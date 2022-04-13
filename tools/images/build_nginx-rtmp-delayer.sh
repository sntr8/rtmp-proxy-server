#!/bin/bash

VERSION=$1
OPTS=$2

if [ -z "$VERSION" ];
then
    VERSION=devel
fi

docker build $OPTS -t nginx-rtmp-delayer nginx-rtmp-delayer
BUILD_SUCCESS=$?

if [ $BUILD_SUCCESS -eq 0 ];
then
    docker tag nginx-rtmp-delayer registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp-delayer":$VERSION"
    docker push registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp-delayer":$VERSION"
else
    echo "nginx-rtmp build failed"
fi
