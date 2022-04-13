#!/bin/bash

VERSION=$1
OPTS=$2

if [ -z "$VERSION" ];
then
    VERSION=devel
fi

docker build $OPTS -t mysql mysql
BUILD_SUCCESS=$?

if [ $BUILD_SUCCESS -eq 0 ];
then
    docker tag mysql registry.gitlab.com/kanaliiga/stream-rtmp/mysql":$VERSION"
    docker push registry.gitlab.com/kanaliiga/stream-rtmp/mysql":$VERSION"
else
    echo "mysql build failed"
fi
