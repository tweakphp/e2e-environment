# TweakPHP E2E Testing Environment

Dedicated, script-managed E2E testing environment for verifying **TweakPHP** connection types:
- 🐳 **Docker Connections**: Testing connections to local running containers (`tweakphp-docker-app`).
- ⛵ **Laravel Sail Connections**: Testing connections to containerized Laravel Sail apps (`tweakphp-sail-app`).
- 🔑 **SSH Connections**: Testing remote execution over SSH (`tweakphp-ssh-app` on port `2222`).
- ☸️ **Kubernetes (kubectl) Connections**: Testing connection execution inside pods running in a local cluster (`tweakphp-test` namespace).

---

## 🏗️ Architecture & How It Works

1. **Pre-Built Dedicated Docker Image (`Dockerfile`)**:
   - Built on `php:8.3-cli` with `pdo_sqlite`, `zip`, `unzip`, `git`, `openssh-server`, and Composer pre-baked.
   - Eliminates runtime `apt-get` delays, `dpkg` lock conflicts, and `ZipDownloader` errors.

2. **In-Container Provisioning**:
    - `composer create-project` runs **INSIDE** the PHP 8.3 container via `docker exec`.
    - `vendor/composer/platform_check.php` is generated natively by PHP 8.3.33, ensuring 100% platform check compliance with zero host PHP version leakage.
    - All test apps (`docker-app`, `sail-app`, `ssh-app`) are automatically configured with **SQLite** (`database/database.sqlite`).

3. **Kubernetes Provisioning**:
   - The Kubernetes deployment builds a Laravel application with SQLite inside its PHP 8.3 pod before reporting as ready.
   - `start.sh` waits for the deployment rollout, so the displayed pod name is ready for a TweakPHP connection.

---

## 🚀 Quick Start Guide

### 1. Using the Makefile (Recommended)

A helper Makefile is included to streamline all lifecycle operations:

```bash
# View all available targets and help
make

# Start the environment (builds if necessary, starts services, displays credentials)
make up

# Display connection parameters anytime
make info

# Stop services safely (preserves apps/ for instant next start)
make down

# Clean teardown (stops services and wipes apps/)
make clean
```