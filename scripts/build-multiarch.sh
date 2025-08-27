#!/usr/bin/env bash
set -euo pipefail

# Multi-architecture build script for ADB Butler
# Supports x86_64 and ARM64 architectures

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configuration
OWNER="${OWNER:-nicholashaven}"
IMAGE_NAME="${IMAGE_NAME:-adb-butler}"
VERSION="${VERSION:-2.0.0}"
PLATFORMS="linux/amd64,linux/arm64"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if buildx is available
check_buildx() {
    if ! docker buildx version >/dev/null 2>&1; then
        log_error "Docker buildx is not available. Please install Docker Desktop or enable buildx."
        exit 1
    fi
}

# Create and use a new builder instance
setup_builder() {
    log_info "Setting up multi-architecture builder..."
    
    # Create a new builder instance if it doesn't exist
    if ! docker buildx inspect multiarch-builder >/dev/null 2>&1; then
        docker buildx create --name multiarch-builder --use
    else
        docker buildx use multiarch-builder
    fi
    
    # Bootstrap the builder
    docker buildx inspect --bootstrap
}

# Build multi-architecture image
build_image() {
    local tag="$1"
    local push="$2"
    
    log_info "Building multi-architecture image: $tag"
    log_warn "Note: ADB platform tools are only available for x86_64 architecture"
    log_warn "ARM64 builds will have limited ADB functionality"
    
    cd "$PROJECT_DIR"
    
    docker buildx build \
        --platform "$PLATFORMS" \
        --build-arg VCS_REF="$(git rev-parse --short HEAD)" \
        --build-arg IMAGE_VERSION="$VERSION" \
        --tag "$tag" \
        ${push:+--push} \
        .
}

# Test the built images
test_images() {
    local tag="$1"
    
    log_info "Testing built images..."
    
    # Test x86_64 image
    log_info "Testing x86_64 image..."
    docker run --rm --platform linux/amd64 "$tag" /bin/bash -c "
        echo 'Architecture: ' \$(uname -m)
        echo 'Node.js: ' \$(node --version)
        echo 'npm: ' \$(npm --version)
        echo 'ADB: ' \$(adb version 2>/dev/null || echo 'Not available')
    "
    
    # Test ARM64 image
    log_info "Testing ARM64 image..."
    docker run --rm --platform linux/arm64 "$tag" /bin/bash -c "
        echo 'Architecture: ' \$(uname -m)
        echo 'Node.js: ' \$(node --version)
        echo 'npm: ' \$(npm --version)
        echo 'ADB: ' \$(which adb 2>/dev/null || echo 'Not available on ARM64')
    "
}

# Main function
main() {
    local action="${1:-build}"
    local registry="${2:-}"
    
    case "$action" in
        "build")
            check_buildx
            setup_builder
            build_image "$OWNER/$IMAGE_NAME:$VERSION" ""
            log_info "Build completed successfully!"
            ;;
        "push")
            if [[ -z "$registry" ]]; then
                log_error "Registry URL required for push action"
                echo "Usage: $0 push <registry-url>"
                exit 1
            fi
            check_buildx
            setup_builder
            build_image "$registry/$OWNER/$IMAGE_NAME:$VERSION" "true"
            log_info "Push completed successfully!"
            ;;
        "test")
            check_buildx
            test_images "$OWNER/$IMAGE_NAME:$VERSION"
            ;;
        *)
            echo "Usage: $0 {build|push|test} [registry-url]"
            echo ""
            echo "Actions:"
            echo "  build    Build multi-architecture image locally"
            echo "  push     Build and push to registry"
            echo "  test     Test built images"
            echo ""
            echo "Examples:"
            echo "  $0 build"
            echo "  $0 push docker.io"
            echo "  $0 test"
            exit 1
            ;;
    esac
}

main "$@"
