DOCKER_IMAGE_NAME=supermock/supernode
DOCKER_IMAGE_VERSION=v$(N2N_VERSION)
DOCKER_BUILD_CONTEXT=./n2n

clone_n2n:
	git clone https://github.com/ntop/n2n

pre_target:
	if [ ! -d ./n2n ]; then echo "Before continue please execute 'make clone_n2n' command"; exit 1; fi
	if [ "$(N2N_VERSION)" = "" ]; then echo "Required N2N_VERSION, example: 2.4"; exit 1; fi

platforms: pre_target
	if [ "$(TARGET_ARCHITECTURE)" = "arm32v7" ] || [ "$(TARGET_ARCHITECTURE)" = "" ]; then DOCKER_IMAGE_FILENAME="Dockerfile.arm32v7" DOCKER_IMAGE_TAGNAME=$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_VERSION)-arm32v7 make build; fi
	if [ "$(TARGET_ARCHITECTURE)" = "x86_64" ] || [ "$(TARGET_ARCHITECTURE)" = "" ]; then DOCKER_IMAGE_FILENAME="Dockerfile.x86_64" DOCKER_IMAGE_TAGNAME=$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_VERSION)-x86_64 make build; fi

build:
	$(eval OS := $(shell uname -s))
	$(eval ARCHITECTURE := $(shell export DOCKER_IMAGE_TAGNAME="$(DOCKER_IMAGE_TAGNAME)"; echo $$DOCKER_IMAGE_TAGNAME | grep -oe -.*))

	docker build --target builder --build-arg COMMIT_HASH=$(N2N_COMMIT_HASH) -t $(DOCKER_IMAGE_TAGNAME) -f image-platforms/$(DOCKER_IMAGE_FILENAME) $(DOCKER_BUILD_CONTEXT)

	docker container create --name n2n-builder $(DOCKER_IMAGE_TAGNAME)
	if [ ! -d "./build" ]; then mkdir ./build; fi
	docker container cp n2n-builder:/usr/src/n2n/supernode ./build/supernode-$(OS)$(ARCHITECTURE)
	docker container cp n2n-builder:/usr/src/n2n/edge ./build/edge-$(OS)$(ARCHITECTURE)
	docker container rm -f n2n-builder

	docker build --cache-from $(DOCKER_IMAGE_TAGNAME) \
		--build-arg COMMIT_HASH=$(N2N_COMMIT_HASH) \
		-t $(DOCKER_IMAGE_TAGNAME) \
		-t $(DOCKER_IMAGE_NAME):latest$(ARCHITECTURE) \
		-f image-platforms/$(DOCKER_IMAGE_FILENAME) $(DOCKER_BUILD_CONTEXT)

pre_push: pre_target
	if [ "$(TARGET_ARCHITECTURE)" = "" ]; then \
		echo "Please pass TARGET_ARCHITECTURE, see README.md."; \
		exit 1; \
	fi

push: pre_push
	docker push $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_VERSION)-$(TARGET_ARCHITECTURE)
	docker push $(DOCKER_IMAGE_NAME):latest-$(TARGET_ARCHITECTURE)

.PHONY: clone_n2n pre_target platforms build pre_push push
.SILENT: pre_target pre_push