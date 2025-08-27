OWNER=nicholashaven
IMAGE_NAME=adb-butler
VCS_REF=`git rev-parse --short HEAD`
IMAGE_VERSION ?= 2.0.0
PROXY ?=
QNAME=$(PROXY)$(OWNER)/$(IMAGE_NAME)
GIT_TAG=$(QNAME):$(VCS_REF)
BUILD_TAG=$(QNAME):$(IMAGE_VERSION)
LATEST_TAG=$(QNAME):latest
ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

build:
	docker build \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg IMAGE_VERSION=$(IMAGE_VERSION) \
		-t $(GIT_TAG) .

buildx:
	docker buildx build \
		--platform linux/amd64,linux/arm64 \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg IMAGE_VERSION=$(IMAGE_VERSION) \
		-t $(GIT_TAG) \
		--push .

lint:
	docker run --rm -v "$(ROOT_DIR)/Dockerfile:/Dockerfile:ro" hadolint/hadolint:latest-alpine

tag:
	docker tag $(GIT_TAG) $(BUILD_TAG)
	docker tag $(GIT_TAG) $(LATEST_TAG)

login:
	@docker login -u "$(DOCKER_USER)" -p "$(DOCKER_PASS)" "$(PROXY)"

push: login
	docker push $(GIT_TAG)
	docker push $(BUILD_TAG)
	docker push $(LATEST_TAG)
