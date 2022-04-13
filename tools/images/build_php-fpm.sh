#!/bin/bash

VERSION=$1
OPTS=$2

if [ -z "$VERSION" ];
then
    VERSION=devel
fi

docker build $OPTS -t php-fpm -f php-fpm/Dockerfile .
BUILD_SUCCESS=$?

if [ $BUILD_SUCCESS -eq 0 ];
then
    docker tag php-fpm registry.gitlab.com/kanaliiga/stream-rtmp/php-fpm":$VERSION"
    docker push registry.gitlab.com/kanaliiga/stream-rtmp/php-fpm":$VERSION"
else
    echo "php-fpm build failed"
fi
