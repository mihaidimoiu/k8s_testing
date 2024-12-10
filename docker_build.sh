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

Examples:
    $0 --nginx-tag 1.21 --mongodb-tag 5.0 --flask-tag 2.0 -n -f
    $0 -c --no-cache --force-pull
    $0 -r --force-pull
    $0 -h
EOF
}

# Pre-parse long options that might appear before short-options block
for arg in "$@"; do
    case "$arg" in
        --help)
            usage
            exit 0
            ;;
    esac
done

# Include 'r' in the getopts string for rebuild option
while getopts "hnfqcr" opt; do
    case "$opt" in
        h)
            usage
            exit 0
            ;;
        n)
            NO_CACHE=true
            ;;
        f)
            FORCE_PULL=true
            ;;
        q)
            VERBOSE=false
            ;;
        c)
            CLEAN=true
            ;;
        r)
            REBUILD=true
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

# Shift out the processed short options
shift $((OPTIND-1))

# Parse any remaining long options manually
while [ $# -gt 0 ]; do
    case "$1" in
        --nginx-tag)
            NGINX_TAG="$2"
            shift 2
            ;;
        --mongodb-tag)
            MONGODB_TAG="$2"
            shift 2
            ;;
        --flask-tag)
            FLASK_TAG="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --force-pull)
            FORCE_PULL=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --rebuild)
            REBUILD=true
            shift
            ;;
        --quiet)
            VERBOSE=false
            shift
            ;;
        *)
            # Unknown option
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check Docker installation
if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker is not installed or not available in the PATH."
    exit 1
fi

BUILD_OPTS=""
[ "$NO_CACHE" = "true" ] && BUILD_OPTS="$BUILD_OPTS --no-cache"
[ "$FORCE_PULL" = "true" ] && BUILD_OPTS="$BUILD_OPTS --pull"

log() {
    if [ "$VERBOSE" = "true" ]; then
        echo "$@"
    fi
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

clean_docker_resources() {
    # List of images to process
    IMAGES="nginx_proxy mongodb flask_app"
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
