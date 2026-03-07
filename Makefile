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
	@if [ "$(IMAGE)" = "telegram-transcribe-bot" ]; then \
		podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu 'python -m py_compile /app/bot.py'; \
		podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu 'TELEGRAM_BOT_TOKEN=dummy-telegram-token GROQ_API_KEY=dummy-groq-key AUTHORIZED_USERS=12345 ENABLE_SUMMARY=false python -c "import bot; bot.build_application()"'; \
		podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu '\
			mkdir -p /tmp/secrets; \
			echo "dummy-telegram-token" > /tmp/secrets/telegram_bot_token; \
			echo "dummy-groq-key" > /tmp/secrets/groq_api_key; \
			TELEGRAM_BOT_TOKEN_FILE=/tmp/secrets/telegram_bot_token \
			GROQ_API_KEY_FILE=/tmp/secrets/groq_api_key \
			/app/entrypoint.sh sh -ceu "printenv TELEGRAM_BOT_TOKEN >/dev/null && printenv GROQ_API_KEY >/dev/null"'; \
	elif [ "$(IMAGE)" = "opencode-telegram-bot" ]; then \
		podman run --rm --entrypoint opencode-telegram $(LOCAL_TAG_PREFIX)$(IMAGE):test --help >/dev/null; \
		podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu 'test -d /home/node/.config/opencode-telegram-bot'; \
	elif [ "$(IMAGE)" = "openclaw-browser-node" ]; then \
		podman run --rm --entrypoint openclaw $(LOCAL_TAG_PREFIX)$(IMAGE):test --version >/dev/null; \
		podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu 'test -x /custom-cont-init.d/40-openclaw-init'; \
		podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu 'test -x /custom-services.d/openclaw-node/run'; \
	else \
		echo "No smoke test configured for $(IMAGE)" >&2; \
		exit 1; \
	fi

local-test: local-build local-smoke
