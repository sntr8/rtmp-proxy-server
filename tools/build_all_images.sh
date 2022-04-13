#!/bin/bash

VERSION=$1
OPTS=$2

if [ -z "$VERSION" ];
then
    VERSION=devel
fi

./tools/images/build_haproxy.sh $VERSION $OPTS

./tools/images/build_mysql.sh $VERSION $OPTS

./tools/images/build_php-fpm.sh $VERSION $OPTS

./tools/images/build_nginx-http.sh $VERSION $OPTS

./tools/images/build_nginx-rtmp-base.sh $VERSION $OPTS

./tools/images/build_nginx-rtmp-delayer.sh $VERSION $OPTS

./tools/images/build_nginx-rtmp-proxy.sh $VERSION $OPTS
