#!/usr/bin/env bash
# ----------------------------------------------------------
# PURPOSE

# This is the test manager for eris-pm. It will run the testing
# sequence for eris-pm using docker.

# ----------------------------------------------------------
# REQUIREMENTS

# eris installed locally

# ----------------------------------------------------------
# USAGE

# test.sh [setup]

# ----------------------------------------------------------
# Set defaults

# Where are the Things?

name=eris-pm
base=github.com/eris-ltd/$name
repo=$GOPATH/src/$base
if [ "$CIRCLE_BRANCH" ]
then
  repo=${GOPATH%%:*}/src/$base
  ci=true
  linux=true
elif [ "$TRAVIS_BRANCH" ]
then
  ci=true
  osx=true
elif [ "$APPVEYOR_REPO_BRANCH" ]
then
  ci=true
  win=true
else
  ci=false
fi

branch=${CIRCLE_BRANCH:=master}
branch=${branch/-/_}
branch=${branch/\//_}

# Other variables
if [[ "$(uname -s)" == "Linux" ]]
then
  uuid=$(cat /proc/sys/kernel/random/uuid | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1)
elif [[ "$(uname -s)" == "Darwin" ]]
then
  uuid=$(uuidgen | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1  | tr '[:upper:]' '[:lower:]')
else
  uuid="62d1486f0fe5"
fi

was_running=0
test_exit=0
chains_dir=$HOME/.eris/chains
chain_name=epm-tests-$uuid
name_full="$chain_name"_full_000
name_part="$chain_name"_participant_000
chain_dir=$chains_dir/$chain_name

export ERIS_PULL_APPROVE="true"
export ERIS_MIGRATE_APPROVE="true"

# ---------------------------------------------------------------------------
# Needed functionality

ensure_running(){
  if [[ "$(eris services ls -qr | grep $1)" == "$1" ]]
  then
    echo "$1 already started. Not starting."
    was_running=1
  else
    echo "Starting service: $1"
    eris services start $1 1>/dev/null
    early_exit
    sleep 3 # boot time
  fi
}

early_exit(){
  if [ $? -eq 0 ]
  then
    return 0
  fi

  echo "There was an error duing setup; keys were not properly imported. Exiting."
  if [ "$was_running" -eq 0 ]
  then
    if [ "$ci" = true ]
    then
      eris services stop keys
    else
      eris services stop -rx keys
    fi
  fi
  exit 1
}

test_setup(){
  echo "Getting Setup"
  if [ "$ci" = true ]
  then
    eris init --yes --pull-images=true --testing=true 1>/dev/null
  fi
  ensure_running keys

  # make a chain
  eris chains make --account-types=Full:1,Participant:1 epm-tests-$uuid 1>/dev/null
  key1_addr=$(cat $chain_dir/addresses.csv | grep $name_full | cut -d ',' -f 1)
  key2_addr=$(cat $chain_dir/addresses.csv | grep $name_part | cut -d ',' -f 1)
  key2_pub=$(cat $chain_dir/accounts.csv | grep $name_part | cut -d ',' -f 1)
  echo -e "Default Key =>\t\t\t\t$key1_addr"
  echo -e "Backup Key =>\t\t\t\t$key2_addr"
  eris chains new $chain_name --dir $chain_dir/$name_full 1>/dev/null
  sleep 5 # boot time
  echo "Setup complete"
}

goto_base(){
  cd $repo/tests/fixtures
}

run_test(){
  # Run the epm deploy
  echo ""
  echo -e "Testing EPM using fixture =>\t$1"
  goto_base
  cd $1
  if [ "$ci" = false ]
  then
    eris pkgs do --chain "$chain_name" --address "$key1_addr" --set "addr1=$key1_addr" --set "addr2=$key2_addr" --set "addr2_pub=$key2_pub"
  else
    eris pkgs do --chain "$chain_name" --address "$key1_addr" --set "addr1=$key1_addr" --set "addr2=$key2_addr" --set "addr2_pub=$key2_pub" --rm
  fi
  test_exit=$?

  # Reset for next run
  goto_base
  return $test_exit
}

perform_tests(){
  echo ""
  goto_base
  apps=(app*/)
  for app in "${apps[@]}"
  do
    run_test $app

    # Set exit code properly
    test_exit=$?
    if [ $test_exit -ne 0 ]
    then
      failing_dir=`pwd`
      break
    fi
  done
}

test_teardown(){
  if [ $test_exit -ne 0 ]
  then
    echo ""
    echo "EPM Log on Failed Test."
    cat $failing_dir/epm.json
  fi
  if [ "$ci" = false ]
  then
    echo ""
    eris chains stop -rxf $chain_name 1>/dev/null
    eris chains rm -f $chain_name 1>/dev/null
    if [ "$was_running" -eq 0 ]
    then
      eris services stop -rx keys
    fi
    rm -rf $HOME/.eris/scratch/data/epm-tests-*
    rm -rf $chain_dir
  fi
  echo ""
  if [ "$test_exit" -eq 0 ]
  then
    echo "Tests complete! Tests are Green. :)"
  else
    echo "Tests complete. Tests are Red. :("
  fi
  cd $start
  exit $test_exit
}

# ---------------------------------------------------------------------------
# Get the things build and dependencies turned on

echo "Hello! I'm the marmot that tests the eris-pm tooling."
start=`pwd`
cd $repo
echo ""
echo "Building eris-pm in a docker container."
set -e
tests/build_tool.sh 1>/dev/null
set +e
if [ $? -ne 0 ]
then
  echo "Could not build eris-pm. Debug via by directly running [`pwd`/tests/build_tool.sh]"
  exit 1
fi
echo "Build complete."
echo ""

# ---------------------------------------------------------------------------
# Setup

test_setup

# ---------------------------------------------------------------------------
# Go!

if [[ "$1" != "setup" ]]
then
  if ! [ -z "$1" ]
  then
    echo "Running One Test..."
    run_test "$1/"
  else
    echo "Running All Tests..."
    perform_tests
  fi
fi

# ---------------------------------------------------------------------------
# Cleaning up

if [[ "$1" != "setup" ]]
then
  test_teardown
fi
