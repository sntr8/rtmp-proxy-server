#!/bin/bash

VERSION=$1
OPTS=$2

if [ -z "$VERSION" ];
then
    VERSION=devel
fi

# Determine registry configuration
if [ -n "$REGISTRY_URL" ]; then
    # Custom registry (e.g., registry.gitlab.com/user/project)
    REGISTRY="$REGISTRY_URL"
elif [ -n "$DOCKER_USERNAME" ]; then
    # Docker Hub
    REGISTRY="$DOCKER_USERNAME"
else
    # Local only - no registry
    REGISTRY=""
fi

docker build $OPTS -t haproxy haproxy
BUILD_SUCCESS=$?

if [ "$BUILD_SUCCESS" -eq 0 ];
then
    if [ -n "$REGISTRY" ]; then
        # Tag for registry
        docker tag haproxy "$REGISTRY/haproxy:$VERSION"

        # Run syntax check with registry tag
        docker run -it --rm --name haproxy-syntax-check \
            --add-host=nginx-http:127.0.0.1 \
            -e FQDN="configtest" \
            "$REGISTRY/haproxy:$VERSION" \
            -c -f /usr/local/etc/haproxy/haproxy.cfg
        TEST_SUCCESS=$?

        if [ "$TEST_SUCCESS" -eq 0 ];
        then
            echo "Pushing haproxy:$VERSION to $REGISTRY"
            docker push "$REGISTRY/haproxy:$VERSION"
        else
            echo "HAProxy config didn't pass validation. Won't push"
        fi
    else
        # Local build only - run syntax check on local tag
        docker run -it --rm --name haproxy-syntax-check \
            --add-host=nginx-http:127.0.0.1 \
            -e FQDN="configtest" \
            haproxy:latest \
            -c -f /usr/local/etc/haproxy/haproxy.cfg
        TEST_SUCCESS=$?

        if [ "$TEST_SUCCESS" -eq 0 ];
        then
            echo "HAProxy built successfully (local only, no push)"
        else
            echo "HAProxy config didn't pass validation"
        fi
    fi
else
    echo "HAProxy build failed"
fi
