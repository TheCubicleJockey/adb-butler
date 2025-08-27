# ADB Butler

ADB Butler is a side-car container component for Android device management that runs ADB server in Kubernetes deployments of OpenSTF providers. It provides self-healing capabilities and device management automation.

## 🚀 Features

- **Self-healing capabilities**:
  - Automatically reconnects devices missing from ADB server by rebinding USB drivers
  - Reconnects devices missing or unstable in OpenSTF by restarting ADB connections
- **Database management**: Cleans up RethinkDB for temporary emulators that are no longer available
- **Device labeling**: Adds notes to provided devices for better organization
- **Test automation**: Automatically installs Test Butler for emulators
- **Health monitoring**: Built-in health checks and monitoring capabilities

## 🛠️ Building

### Using Docker directly:
```bash
docker build -t adb-butler .
```

### Using Makefile:
```bash
# Set environment variables
export DOCKER_USER=your-username
export DOCKER_PASS=your-password

# Build and push
make PROXY=docker-registry-url/ build tag login push
```

### Using GitHub Actions:
The project includes automated CI/CD with GitHub Actions that will:
- Lint the Dockerfile
- Build and test multi-architecture images (x86_64, ARM64)
- Deploy to Docker Hub on main branch pushes

### Using Tekton (Kubernetes-native CI/CD):
The project also includes a Tekton pipeline for cloud-native CI/CD:
- Multi-architecture builds (x86_64, ARM64)
- Dockerfile linting with hadolint
- Security scanning with Trivy
- Kubernetes-native execution

```bash
# Deploy Tekton pipeline
./scripts/tekton-deploy.sh deploy

# Run development pipeline
./scripts/tekton-deploy.sh dev

# Run production pipeline
./scripts/tekton-deploy.sh prod
```

See [Tekton documentation](tekton/README.md) for detailed setup and usage.

### Multi-Architecture Builds:
```bash
# Build for multiple architectures
./scripts/build-multiarch.sh build

# Build and push to registry
./scripts/build-multiarch.sh push docker.io

# Test built images
./scripts/build-multiarch.sh test
```

## 🔧 Configuration

### Environment Variables:
- `STF_PROVIDER_PUBLIC_IP`: IP address of the emulator (required for emulator mode)
- `STF_PROVIDER_NOTE`: Note to add to devices
- `RETHINKDB_URL`: RethinkDB host
- `RETHINKDB_PORT`: RethinkDB port
- `RETHINKDB_ENV_AUTHKEY`: RethinkDB authentication key

## 📦 Image Details

- **Base Image**: Alpine Linux 3.19
- **Supported Architectures**: x86_64 (amd64), ARM64
- **ADB Version**: 1.0.41 (29.0.6-6198805) - *x86_64 only*
- **Node.js**: v20.15.1
- **Supervisor**: 4.2.5
- **glibc**: 2.35-r1

### 🏗️ Architecture Support

| Architecture | ADB Support | Node.js Support | Use Case |
|--------------|-------------|-----------------|----------|
| x86_64 (amd64) | ✅ Full | ✅ Full | Production ADB server |
| ARM64 | ❌ Limited* | ✅ Full | Node.js services only |

*Note: Google doesn't provide ARM64 versions of Android Platform Tools. ARM64 builds will work for Node.js services but won't have ADB functionality.

# License

adb-butler is open source and available under the [Apache License, Version 2.0](LICENSE).

Android SDK components are available under the [Android Software Development Kit License](https://developer.android.com/studio/terms.html)
