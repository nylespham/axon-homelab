# Build the Flask app image and push it to the private ECR repository
# (terraform/ecr.tf), then deploy it to EKS.
#
#   make push      # build, log in, push <git-sha> tag, wait for the scan
#   make deploy    # point kubernetes/app at the pushed tag and roll it out
#   make help
#
# Override anything on the command line, e.g. make push CONTAINER_TOOL=docker

AWS_REGION     ?= us-west-2
REPO_NAME      ?= vulnerable-flask
PLATFORM       ?= linux/amd64   # EKS nodes are x86_64 (AL2023_x86_64_STANDARD)
CONTAINER_TOOL ?= $(shell command -v podman >/dev/null 2>&1 && echo podman || echo docker)

# Tags are immutable in ECR, so one tag = one commit. A dirty tree would
# push code that doesn't match its tag: refused unless ALLOW_DIRTY=1.
GIT_SHA     := $(shell git rev-parse --short=12 HEAD)
GIT_DIRTY   := $(shell git status --porcelain --untracked-files=no -- app)
TAG         ?= $(GIT_SHA)
ALLOW_DIRTY ?= 0

AWS_ACCOUNT_ID = $(shell aws sts get-caller-identity --query Account --output text)
REGISTRY       = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
IMAGE          = $(REGISTRY)/$(REPO_NAME)

APP_DIR   := app
KUSTOMIZE := kubernetes/app

.DEFAULT_GOAL := help
.PHONY: help build login check-clean check-tag push scan set-image deploy print

help: ## Show targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*## "}; {printf "  %-12s %s\n", $$1, $$2}'

print: ## Show the resolved image and tool
	@echo "image: $(IMAGE):$(TAG)"
	@echo "tool:  $(CONTAINER_TOOL) ($(strip $(PLATFORM)))"

build: ## Build the image for the node platform
	$(CONTAINER_TOOL) build --platform $(strip $(PLATFORM)) \
	  --label org.opencontainers.image.revision=$(GIT_SHA) \
	  -t $(IMAGE):$(TAG) $(APP_DIR)

login: ## Log in to ECR (token from your current AWS credentials, valid 12h)
	aws ecr get-login-password --region $(AWS_REGION) | \
	  $(CONTAINER_TOOL) login --username AWS --password-stdin $(REGISTRY)

check-clean:
ifneq ($(ALLOW_DIRTY),1)
	@if [ -n "$(GIT_DIRTY)" ]; then \
	  echo "app/ has uncommitted changes: commit first, or ALLOW_DIRTY=1 with a custom TAG"; exit 1; \
	fi
endif

check-tag:
	@if aws ecr describe-images --region $(AWS_REGION) --repository-name $(REPO_NAME) \
	     --image-ids imageTag=$(TAG) >/dev/null 2>&1; then \
	  echo "$(REPO_NAME):$(TAG) already exists (tags are immutable): nothing to push"; exit 1; \
	fi

push: check-clean check-tag build login ## Build and push $(TAG), then wait for the scan
	$(CONTAINER_TOOL) push $(IMAGE):$(TAG)
	@$(MAKE) --no-print-directory scan TAG=$(TAG)

scan: ## Wait for the ECR scan of $(TAG) and print severity counts
	aws ecr wait image-scan-complete --region $(AWS_REGION) \
	  --repository-name $(REPO_NAME) --image-id imageTag=$(TAG)
	aws ecr describe-image-scan-findings --region $(AWS_REGION) \
	  --repository-name $(REPO_NAME) --image-id imageTag=$(TAG) \
	  --query 'imageScanFindings.findingSeverityCounts' --output table

set-image: ## Point kubernetes/app/kustomization.yaml at $(TAG)
	sed -i.bak -e 's|newName: .*|newName: $(IMAGE)|' -e 's|newTag: .*|newTag: "$(TAG)"|' \
	  $(KUSTOMIZE)/kustomization.yaml && rm -f $(KUSTOMIZE)/kustomization.yaml.bak

deploy: set-image ## Deploy $(TAG) to the cluster and wait for the rollout
	kubectl apply -k $(KUSTOMIZE)
	kubectl -n vulnerable-app rollout status deployment/vulnerable-flask --timeout=180s
