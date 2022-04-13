#!/bin/bash

VERSION=$1
OPTS=$2

if [ -z "$VERSION" ];
then
    VERSION=devel
fi

docker build $OPTS -t nginx-rtmp-proxy nginx-rtmp-proxy
BUILD_SUCCESS=$?

if [ $BUILD_SUCCESS -eq 0 ];
then
    docker tag nginx-rtmp-proxy registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp-proxy":$VERSION"
    docker push registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp-proxy":$VERSION"
else
    echo "nginx-rtmp-proxy build failed"
fi
