#!/bin/bash

VERSION=$1
OPTS=$2

if [ -z "$VERSION" ];
then
    VERSION=devel
fi

docker build $OPTS -t nginx-rtmp nginx-rtmp
BUILD_SUCCESS=$?

if [ $BUILD_SUCCESS -eq 0 ];
then
    docker tag nginx-rtmp registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp":$VERSION"
    docker push registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp":$VERSION"
else
    echo "nginx-rtmp build failed"
fi
