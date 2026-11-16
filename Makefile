CHART      := charts/t3code
T3_VERSION := $(shell awk -F'"' '/^appVersion:/{print $$2}' $(CHART)/Chart.yaml)
IMAGE      ?= t3code-ci
TAG        ?= ci
KIND       ?= t3

.PHONY: help lint test docs template image kind e2e clean bump

help: ## Show targets
	@grep -E '^[a-z-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

lint: ## helm lint (default + ci values), shellcheck, hadolint
	helm lint $(CHART) --strict
	@for f in $(CHART)/ci/*.yaml; do helm lint $(CHART) --strict -f $$f; done
	shellcheck image/rootfs/usr/local/bin/* scripts/*.sh
	hadolint --ignore DL3008 --ignore DL4006 image/Dockerfile

test: ## helm-unittest
	helm unittest --strict $(CHART)

docs: ## Regenerate chart README (helm-docs)
	helm-docs --chart-search-root charts --template-files README.md.gotmpl

template: ## Render the chart with default values
	helm template t3 $(CHART)

image: ## Build the image for the current T3 version
	docker build --build-arg T3_VERSION=$(T3_VERSION) -t $(IMAGE):$(TAG) image

kind: image ## Create a kind cluster and load the image
	kind get clusters | grep -qx $(KIND) || kind create cluster --name $(KIND)
	kind load docker-image $(IMAGE):$(TAG) --name $(KIND)

e2e: kind ## Install and smoke-test on kind
	KUBE_CONTEXT=kind-$(KIND) IMAGE_REPO=$(IMAGE) IMAGE_TAG=$(TAG) scripts/e2e.sh install
	KUBE_CONTEXT=kind-$(KIND) scripts/e2e.sh smoke

bump: ## Bump to a T3 version: make bump V=0.1.10
	python3 scripts/bump-t3.py $(V) && $(MAKE) docs

clean: ## Delete the kind cluster
	kind delete cluster --name $(KIND)
