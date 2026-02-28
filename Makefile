SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

IMAGES := $(shell ./scripts/list-images.sh)
LOCAL_TAG_PREFIX ?= local/

.PHONY: help podman-check list-images local-build local-smoke smoke-image local-test

help:
	@echo "Targets:"
	@echo "  make list-images            # list image directories"
	@echo "  make local-build            # build all images with podman"
	@echo "  make local-smoke            # run generic smoke checks inside built images"
	@echo "  make local-test             # build + smoke for all images"
	@echo "  make local-test IMAGE=name  # build + smoke only one image"

podman-check:
	@command -v podman >/dev/null 2>&1 || { echo "podman is required" >&2; exit 1; }

list-images:
	@for image in $(IMAGES); do echo $$image; done

local-build: podman-check
	@if [ -n "$(IMAGE)" ]; then \
		podman build -t $(LOCAL_TAG_PREFIX)$(IMAGE):test -f images/$(IMAGE)/Dockerfile images/$(IMAGE); \
	else \
		for image in $(IMAGES); do \
			echo ">>> building $$image"; \
			podman build -t $(LOCAL_TAG_PREFIX)$$image:test -f images/$$image/Dockerfile images/$$image; \
		done; \
	fi

local-smoke: podman-check
	@if [ -n "$(IMAGE)" ]; then \
		$(MAKE) smoke-image IMAGE=$(IMAGE); \
	else \
		for image in $(IMAGES); do \
			$(MAKE) smoke-image IMAGE=$$image; \
		done; \
	fi

smoke-image: podman-check
	@echo ">>> smoke test $(IMAGE)"
	@podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu 'if [ -f /app/bot.py ]; then python -m py_compile /app/bot.py; fi'
	@podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu '\
		mkdir -p /tmp/secrets; \
		echo "dummy-telegram-token" > /tmp/secrets/telegram_bot_token; \
		echo "dummy-groq-key" > /tmp/secrets/groq_api_key; \
		TELEGRAM_BOT_TOKEN_FILE=/tmp/secrets/telegram_bot_token \
		GROQ_API_KEY_FILE=/tmp/secrets/groq_api_key \
		/app/entrypoint.sh sh -ceu "printenv TELEGRAM_BOT_TOKEN >/dev/null && printenv GROQ_API_KEY >/dev/null"'

local-test: local-build local-smoke
