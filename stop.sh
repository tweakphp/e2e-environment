#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    BASE_DIR="$SCRIPT_DIR"
elif [ -f "$SCRIPT_DIR/../docker-compose.yml" ]; then
    BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    BASE_DIR="$SCRIPT_DIR"
fi

CLEAN_APPS="${CLEAN_APPS:-true}"

for arg in "$@"; do
    case "$arg" in
        --keep-apps|--no-clean)
            CLEAN_APPS=false
            ;;
        --clean|-c)
            CLEAN_APPS=true
            ;;
    esac
done

echo "=========================================="
echo " Stopping E2E Environment"
echo "=========================================="

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "--> Stopping Docker Compose containers..."
    cd "$BASE_DIR"
    if docker compose version >/dev/null 2>&1; then
        docker compose down -v --remove-orphans 2>/dev/null || true
    else
        docker-compose down -v --remove-orphans 2>/dev/null || true
    fi

    # Clean up generated applications directory safely after containers have stopped
    if [ "$CLEAN_APPS" = "true" ] && [ -d "$BASE_DIR/apps" ]; then
        echo "--> Granting full permissions on apps directory..."
        docker run --rm -v "$BASE_DIR:/work" alpine chmod -R 777 /work/apps 2>/dev/null || true
        echo "--> Deleting generated test applications in apps/..."
        rm -rf "$BASE_DIR/apps" 2>/dev/null || docker run --rm -v "$BASE_DIR:/work" alpine rm -rf /work/apps 2>/dev/null || true
    fi
elif [ "$CLEAN_APPS" = "true" ] && [ -d "$BASE_DIR/apps" ]; then
    echo "--> Deleting generated test applications in apps/..."
    rm -rf "$BASE_DIR/apps" 2>/dev/null || true
fi

if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
    echo "--> Cleaning up Kubernetes manifests..."
    kubectl delete -f "$BASE_DIR/k8s/laravel-pod.yaml" --ignore-not-found --timeout=15s 2>/dev/null || true
    kubectl delete ns tweakphp-test --ignore-not-found --timeout=15s 2>/dev/null || true
fi

if [ "$CLEAN_APPS" = "true" ]; then
    echo "=========================================="
    echo " Environment stopped and apps cleaned."
    echo "=========================================="
else
    echo "--> Apps directory preserved for fast restart."
    echo "=========================================="
    echo " Environment stopped (apps preserved)."
    echo "=========================================="
fi
