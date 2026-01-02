# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

# Configuration
VELERO_VERSION := 11.3.1
VELERO_CRDS_URL := https://raw.githubusercontent.com/vmware-tanzu/helm-charts/velero-$(VELERO_VERSION)/charts/velero/crds
GITHUB_API_URL := https://api.github.com/repos/vmware-tanzu/helm-charts/contents/charts/velero/crds?ref=velero-$(VELERO_VERSION)
CRDS_DIR := crds
CHART_DIR := chart
CHART_DIST := dist
CHART_NAME := velero-crds
STATIC_DIR := static
HELM_REGISTRY := ghcr.io
HELM_REPO := $(HELM_REGISTRY)/clastix/charts

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

## Tool Binaries
HELM ?= $(LOCALBIN)/helm

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

# VERSION defines the current version.
# Its value is extracted from the latest available tag.
VERSION ?= $(or $(shell git describe --abbrev=0 --tags 2>/dev/null),$(GIT_HEAD_COMMIT))

.PHONY: all
all: fetch-crds package ## Fetch CRDs and package the Helm chart

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# Default target
all: fetch-crds package

##@ Development

.PHONY: fetch-crds
fetch-crds: ## Fetch Velero CRDs from GitHub
	@./fetch-crds.sh

.PHONY: setup-chart
setup-chart: fetch-crds ## Set up Helm chart structure
	@echo "Setting up Helm chart structure..."
	@mkdir -p $(CHART_DIR)/templates
	@cp $(STATIC_DIR)/Chart.yaml $(CHART_DIR)/
	@cp $(STATIC_DIR)/README.md $(CHART_DIR)/
	@cp $(STATIC_DIR)/values.yaml $(CHART_DIR)/
	@cp $(STATIC_DIR)/.helmignore $(CHART_DIR)/
	@cp templates/_helpers.tpl $(CHART_DIR)/templates/
	@# Process each CRD to create proper Helm templates with full structure and templating
	@VERSION=$(VERSION) ./generate-templates.sh
	@echo "Helm chart structure created in $(CHART_DIR)/"

.PHONY: clean
clean: ## Clean up build artifacts
	rm -f $(CHART_DIST)/*.tgz

.PHONY: lint
lint: $(HELM) ## Helm lint
	$(HELM) lint $(CHART_DIR)

.PHONY: test
test: $(HELM) ## Helm template
	$(HELM) template --debug $(CHART_DIR)

##@ Build

.PHONY: install
install: $(HELM) ## Install Helm chart
	$(HELM) install velero-crds $(CHART_DIR)

.PHONY: uninstall
uninstall: $(HELM) ## Uninstall Helm chart
	$(HELM) uninstall velero-crds

# Get information about git current status
GIT_HEAD_COMMIT ?= $$(git rev-parse --short HEAD)

.PHONY: package
package: setup-chart helm ## Package Helm chart
	sed -i 's/^version: 0.0.0/version: $(VERSION)/' $(CHART_DIR)/Chart.yaml
	sed -i 's/^appVersion: 0.0.0/appVersion: $(VERSION)/' $(CHART_DIR)/Chart.yaml
	$(HELM) package $(CHART_DIR) --version $(VERSION) --destination dist

.PHONY: publish
publish: ## Publish to GitHub Container Registry
	$(HELM) registry login $(HELM_REGISTRY) --username=$(GITHUB_ACTOR) --password=$(GITHUB_TOKEN)
	$(HELM) push $(CHART_DIST)/$(CHART_NAME)-$(VERSION).tgz oci://$(HELM_REPO)

##@ Binary

.PHONY: helm
helm: $(HELM) ## Download helm locally if necessary.
$(HELM): $(LOCALBIN)
	test -s $(LOCALBIN)/helm || GOBIN=$(LOCALBIN) CGO_ENABLED=0 go install -ldflags="-s -w" helm.sh/helm/v3/cmd/helm@v3.9.0
