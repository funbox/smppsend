#!/bin/bash

VERSION=$1

DOCKER_DIR=build/$VERSION
IMAGE_TAG=smppsend-$VERSION

SMPPSEND=$(pwd)
BIN_DIR=bin

SMPPSEND_BIN=$BIN_DIR/smppsend-$VERSION

mkdir -p $BIN_DIR
docker build -t $IMAGE_TAG $DOCKER_DIR
docker run -v $SMPPSEND:/smppsend -w /smppsend $IMAGE_TAG make escript SMPPSEND_BIN=$SMPPSEND_BIN
