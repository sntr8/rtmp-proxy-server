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

docker build $OPTS -t php-fpm -f php-fpm/Dockerfile .
BUILD_SUCCESS=$?

if [ $BUILD_SUCCESS -eq 0 ];
then
    if [ -n "$REGISTRY" ]; then
        # Tag and push to registry
        docker tag php-fpm "$REGISTRY/php-fpm:$VERSION"
        echo "Pushing php-fpm:$VERSION to $REGISTRY"
        docker push "$REGISTRY/php-fpm:$VERSION"
    else
        echo "php-fpm built successfully (local only, no push)"
    fi
else
    echo "php-fpm build failed"
fi
