# Pull base image.
FROM quay.io/eris/build
MAINTAINER Eris Industries <support@erisindustries.com>

#-----------------------------------------------------------------------------
# install epm

# set the repo and install epm
ENV REPO $GOPATH/src/github.com/eris-ltd/eris-pm
COPY . $REPO
WORKDIR $REPO/cmd/epm
RUN go build -o /usr/local/bin/epm
RUN chown --recursive $USER:$USER $REPO

#-----------------------------------------------------------------------------
# root dir

# persist data, set user
RUN chown --recursive $USER:$USER /home/$USER
VOLUME /home/$USER/.eris
WORKDIR /home/$USER/.eris
USER $USER
CMD ["epm", "--chain", "chain:46657", "--sign", "keys:4767" ]
