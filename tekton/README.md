# Tekton CI/CD Pipeline for ADB Butler

This directory contains the Tekton pipeline configuration for building, testing, and deploying the ADB Butler Docker image with multi-architecture support.

## 🏗️ Pipeline Overview

The Tekton pipeline provides a cloud-native CI/CD solution that:

- **Builds multi-architecture images** (x86_64 and ARM64)
- **Lints Dockerfiles** using hadolint
- **Tests images** on both architectures
- **Scans for security vulnerabilities** using Trivy
- **Pushes to registry** (optional)

## 📁 Directory Structure

```
tekton/
├── README.md                    # This file
├── pipeline.yaml               # Main pipeline definition
├── pipelinerun.yaml           # Default PipelineRun
├── pipelinerun-dev.yaml       # Development PipelineRun
├── pipelinerun-prod.yaml      # Production PipelineRun
├── tasks/                     # Custom Tekton tasks
│   ├── hadolint-task.yaml     # Dockerfile linting task
│   ├── docker-run-task.yaml   # Container testing task
│   └── trivy-scanner-task.yaml # Security scanning task
└── k8s/                       # Kubernetes resources
    └── service-account.yaml   # Service account and RBAC
```

## 🚀 Quick Start

### Prerequisites

1. **Kubernetes cluster** with Tekton installed
2. **kubectl** configured to access your cluster
3. **Docker registry credentials** (for pushing images)

### Install Tekton

If Tekton is not installed, install it first:

```bash
# Install Tekton Pipelines
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Install Tekton CLI (optional)
# For macOS: brew install tektoncd-cli
# For Linux: https://tekton.dev/docs/cli/
```

### Deploy and Run Pipeline

Use the provided script to deploy and run the pipeline:

```bash
# Deploy Tekton resources
./scripts/tekton-deploy.sh deploy

# Run development pipeline (build and test only)
./scripts/tekton-deploy.sh dev

# Run production pipeline (build, test, and push)
./scripts/tekton-deploy.sh prod

# Check pipeline status
./scripts/tekton-deploy.sh status

# Clean up resources
./scripts/tekton-deploy.sh cleanup
```

## 🔧 Pipeline Tasks

### 1. Fetch Repository
- **Task**: `git-clone` (Tekton catalog)
- **Purpose**: Clone the source code repository
- **Parameters**: Git URL, revision, subdirectory

### 2. Lint Dockerfile
- **Task**: `hadolint` (custom task)
- **Purpose**: Lint Dockerfile for best practices
- **Output**: SARIF format for integration with security tools

### 3. Build Image
- **Task**: `kaniko` (Tekton catalog)
- **Purpose**: Build multi-architecture Docker image
- **Platforms**: linux/amd64, linux/arm64
- **Features**: Layer caching, build arguments

### 4. Test Images
- **Task**: `docker-run` (custom task)
- **Purpose**: Test built images on both architectures
- **Tests**: Node.js version, npm version, ADB availability

### 5. Security Scan
- **Task**: `trivy-scanner` (custom task)
- **Purpose**: Scan for vulnerabilities in the built image
- **Output**: SARIF format for security reporting

### 6. Push to Registry
- **Task**: `kaniko` (conditional)
- **Purpose**: Push image to Docker registry
- **Condition**: Only runs when `push-image=true`

## ⚙️ Configuration

### Pipeline Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `git-url` | Git repository URL | `https://github.com/nicholashaven/adb-butler.git` |
| `git-revision` | Git revision to checkout | `main` |
| `image-name` | Docker image name | `adb-butler` |
| `image-tag` | Docker image tag | `latest` |
| `registry-url` | Docker registry URL | `docker.io` |
| `push-image` | Whether to push image | `false` |

### Environment Variables

Set these environment variables for registry access:

```bash
export DOCKER_USERNAME="your-username"
export DOCKER_PASSWORD="your-password"
```

### Docker Registry Secret

Create a Docker registry secret:

```bash
kubectl create secret docker-registry docker-registry-secret \
  --docker-server=docker.io \
  --docker-username=$DOCKER_USERNAME \
  --docker-password=$DOCKER_PASSWORD \
  --namespace=tekton-pipelines
```

## 📊 Pipeline Execution

### Development Pipeline

```bash
# Run development pipeline
./scripts/tekton-deploy.sh dev
```

**Features:**
- Builds multi-architecture image
- Runs tests on both architectures
- Does NOT push to registry
- Faster execution (20m timeout)

### Production Pipeline

```bash
# Run production pipeline
./scripts/tekton-deploy.sh prod
```

**Features:**
- Builds multi-architecture image
- Runs comprehensive tests
- Security scanning
- Pushes to registry
- Longer timeout (45m)

## 🔍 Monitoring

### View Pipeline Status

```bash
# Check pipeline runs
kubectl get pipelinerun -n tekton-pipelines

# Check task runs
kubectl get taskrun -n tekton-pipelines

# View pipeline logs
kubectl logs -f pipelinerun/<pipelinerun-name> -n tekton-pipelines
```

### View Task Logs

```bash
# View specific task logs
kubectl logs -f taskrun/<taskrun-name> -n tekton-pipelines

# View all logs for a pipeline run
kubectl logs -f pipelinerun/<pipelinerun-name> -n tekton-pipelines --all-containers
```

## 🛠️ Customization

### Modify Pipeline

Edit `pipeline.yaml` to:
- Add new tasks
- Modify task parameters
- Change task execution order
- Add conditional execution

### Add Custom Tasks

Create new tasks in `tasks/` directory:
- Follow Tekton task specification
- Use appropriate base images
- Include proper error handling

### Modify PipelineRuns

Edit PipelineRun files to:
- Change image tags
- Modify timeouts
- Adjust resource requests
- Add custom parameters

## 🔒 Security

### RBAC Configuration

The pipeline uses a dedicated service account with minimal required permissions:
- Read access to pods and logs
- Create/update/delete PVCs
- Full access to Tekton resources

### Security Scanning

The pipeline includes Trivy security scanning:
- Scans for known vulnerabilities
- Configurable severity levels
- SARIF output for integration

## 🚨 Troubleshooting

### Common Issues

1. **Tekton not installed**
   ```bash
   kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
   ```

2. **Registry authentication failed**
   ```bash
   kubectl create secret docker-registry docker-registry-secret \
     --docker-server=docker.io \
     --docker-username=$DOCKER_USERNAME \
     --docker-password=$DOCKER_PASSWORD \
     --namespace=tekton-pipelines
   ```

3. **Insufficient resources**
   - Check cluster capacity
   - Adjust resource requests in PipelineRun

4. **Build timeout**
   - Increase timeout in PipelineRun
   - Check network connectivity

### Debug Commands

```bash
# Check Tekton installation
kubectl get pods -n tekton-pipelines

# Check pipeline status
kubectl describe pipelinerun <name> -n tekton-pipelines

# Check task run status
kubectl describe taskrun <name> -n tekton-pipelines

# View events
kubectl get events -n tekton-pipelines --sort-by=.metadata.creationTimestamp
```

## 📚 Additional Resources

- [Tekton Documentation](https://tekton.dev/docs/)
- [Tekton Catalog](https://github.com/tektoncd/catalog)
- [Kaniko Documentation](https://github.com/GoogleContainerTools/kaniko)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Hadolint Documentation](https://github.com/hadolint/hadolint)
