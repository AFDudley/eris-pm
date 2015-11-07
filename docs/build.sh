#!/usr/bin/env bash

start=`pwd`
mkdir -p docs/eris-pm
go run docs/generator.go

cd $HOME
git clone git@github.com:eris-ltd/docs.erisindustries.com.git
cd $start

rsync -av docs/eris-pm $HOME/docs.erisindustries.com/documentation/

cd $HOME/docs.erisindustries.com;
if [ -z "$(git status --porcelain)" ]; then
  echo "All Good!"
else
  git add -A :/ &&
  git commit -m "eris-pm build number $CIRCLE_BUILD_NUM doc generation" &&
  git push origin master
fi

cd $start