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
		podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu 'test -f /custom-services.d/openclaw-node && test -x /custom-services.d/openclaw-node'; \
		podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu 'test -f /custom-services.d/openclaw-cdp-proxy && test -x /custom-services.d/openclaw-cdp-proxy'; \
		podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu 'test -f /usr/local/lib/openclaw-cdp-proxy/index.mjs'; \
		podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu 'test -x /usr/bin/chromium'; \
		podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu 'test -x /usr/bin/chromium-browser'; \
		podman run --rm --entrypoint bash $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu 'source /custom-cont-init.d/40-openclaw-init; [[ "$${CHROME_CLI}" == *"--remote-debugging-address=127.0.0.1"* ]]; [[ "$${CHROME_CLI}" == *"--remote-debugging-port=$${CDP_PORT}"* ]]; [[ "$${CHROME_CLI}" == *"--user-data-dir=$${CHROMIUM_USER_DATA_DIR}"* ]]; [[ "$${OPENCLAW_BROWSER_CDP_URL}" == "http://127.0.0.1:$${CDP_PORT}" ]]'; \
	elif [ "$(IMAGE)" = "chrome-devtools-mcp-proxy" ]; then \
		podman run --rm --entrypoint sh $(LOCAL_TAG_PREFIX)$(IMAGE):test -ceu 'command -v node >/dev/null && command -v npm >/dev/null && command -v mcp-proxy >/dev/null && command -v chrome-devtools-mcp >/dev/null && test -x /usr/local/bin/docker-entrypoint.sh'; \
		podman run --rm --entrypoint mcp-proxy $(LOCAL_TAG_PREFIX)$(IMAGE):test --help >/dev/null; \
		podman run --rm --entrypoint chrome-devtools-mcp $(LOCAL_TAG_PREFIX)$(IMAGE):test --help >/dev/null; \
		mkdir -p .tmp/chrome-devtools-mcp-proxy-smoke; \
		printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"smoke-client","version":"1.0.0"}}}' > .tmp/chrome-devtools-mcp-proxy-smoke/initialize.json; \
		if podman run --rm $(LOCAL_TAG_PREFIX)$(IMAGE):test >.tmp/chrome-devtools-mcp-proxy-smoke/missing-token.log 2>&1; then \
			echo 'expected missing-token startup failure' >&2; \
			exit 1; \
		fi; \
		grep -q 'BROWSER_CDP_BEARER_TOKEN' .tmp/chrome-devtools-mcp-proxy-smoke/missing-token.log; \
		if podman run --rm -e BROWSER_CDP_BEARER_TOKEN=dummy-browser-cdp-token $(LOCAL_TAG_PREFIX)$(IMAGE):test >.tmp/chrome-devtools-mcp-proxy-smoke/missing-api-key.log 2>&1; then \
			echo 'expected missing-api-key startup failure' >&2; \
			exit 1; \
		fi; \
		grep -q 'MCP_PROXY_API_KEY' .tmp/chrome-devtools-mcp-proxy-smoke/missing-api-key.log; \
		if podman run --rm -e BROWSER_CDP_BEARER_TOKEN=dummy-browser-cdp-token -e MCP_PROXY_API_KEY=dummy-incoming-api-key -e CHROME_DEVTOOLS_MCP_EXTRA_ARGS='not-json' $(LOCAL_TAG_PREFIX)$(IMAGE):test >.tmp/chrome-devtools-mcp-proxy-smoke/invalid-extra-args.log 2>&1; then \
			echo 'expected invalid-extra-args startup failure' >&2; \
			exit 1; \
		fi; \
		grep -q 'CHROME_DEVTOOLS_MCP_EXTRA_ARGS must be a JSON array of strings.' .tmp/chrome-devtools-mcp-proxy-smoke/invalid-extra-args.log; \
		if podman run --rm -e BROWSER_CDP_BEARER_TOKEN=dummy-browser-cdp-token -e MCP_PROXY_API_KEY=dummy-incoming-api-key -e CHROME_DEVTOOLS_MCP_EXTRA_ARGS='["--wsEndpoint=ws://override"]' $(LOCAL_TAG_PREFIX)$(IMAGE):test >.tmp/chrome-devtools-mcp-proxy-smoke/forbidden-ws-endpoint.log 2>&1; then \
			echo 'expected forbidden-ws-endpoint startup failure' >&2; \
			exit 1; \
		fi; \
		grep -q 'CHROME_DEVTOOLS_MCP_EXTRA_ARGS may not override required browser connection or telemetry flags: --wsEndpoint=ws://override' .tmp/chrome-devtools-mcp-proxy-smoke/forbidden-ws-endpoint.log; \
		if podman run --rm -e BROWSER_CDP_BEARER_TOKEN=dummy-browser-cdp-token -e MCP_PROXY_API_KEY=dummy-incoming-api-key -e CHROME_DEVTOOLS_MCP_EXTRA_ARGS='["--browser-url=http://override"]' $(LOCAL_TAG_PREFIX)$(IMAGE):test >.tmp/chrome-devtools-mcp-proxy-smoke/forbidden-browser-url.log 2>&1; then \
			echo 'expected forbidden-browser-url startup failure' >&2; \
			exit 1; \
		fi; \
		grep -q 'CHROME_DEVTOOLS_MCP_EXTRA_ARGS may not override required browser connection or telemetry flags: --browser-url=http://override' .tmp/chrome-devtools-mcp-proxy-smoke/forbidden-browser-url.log; \
		if podman run --rm -e BROWSER_CDP_BEARER_TOKEN=dummy-browser-cdp-token -e MCP_PROXY_API_KEY=dummy-incoming-api-key -e CHROME_DEVTOOLS_MCP_EXTRA_ARGS='["--browserUrl=http://override"]' $(LOCAL_TAG_PREFIX)$(IMAGE):test >.tmp/chrome-devtools-mcp-proxy-smoke/forbidden-browserUrl.log 2>&1; then \
			echo 'expected forbidden-browserUrl startup failure' >&2; \
			exit 1; \
		fi; \
		grep -q 'CHROME_DEVTOOLS_MCP_EXTRA_ARGS may not override required browser connection or telemetry flags: --browserUrl=http://override' .tmp/chrome-devtools-mcp-proxy-smoke/forbidden-browserUrl.log; \
		unauth_ctr_id="$$(podman run -d -e BROWSER_CDP_BEARER_TOKEN=dummy-browser-cdp-token -e MCP_PROXY_ALLOW_UNAUTHENTICATED=true -e CHROME_DEVTOOLS_MCP_EXTRA_ARGS='["--headless"]' -e BROWSER_CDP_WS_ENDPOINT=ws://127.0.0.1:9/devtools/browser $(LOCAL_TAG_PREFIX)$(IMAGE):test)"; \
		podman exec "$${unauth_ctr_id}" sh -ceu 'for i in $$(seq 1 50); do curl -fsS http://127.0.0.1:8000/ping >/dev/null 2>/dev/null && exit 0; sleep 0.2; done; exit 1'; \
		podman logs "$${unauth_ctr_id}" > .tmp/chrome-devtools-mcp-proxy-smoke/unauthenticated.log 2>&1; \
		grep -q 'WARNING: Starting without MCP_PROXY_API_KEY because MCP_PROXY_ALLOW_UNAUTHENTICATED=true.' .tmp/chrome-devtools-mcp-proxy-smoke/unauthenticated.log; \
		podman exec "$${unauth_ctr_id}" sh -ceu 'ps -eo args= | grep -Eq "(^|/)[c]hrome-devtools-mcp( |$$).+ --headless( |$$)"'; \
		podman rm -f "$${unauth_ctr_id}" >/dev/null; \
		tmpdir=.tmp/chrome-devtools-mcp-proxy-smoke; \
		printf '%s\n' 'dummy-browser-cdp-token' > "$${tmpdir}/browser_cdp_token"; \
		ctr_id="$$(podman run -d -v "$${tmpdir}:/run/secrets:ro,Z" -e BROWSER_CDP_BEARER_TOKEN_FILE=/run/secrets/browser_cdp_token -e MCP_PROXY_ALLOW_UNAUTHENTICATED=true -e BROWSER_CDP_WS_ENDPOINT=ws://127.0.0.1:9/devtools/browser $(LOCAL_TAG_PREFIX)$(IMAGE):test)"; \
		podman exec "$${ctr_id}" sh -ceu 'for i in $$(seq 1 50); do curl -fsS http://127.0.0.1:8000/ping >/dev/null 2>/dev/null && exit 0; sleep 0.2; done; exit 1'; \
		podman exec "$${ctr_id}" sh -ceu 'for i in $$(seq 1 3); do status="$$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/mcp || true)"; test "$${status}" = 400; done; test "$$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/sse || true)" = 404'; \
		printf '%s\n' 'dummy-incoming-api-key' > "$${tmpdir}/mcp_proxy_api_key"; \
		api_key_ctr_id="$$(podman run -d -v "$${tmpdir}:/run/secrets:ro,Z" -e BROWSER_CDP_BEARER_TOKEN_FILE=/run/secrets/browser_cdp_token -e MCP_PROXY_API_KEY_FILE=/run/secrets/mcp_proxy_api_key -e BROWSER_CDP_WS_ENDPOINT=ws://127.0.0.1:9/devtools/browser $(LOCAL_TAG_PREFIX)$(IMAGE):test)"; \
		podman exec "$${api_key_ctr_id}" sh -ceu 'for i in $$(seq 1 50); do curl -fsS http://127.0.0.1:8000/ping >/dev/null 2>/dev/null && exit 0; sleep 0.2; done; exit 1'; \
		podman exec "$${api_key_ctr_id}" sh -ceu 'test "$$(curl -sS -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/mcp || true)" = 401; test "$$(curl -sS -H "X-API-Key: dummy-incoming-api-key" -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/mcp || true)" = 400'; \
		podman exec "$${api_key_ctr_id}" sh -ceu 'processes="$$(ps -eo args=)"; mcp_proxy_count="$$(printf "%s\n" "$${processes}" | grep -Ec "(^|/)[m]cp-proxy( |$$)")"; chrome_devtools_count="$$(printf "%s\n" "$${processes}" | grep -Ec "(^|/)[c]hrome-devtools-mcp( |$$)")"; if [ "$${mcp_proxy_count}" -ne 1 ] || [ "$${chrome_devtools_count}" -ne 1 ]; then echo "unexpected startup process counts: mcp-proxy=$${mcp_proxy_count} chrome-devtools-mcp=$${chrome_devtools_count}" >&2; printf "%s\n" "$${processes}" >&2; exit 1; fi'; \
		podman cp .tmp/chrome-devtools-mcp-proxy-smoke/initialize.json "$${api_key_ctr_id}:/tmp/initialize.json"; \
		podman exec "$${api_key_ctr_id}" sh -ceu 'curl -i -sS -X POST http://127.0.0.1:8000/mcp -H "X-API-Key: dummy-incoming-api-key" -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" --data-binary @/tmp/initialize.json > /tmp/initialize-response.txt; grep -q "HTTP/1.1 200 OK" /tmp/initialize-response.txt; grep -qi "content-type: text/event-stream" /tmp/initialize-response.txt; grep -qi "mcp-session-id:" /tmp/initialize-response.txt; grep -q "\"jsonrpc\":\"2.0\"" /tmp/initialize-response.txt; grep -q "\"id\":1" /tmp/initialize-response.txt; grep -q "\"name\":\"chrome_devtools\"" /tmp/initialize-response.txt'; \
		podman exec "$${api_key_ctr_id}" sh -ceu 'processes="$$(ps -eo args=)"; mcp_proxy_count="$$(printf "%s\n" "$${processes}" | grep -Ec "(^|/)[m]cp-proxy( |$$)")"; chrome_devtools_count="$$(printf "%s\n" "$${processes}" | grep -Ec "(^|/)[c]hrome-devtools-mcp( |$$)")"; if [ "$${mcp_proxy_count}" -ne 1 ] || [ "$${chrome_devtools_count}" -gt 1 ]; then echo "unexpected post-initialize process counts: mcp-proxy=$${mcp_proxy_count} chrome-devtools-mcp=$${chrome_devtools_count}" >&2; printf "%s\n" "$${processes}" >&2; exit 1; fi; printf "%s\n" "$${processes}" | grep -Eq "(^|/)[m]cp-proxy( |$$).+ -- chrome-devtools-mcp "'; \
		podman rm -f "$${api_key_ctr_id}" >/dev/null; \
		podman rm -f "$${ctr_id}" >/dev/null; \
	elif [ "$(IMAGE)" = "devbox" ]; then \
		podman run --rm $(LOCAL_TAG_PREFIX)$(IMAGE):test bash -lc 'whoami | grep -qx dev'; \
		podman run --rm $(LOCAL_TAG_PREFIX)$(IMAGE):test bash -lc 'test "$$HOME" = /home/dev'; \
		podman run --rm $(LOCAL_TAG_PREFIX)$(IMAGE):test bash -lc 'test -r /etc/profile.d/devbox.sh'; \
		podman run --rm $(LOCAL_TAG_PREFIX)$(IMAGE):test bash -lc 'command -v supervisord >/dev/null && command -v supervisorctl >/dev/null'; \
		podman run --rm $(LOCAL_TAG_PREFIX)$(IMAGE):test bash -lc 'test -x /usr/local/bin/ensure-mise && command -v ensure-mise >/dev/null'; \
		podman run --rm $(LOCAL_TAG_PREFIX)$(IMAGE):test bash -lc 'pipx --version'; \
		podman run --rm $(LOCAL_TAG_PREFIX)$(IMAGE):test bash -lc 'command -v git curl jq rg tmux python3 >/dev/null'; \
		podman run --rm $(LOCAL_TAG_PREFIX)$(IMAGE):test bash -lc '\
			mkdir -p "$$HOME/.cache/supervisor" "$$HOME/.config/supervisor/conf.d"; \
			conf="$$HOME/.config/supervisor/conf.d/echo.conf"; \
			printf "%s\n" \
				"[program:echo-once]" \
				"command=/bin/sleep 60" \
				"autorestart=false" \
				"startsecs=0" \
				"stdout_logfile=/home/dev/.cache/supervisor/echo-once.log" \
				"stderr_logfile=/home/dev/.cache/supervisor/echo-once.err" \
				> "$$conf"; \
			supervisord -c /etc/supervisor/supervisord.conf & \
			for i in $$(seq 1 20); do supervisorctl status >/dev/null 2>&1 && break; sleep 0.2; done; \
			supervisorctl status | grep -q "^echo-once"; \
			supervisorctl shutdown; \
		'; \
		tmp_home="$$(mktemp -d)"; \
		ctr_id="$$(podman run -d -v "$${tmp_home}:/home/dev:U,Z" $(LOCAL_TAG_PREFIX)$(IMAGE):test)"; \
		podman exec "$${ctr_id}" bash -lc 'test -f "$$HOME/.bash_profile" && test -f "$$HOME/.bashrc" && test -f "$$HOME/.config/supervisor/conf.d/README.txt"'; \
		podman exec "$${ctr_id}" bash -lc 'for i in $$(seq 1 50); do mise --version >/dev/null 2>&1 && break; sleep 0.2; done; mise --version'; \
		podman rm -f "$${ctr_id}" >/dev/null; \
		podman run --rm -v "$${tmp_home}:/home/dev:U,Z" $(LOCAL_TAG_PREFIX)$(IMAGE):test bash -lc 'ensure-mise >/dev/null && test -x "$$HOME/.local/bin/mise" && mise --version'; \
		podman run --rm -v "$${tmp_home}:/home/dev:U,Z" $(LOCAL_TAG_PREFIX)$(IMAGE):test bash -lc 'ensure-mise >/dev/null && mise --version'; \
	else \
		echo "No smoke test configured for $(IMAGE)" >&2; \
		exit 1; \
	fi

local-test: local-build local-smoke
