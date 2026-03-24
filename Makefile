IMAGE_NAME ?= ghcr.io/drgrovesoftwarellc/trust-pkg-stagex
VERSION ?= sx2026.03.0
SOURCE_DATE_EPOCH ?= $(shell git log -1 --pretty=%ct 2>/dev/null || echo 0)

.PHONY: build push scan verify clean

build:
	docker buildx build \
		--build-arg VERSION=$(VERSION) \
		-f Containerfile \
		-t $(IMAGE_NAME):$(VERSION) \
		.

push:
	docker buildx build \
		--build-arg VERSION=$(VERSION) \
		-f Containerfile \
		--push \
		-t $(IMAGE_NAME):$(VERSION) \
		.

scan: build
	trivy image --severity CRITICAL,HIGH --exit-code 1 $(IMAGE_NAME):$(VERSION)

verify:
	slsa-verifier verify-image \
		"$(IMAGE_NAME)@$(DIGEST)" \
		--source-uri github.com/DRGroveSoftwareLLC/trust-pkg-stagex \
		--source-tag "$(VERSION)"

clean:
	docker rmi $(IMAGE_NAME):$(VERSION) 2>/dev/null || true
