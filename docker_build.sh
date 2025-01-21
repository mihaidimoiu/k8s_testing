#!/usr/bin/env sh
set -e

# Default tags
NGINX_TAG="latest"
MONGODB_TAG="latest"
FLASK_TAG="latest"

# Default options
NO_CACHE=false
FORCE_PULL=false
VERBOSE=true
CLEAN=false
REBUILD=false

NGINX_DIR="./nginx"
MONGODB_DIR="./mongodb"
FLASK_DIR="./web_server"

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
    --nginx-tag <tag>       Set tag for nginx image (default: "latest")
    --mongodb-tag <tag>     Set tag for mongodb image (default: "latest")
    --flask-tag <tag>       Set tag for flask_app image (default: "latest")

    -c, --clean             Remove existing images/containers/volumes and exit
    -r, --rebuild           Remove existing images/containers/volumes before building
    -n, --no-cache          Build images with no cache
    -f, --force-pull        Always attempt to pull the latest base image
    -q, --quiet             Disable verbose output
    -h, --help              Print this help message and exit
EOF
}

# SINGLE LOOP for both short & long options
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -n|--no-cache)
            NO_CACHE=true
            ;;
        -f|--force-pull)
            FORCE_PULL=true
            ;;
        -q|--quiet)
            VERBOSE=false
            ;;
        -c|--clean)
            CLEAN=true
            ;;
        -r|--rebuild)
            REBUILD=true
            ;;
        --nginx-tag)
            shift
            NGINX_TAG="$1"
            ;;
        --mongodb-tag)
            shift
            MONGODB_TAG="$1"
            ;;
        --flask-tag)
            shift
            FLASK_TAG="$1"
            ;;
        -*)
            # Unknown short/long option
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            # Positional arguments, if any. Break or store them.
            break
            ;;
    esac
    shift
done

# Then the rest of your build logic:
BUILD_OPTS=""
[ "$NO_CACHE" = "true" ] && BUILD_OPTS="$BUILD_OPTS --no-cache"
[ "$FORCE_PULL" = "true" ] && BUILD_OPTS="$BUILD_OPTS --pull"

log() {
    [ "$VERBOSE" = "true" ] && echo "$@"
}

# Cleaning functions
remove_related_resources() {
    IMAGE=$1
    log "Stopping and removing containers for image: $IMAGE"
    CONTAINERS=$(docker ps -a -q --filter ancestor="$IMAGE") || true
    if [ -n "$CONTAINERS" ]; then
        docker stop $CONTAINERS >/dev/null 2>&1 || true
        docker rm $CONTAINERS >/dev/null 2>&1 || true
    fi

    # Remove dangling volumes
    log "Removing dangling volumes"
    VOLUMES=$(docker volume ls -q --filter dangling=true) || true
    if [ -n "$VOLUMES" ]; then
        docker volume rm $VOLUMES >/dev/null 2>&1 || true
    fi

    # Remove unused networks
    log "Pruning unused networks"
    docker network prune -f >/dev/null 2>&1 || true
}

remove_image() {
    IMAGE=$1
    IMAGE_ID=$(docker images -q "$IMAGE") || true
    if [ -n "$IMAGE_ID" ]; then
        log "Removing image: $IMAGE"
        docker rmi "$IMAGE" --force >/dev/null 2>&1 || true
    fi
}

IMAGES="nginx_proxy mongodb flask_app appropriate/curl"

clean_docker_resources() {
    # List of images to process
    for IMAGE in $IMAGES; do
        remove_related_resources "$IMAGE"
        remove_image "$IMAGE"
    done
    log "Clean operation completed."
}

build_image() {
    local image_name="$1"
    local build_dir="$2"
    local image_tag="$3"

    # Validate directory
    if [ ! -d "$build_dir" ]; then
        echo "Error: Directory '$build_dir' does not exist."
        exit 1
    fi

    log "Building Docker image: ${image_name}:${image_tag} from $build_dir"
    docker build $BUILD_OPTS -t "${image_name}:${image_tag}" "$build_dir"
    log "Successfully built ${image_name}:${image_tag}"
}

# If clean-only option is set, run cleaning and exit successfully
if [ "$CLEAN" = "true" ] && [ "$REBUILD" = "false" ]; then
    log "Performing clean..."
    clean_docker_resources
    docker ps
    docker images
    exit 0
fi

# If rebuild option is set, run cleaning step first
if [ "$REBUILD" = "true" ]; then
    log "Performing clean before building..."
    clean_docker_resources
    docker ps
    docker images
fi

# Build the images
build_image "mongodb" "$MONGODB_DIR" "$MONGODB_TAG"
build_image "flask_app" "$FLASK_DIR" "$FLASK_TAG"
build_image "nginx_proxy" "$NGINX_DIR" "$NGINX_TAG"
log "All images built successfully."
