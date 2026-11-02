APP_NAME := Dif
PROJECT := Dif.xcodeproj
SCHEME := Dif
CURRENT_PROJECT_VERSION ?= 1
MARKETING_VERSION ?= $(VERSION)
BUILD_PATH := build
DERIVED_DATA_PATH := $(BUILD_PATH)/DerivedData

.PHONY: help build release test lint check publish clean

.DEFAULT_GOAL := help

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_\-\.]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

all: release ## Run release

---------------: ## ---------------

build: clean ## Build the app in Debug configuration
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED_DATA_PATH) build

release: clean ## Build the app in Release configuration
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-derivedDataPath $(DERIVED_DATA_PATH) -destination generic/platform=macOS build \
		MARKETING_VERSION="$(MARKETING_VERSION)" CURRENT_PROJECT_VERSION="$(CURRENT_PROJECT_VERSION)"

---------------: ## ---------------

test: ## Run tests
	xcodebuild test -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED_DATA_PATH)

lint: ## Run linting
	swiftformat Dif DifTests --lint --cache ignore
	swiftlint --strict --no-cache --config .swiftlint.yml

check: lint test ## Run linting and tests

---------------: ## ---------------

publish: ## Package the app into DMG formats and publish to GitHub releases
	@test -n "$(VERSION)" || { echo "usage: make publish VERSION=x.y.z [PUBLISH=1]" >&2; exit 1; }
	@$(MAKE) release
	./scripts/package.sh $(VERSION) $(if $(PUBLISH),--publish,)

---------------: ## ---------------

clean: ## Clean build directory
	rm -rf "$(BUILD_PATH)"
