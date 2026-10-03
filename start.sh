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

echo "============================================================"
echo " 🔍 PRE-FLIGHT PREREQUISITES CHECK (PHP 8.3 Environment)"
echo "============================================================"

HAS_DOCKER=false
HAS_DOCKER_COMPOSE=false
HAS_K8S=false

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    echo "  [✓] Docker Daemon:    RUNNING"
    HAS_DOCKER=true
else
    echo "  [✗] Docker Daemon:    NOT RUNNING OR NOT AVAILABLE"
fi

if docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1; then
    echo "  [✓] Docker Compose:   AVAILABLE"
    HAS_DOCKER_COMPOSE=true
fi

if command -v kubectl >/dev/null 2>&1 && kubectl cluster-info >/dev/null 2>&1; then
    echo "  [✓] Kubectl & K8s:    CLUSTER ACTIVE"
    HAS_K8S=true
fi

echo "============================================================"
echo ""

if [ "$HAS_DOCKER" != true ] && [ "$HAS_K8S" != true ]; then
    echo "❌ Neither Docker nor Kubernetes is available or running."
    echo "   Please start Docker (Docker Desktop, OrbStack, etc.) or your K8s cluster and try again."
    exit 1
fi

# Run setup to spin up containers and install Laravel inside containers
if [ "$HAS_DOCKER" = true ] && [ "$HAS_DOCKER_COMPOSE" = true ]; then
    if [ ! -f "$BASE_DIR/apps/docker-app/artisan" ] || [ ! -f "$BASE_DIR/apps/sail-app/artisan" ] || [ ! -f "$BASE_DIR/apps/ssh-app/artisan" ]; then
        echo "--> Running setup.sh to start containers and install Laravel inside..."
        bash "$BASE_DIR/setup.sh"
    else
        echo "--> Starting Docker Compose services..."
        cd "$BASE_DIR"
        if docker compose version >/dev/null 2>&1; then
            docker compose up -d
        else
            docker-compose up -d
        fi
    fi
else
    echo "  [!] Docker is not available or not running. Skipping Docker services."
fi

if [ "$HAS_K8S" = true ]; then
    echo "--> Applying Kubernetes test manifests..."
    if kubectl get ns tweakphp-test 2>/dev/null | grep -q Terminating; then
        echo "--> Waiting for terminating tweakphp-test namespace to clear..."
        kubectl wait --for=delete namespace/tweakphp-test --timeout=30s 2>/dev/null || true
    fi
    if kubectl apply -f "$BASE_DIR/k8s/laravel-pod.yaml"; then
        echo "--> Waiting for Kubernetes deployment rollout..."
        kubectl rollout status deployment/tweakphp-k8s-laravel -n tweakphp-test --timeout=180s 2>/dev/null || {
            echo "  [!] Warning: Kubernetes deployment rollout did not complete within timeout."
        }
    fi
fi

echo ""
echo "============================================================"
echo " 📋 TWEAKPHP CONNECTION PARAMETERS (PHP 8.3)"
echo " Copy and paste these exact values into TweakPHP connections:"
echo "============================================================"

if [ "$HAS_DOCKER" = true ]; then
    DOCKER_ID=$(docker inspect -f '{{.Id}}' tweakphp-docker-app 2>/dev/null | cut -c1-12)
    SAIL_ID=$(docker inspect -f '{{.Id}}' tweakphp-sail-app 2>/dev/null | cut -c1-12)
    SSH_ID=$(docker inspect -f '{{.Id}}' tweakphp-ssh-app 2>/dev/null | cut -c1-12)
    DOCKER_ID=${DOCKER_ID:-tweakphp-docker-app}
    SAIL_ID=${SAIL_ID:-tweakphp-sail-app}
    SSH_ID=${SSH_ID:-tweakphp-ssh-app}

    echo ""
    echo "🐳 [1] DOCKER CONNECTION"
    echo "------------------------------------------------------------"
    echo "  • Connection Type:   Docker"
    echo "  • Connection Name:   Docker E2E Test"
    echo "  • Container Name:    tweakphp-docker-app"
    echo "  • Container ID:      $DOCKER_ID"
    echo "  • Working Directory: /var/www/html"
    echo "  • PHP Path:          php"

    echo ""
    echo "⛵ [2] LARAVEL SAIL CONNECTION"
    echo "------------------------------------------------------------"
    echo "  • Connection Type:   Docker"
    echo "  • Connection Name:   Sail E2E Test"
    echo "  • Container Name:    tweakphp-sail-app"
    echo "  • Container ID:      $SAIL_ID"
    echo "  • Working Directory: /var/www/html"
    echo "  • PHP Path:          php"

    echo ""
    echo "🔑 [3] SSH CONNECTION"
    echo "------------------------------------------------------------"
    echo "  • Connection Type:   SSH"
    echo "  • Connection Name:   SSH E2E Test"
    echo "  • Host:              127.0.0.1 (or localhost)"
    echo "  • Port:              2222"
    echo "  • Username:          tweakphp"
    echo "  • Auth Type:         password"
    echo "  • Password:          secret123"
    echo "  • Path / WorkingDir: /var/www/html"
    echo "  • PHP Path:          php"
fi

if [ "$HAS_K8S" = true ]; then
    K8S_POD=$(kubectl get pods -n tweakphp-test -l app=tweakphp-k8s-laravel --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    [ -z "$K8S_POD" ] && K8S_POD=$(kubectl get pods -n tweakphp-test -l app=tweakphp-k8s-laravel -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    K8S_POD=${K8S_POD:-tweakphp-k8s-laravel-xxxx}
    K8S_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "default")

    echo ""
    echo "☸️  [4] KUBERNETES (KUBECTL) CONNECTION"
    echo "------------------------------------------------------------"
    echo "  • Connection Type:   Kubectl"
    echo "  • Connection Name:   Kubernetes E2E Test"
    echo "  • Context:           $K8S_CONTEXT"
    echo "  • Namespace:         tweakphp-test"
    echo "  • Pod Name:          $K8S_POD"
    echo "  • Path / WorkingDir: /var/www/html"
    echo "  • PHP Path:          php"
fi

echo "============================================================"
