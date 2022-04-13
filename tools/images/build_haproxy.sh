#!/bin/bash

VERSION=$1
OPTS=$2

if [ -z "$VERSION" ];
then
    VERSION=devel
fi

docker build $OPTS -t haproxy haproxy
BUILD_SUCCESS=$?

if [ $BUILD_SUCCESS -eq 0 ];
then
    docker tag haproxy registry.gitlab.com/kanaliiga/stream-rtmp/haproxy":$VERSION"
    docker run -it --rm --name haproxy-syntax-check --add-host=nginx-http:127.0.0.1 -e FQDN="configtest" registry.gitlab.com/kanaliiga/stream-rtmp/haproxy":$VERSION" -c -f /usr/local/etc/haproxy/haproxy.cfg
    TEST_SUCCESS=$?

    if [ $TEST_SUCCESS -eq 0 ];
    then
        docker push registry.gitlab.com/kanaliiga/stream-rtmp/haproxy":$VERSION"
    else
        echo "HAproxy config didn't pass validation. Won't push"
    fi
else
    echo "HAproxy build failed"
fi
