#!/bin/bash

VERSION=$1
OPTS=$2

if [ -z "$VERSION" ];
then
    VERSION=devel
fi

docker build $OPTS -t nginx-rtmp-base nginx-rtmp-base
BUILD_SUCCESS=$?

if [ $BUILD_SUCCESS -eq 0 ];
then
    docker tag nginx-rtmp-base registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp-base":$VERSION"
    docker push registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp-base":$VERSION"
else
    echo "nginx-rtmp build failed"
fi
