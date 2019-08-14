BASH ?= bash
GO ?= go
DOCKER ?= docker
FLAGS ?= -ldflags '-w -s'
OUT ?= controller

IMAGE := gravitational/nginx-controller
VER := 0.0.1
REGISTRY := quay.io

# build Go executable
.PHONY: build
build:
	$(GO) build $(FLAGS) -o $(OUT) .

# install Go executable
.PHONY: install
install:
	$(GO) install .

# generate Kubernetes client stubs
.PHONY: generate
generate:
	$(BASH) generate.sh

# remove built Go executable
.PHONY: clean
clean:
	rm -rf $(OUT)

# build Docker image
.PHONY: docker
docker: build
	$(DOCKER) build -t $(IMAGE):$(VER) .

# push Docker image to the registry
.PHONY: push
push: docker
	$(DOCKER) tag $(IMAGE):$(VER) $(REGISTRY)/$(IMAGE):$(VER)
	$(DOCKER) push $(REGISTRY)/$(IMAGE):$(VER)
