#!/bin/bash

VERSION=$1
OPTS=$2

if [ -z "$VERSION" ];
then
    VERSION=devel
fi

docker build $OPTS -t nginx-http nginx-http
BUILD_SUCCESS=$?

if [ $BUILD_SUCCESS -eq 0 ];
then
    docker tag nginx-http registry.gitlab.com/kanaliiga/stream-rtmp/nginx-http":$VERSION"
    docker push registry.gitlab.com/kanaliiga/stream-rtmp/nginx-http":$VERSION"
else
    echo "nginx-http build failed"
fi
