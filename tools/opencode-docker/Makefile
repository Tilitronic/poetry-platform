.PHONY: build build-latest run shell clean tag-latest build-builder-tools

USER_UID := $(shell id -u)
USER_GID := $(shell id -g)
VERSION ?=

COMMON_DOCKER_FLAGS := --rm -it --userns=keep-id --read-only --tmpfs /tmp:exec,size=512m --cap-drop=ALL --security-opt=no-new-privileges --shm-size=1g --memory=4g --cpus=4
COMMON_VOLUME_FLAGS := -v $(shell pwd)/homebase/.local/share:/app/.local/share:rw,z -v $(shell pwd)/homebase/.local/state:/app/.local/state:rw,z -v $(shell pwd)/config:/app/.config/opencode:rw,z -v $(shell pwd)/homebase/.cache:/app/.cache:rw,z -v $(shell pwd)/workspace:/workspace:rw,z -v $(shell pwd)/secrets:/run/secrets:ro,Z

build:
	podman build --load --build-arg USER_UID=$(USER_UID) --build-arg USER_GID=$(USER_GID) $(if $(VERSION),--build-arg OPENCODE_VERSION=$(VERSION),) -t opencode-docker$(if $(VERSION),:$(VERSION),) .

build-builder-tools:
	podman build --build-arg USER_UID=$(USER_UID) --build-arg USER_GID=$(USER_GID) $(if $(VERSION),--build-arg OPENCODE_VERSION=$(VERSION),) --target builder-tools -t opencode-docker:builder-tools .

tag-latest:
ifndef VERSION
	$(error VERSION is required. Usage: make tag-latest VERSION=1.3.17)
endif
	podman tag opencode-docker:$(VERSION) opencode-docker:latest

build-latest:
	@VERSION=$$(curl -sf https://api.github.com/repos/anomalyco/opencode/releases/latest | jq -r '.tag_name' | sed 's/^v//') && \
	if [ -z "$$VERSION" ] || [ "$$VERSION" = "null" ]; then echo "Error: failed to fetch latest version" >&2; exit 1; fi && \
	echo "Building opencode-docker:$$VERSION..." && \
	$(MAKE) build VERSION=$$VERSION && \
	$(MAKE) tag-latest VERSION=$$VERSION

# Development targets: use local directories (./homebase, ./workspace, ./secrets)
# For regular use, prefer: bin/opencode-docker (uses ~/.opencode-docker/)

run:
	podman run $(COMMON_DOCKER_FLAGS) \
		$(COMMON_VOLUME_FLAGS) \
		opencode-docker:latest /workspace

shell: build-builder-tools
	podman run $(COMMON_DOCKER_FLAGS) \
		$(COMMON_VOLUME_FLAGS) \
		--entrypoint /bin/bash \
		opencode-docker:builder-tools

clean:
	podman rmi opencode-docker:builder-tools || true
	podman rmi opencode-docker || true
