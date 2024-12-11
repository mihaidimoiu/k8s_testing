#!/usr/bin/env sh

set -e

# Default options
NAMESPACE=""
VERBOSE=true
DRY_RUN=false
CLEAN=false
REDEPLOY=false

MONGODB_DIR="./mongodb"
FLASK_DIR="./web_server"
NGINX_DIR="./nginx"

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
    -n, --namespace <name>  Apply resources in a specific Kubernetes namespace
    -q, --quiet             Disable verbose output
    -d, --dry-run           Perform a server-side dry-run without applying or deleting
    -c, --clean             Remove (delete) existing resources and exit
    -r, --redeploy          Remove existing resources first, then re-apply them
    -h, --help              Print this help message and exit

Examples:
    $0                    # Apply all resources
    $0 -c                 # Delete all managed resources and exit
    $0 -r                 # Delete all managed resources, then re-apply them
    $0 --namespace dev    # Apply resources in the 'dev' namespace
    $0 --dry-run          # Show what changes would happen without applying or deleting
EOF
}

# Pre-parse for --help
for arg in "$@"; do
    case "$arg" in
        --help)
            usage
            exit 0
            ;;
    esac
done

# Parse short options
while getopts "hn:qdcr" opt; do
    case "$opt" in
        h)
            usage
            exit 0
            ;;
        n)
            NAMESPACE="$OPTARG"
            ;;
        q)
            VERBOSE=false
            ;;
        d)
            DRY_RUN=true
            ;;
        c)
            CLEAN=true
            ;;
        r)
            REDEPLOY=true
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

# Parse remaining long options
while [ $# -gt 0 ]; do
    case "$1" in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --quiet)
            VERBOSE=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --redeploy)
            REDEPLOY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check for kubectl
if ! command -v kubectl >/dev/null 2>&1; then
    echo "Error: kubectl is not installed or not available in the PATH."
    exit 1
fi

log() {
    if [ "$VERBOSE" = "true" ]; then
        echo "$@"
    fi
}

check_path() {
    if [ ! -e "$1" ]; then
        echo "Error: '$1' does not exist."
        exit 1
    fi
}

check_path "$MONGODB_DIR"
check_path "$FLASK_DIR"
check_path "$NGINX_DIR"

KUBE_OPTS=""
[ -n "$NAMESPACE" ] && KUBE_OPTS="$KUBE_OPTS --namespace=$NAMESPACE"
[ "$DRY_RUN" = "true" ] && KUBE_OPTS="$KUBE_OPTS --dry-run=server"

RESOURCES="
$MONGODB_DIR/mongo-stateful.yaml
$MONGODB_DIR/mongo-headless-service.yaml
$MONGODB_DIR/mongo-pv0.yaml
$MONGODB_DIR/mongo-pv1.yaml
$MONGODB_DIR/mongo-pv2.yaml
$MONGODB_DIR/mongo-sm.yaml
$MONGODB_DIR/mongo-cm.yaml
$NGINX_DIR/nginx-pod.yaml
$FLASK_DIR/app-deployment.yaml
$FLASK_DIR/app-deployment-service.yaml
$FLASK_DIR/app-cm.yaml
"

apply_resources() {
    for RESOURCE_FILE in $RESOURCES; do
        log "Applying $RESOURCE_FILE"
        kubectl apply $KUBE_OPTS -f "$RESOURCE_FILE"
    done
}

delete_resources() {
    for RESOURCE_FILE in $RESOURCES; do
        log "Deleting $RESOURCE_FILE"
        # Using --ignore-not-found to avoid errors if resource doesn't exist
        kubectl delete $KUBE_OPTS --ignore-not-found=true -f "$RESOURCE_FILE"
    done

    # After deleting the main resources, also delete PVCs created by the StatefulSet
    log "Deleting PVCs associated with MongoDB..."
    # Assuming PVCs are labeled with app=mongodb, or you can manually specify known PVC names
    kubectl delete $KUBE_OPTS pvc -l app=mongodb --ignore-not-found=true || true
}

# Clean only: delete resources and exit
if [ "$CLEAN" = "true" ] && [ "$REDEPLOY" = "false" ]; then
    log "Performing clean..."
    delete_resources
    log "Clean completed."
    kubectl get all $KUBE_OPTS
    exit 0
fi

# Redeploy: delete first, then apply
if [ "$REDEPLOY" = "true" ]; then
    log "Performing redeploy (clean then apply)..."
    delete_resources
    # Now apply after delete
    apply_resources
    log "Redeploy completed."
    kubectl get all $KUBE_OPTS
    exit 0
fi

# If neither clean-only nor redeploy:
# Just apply the resources
log "Applying resources..."
apply_resources
log "All resources applied successfully."
kubectl get all $KUBE_OPTS
