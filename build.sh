#!/bin/bash

VERSION=$1
BUILD_TO=build/$VERSION
IMAGE=elixir:$VERSION
SMPPSEND=$(pwd)

docker pull $IMAGE
docker run -v $SMPPSEND:/smppsend -w /smppsend -e "BUILD_TO=$BUILD_TO" $IMAGE make



