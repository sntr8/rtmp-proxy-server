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

docker build $OPTS -t mysql mysql
BUILD_SUCCESS=$?

if [ $BUILD_SUCCESS -eq 0 ];
then
    if [ -n "$REGISTRY" ]; then
        # Tag and push to registry
        docker tag mysql "$REGISTRY/mysql:$VERSION"
        echo "Pushing mysql:$VERSION to $REGISTRY"
        docker push "$REGISTRY/mysql:$VERSION"
    else
        echo "MySQL built successfully (local only, no push)"
    fi
else
    echo "MySQL build failed"
fi
