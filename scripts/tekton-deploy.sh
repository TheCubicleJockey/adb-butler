#!/usr/bin/env bash
set -euo pipefail

# Tekton deployment script for ADB Butler
# This script deploys and runs the Tekton pipeline

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEKTON_DIR="$PROJECT_DIR/tekton"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
}

# Check if Tekton is installed
check_tekton() {
    if ! kubectl get namespace tekton-pipelines &> /dev/null; then
        log_error "Tekton is not installed. Please install Tekton first:"
        echo "  kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml"
        exit 1
    fi
    
    if ! kubectl get crd pipelines.tekton.dev &> /dev/null; then
        log_error "Tekton CRDs are not installed"
        exit 1
    fi
}

# Create namespace if it doesn't exist
create_namespace() {
    local namespace="$1"
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log_info "Creating namespace: $namespace"
        kubectl create namespace "$namespace"
    fi
}

# Deploy Tekton resources
deploy_tekton_resources() {
    log_step "Deploying Tekton resources..."
    
    # Create namespace
    create_namespace "tekton-pipelines"
    
    # Deploy service account and RBAC
    log_info "Deploying service account and RBAC..."
    kubectl apply -f "$TEKTON_DIR/k8s/service-account.yaml"
    
    # Deploy custom tasks
    log_info "Deploying custom tasks..."
    kubectl apply -f "$TEKTON_DIR/tasks/hadolint-task.yaml"
    kubectl apply -f "$TEKTON_DIR/tasks/docker-run-task.yaml"
    kubectl apply -f "$TEKTON_DIR/tasks/trivy-scanner-task.yaml"
    
    # Deploy pipeline
    log_info "Deploying pipeline..."
    kubectl apply -f "$TEKTON_DIR/pipeline.yaml"
    
    log_info "Tekton resources deployed successfully!"
}

# Run development pipeline
run_dev_pipeline() {
    log_step "Running development pipeline..."
    
    log_info "Creating development PipelineRun..."
    kubectl apply -f "$TEKTON_DIR/pipelinerun-dev.yaml"
    
    # Get the PipelineRun name
    local pipelinerun_name=$(kubectl get pipelinerun -n tekton-pipelines --sort-by=.metadata.creationTimestamp --no-headers | tail -1 | awk '{print $1}')
    
    log_info "PipelineRun created: $pipelinerun_name"
    log_info "Monitoring pipeline execution..."
    
    # Monitor the pipeline
    kubectl logs -f pipelinerun/$pipelinerun_name -n tekton-pipelines
}

# Run production pipeline
run_prod_pipeline() {
    log_step "Running production pipeline..."
    
    log_warn "This will push the image to the registry!"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Production pipeline cancelled"
        exit 0
    fi
    
    log_info "Creating production PipelineRun..."
    kubectl apply -f "$TEKTON_DIR/pipelinerun-prod.yaml"
    
    # Get the PipelineRun name
    local pipelinerun_name=$(kubectl get pipelinerun -n tekton-pipelines --sort-by=.metadata.creationTimestamp --no-headers | tail -1 | awk '{print $1}')
    
    log_info "PipelineRun created: $pipelinerun_name"
    log_info "Monitoring pipeline execution..."
    
    # Monitor the pipeline
    kubectl logs -f pipelinerun/$pipelinerun_name -n tekton-pipelines
}

# Show pipeline status
show_status() {
    log_step "Pipeline status:"
    kubectl get pipelinerun -n tekton-pipelines
    echo
    log_step "TaskRun status:"
    kubectl get taskrun -n tekton-pipelines
}

# Clean up resources
cleanup() {
    log_step "Cleaning up Tekton resources..."
    
    kubectl delete -f "$TEKTON_DIR/pipeline.yaml" --ignore-not-found
    kubectl delete -f "$TEKTON_DIR/tasks/hadolint-task.yaml" --ignore-not-found
    kubectl delete -f "$TEKTON_DIR/tasks/docker-run-task.yaml" --ignore-not-found
    kubectl delete -f "$TEKTON_DIR/tasks/trivy-scanner-task.yaml" --ignore-not-found
    kubectl delete -f "$TEKTON_DIR/k8s/service-account.yaml" --ignore-not-found
    
    log_info "Cleanup completed!"
}

# Show usage
show_usage() {
    echo "Usage: $0 {deploy|dev|prod|status|cleanup}"
    echo ""
    echo "Commands:"
    echo "  deploy    Deploy Tekton resources (pipeline, tasks, RBAC)"
    echo "  dev       Run development pipeline (build and test only)"
    echo "  prod      Run production pipeline (build, test, and push)"
    echo "  status    Show pipeline and task run status"
    echo "  cleanup   Remove all Tekton resources"
    echo ""
    echo "Examples:"
    echo "  $0 deploy"
    echo "  $0 dev"
    echo "  $0 prod"
    echo "  $0 status"
}

# Main function
main() {
    local action="${1:-}"
    
    # Check prerequisites
    check_kubectl
    check_tekton
    
    case "$action" in
        "deploy")
            deploy_tekton_resources
            ;;
        "dev")
            deploy_tekton_resources
            run_dev_pipeline
            ;;
        "prod")
            deploy_tekton_resources
            run_prod_pipeline
            ;;
        "status")
            show_status
            ;;
        "cleanup")
            cleanup
            ;;
        *)
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
