import { createServer } from 'node:http';
import { randomUUID, timingSafeEqual } from 'node:crypto';
import { readFileSync } from 'node:fs';
import process from 'node:process';

import WebSocket, { WebSocketServer } from 'ws';

const rawCdpBaseUrl = envOrDefault('OPENCLAW_BROWSER_CDP_URL', `http://127.0.0.1:${envOrDefault('CDP_PORT', '9222')}`);
const proxyHost = envOrDefault('CDP_PROXY_HOST', '0.0.0.0');
const proxyPort = parsePort('CDP_PROXY_PORT', envOrDefault('CDP_PROXY_PORT', '9223'));
const browserWsPath = normalizePath(envOrDefault('CDP_PROXY_BROWSER_WS_PATH', '/devtools/browser'));
const jsonVersionPath = normalizePath(envOrDefault('CDP_PROXY_JSON_VERSION_PATH', '/json/version'));
const exposeJsonVersion = isTrue(envOrDefault('CDP_PROXY_EXPOSE_JSON_VERSION', 'true'));
const upstreamTimeoutMs = parsePositiveInteger('CDP_PROXY_UPSTREAM_TIMEOUT_MS', envOrDefault('CDP_PROXY_UPSTREAM_TIMEOUT_MS', '2000'));
const upstreamRetryAttempts = parsePositiveInteger('CDP_PROXY_UPSTREAM_RETRY_ATTEMPTS', envOrDefault('CDP_PROXY_UPSTREAM_RETRY_ATTEMPTS', '5'));
const upstreamRetryDelayMs = parseNonNegativeInteger('CDP_PROXY_UPSTREAM_RETRY_DELAY_MS', envOrDefault('CDP_PROXY_UPSTREAM_RETRY_DELAY_MS', '250'));
const bearerToken = resolveBearerToken();

if (!bearerToken) {
  throw new Error('CDP proxy requires CDP_PROXY_BEARER_TOKEN or CDP_PROXY_BEARER_TOKEN_FILE');
}

const server = createServer(async (req, res) => {
  try {
    if (!authorizeRequest(req, res)) {
      return;
    }

    if (req.method === 'GET' && req.url && normalizePath(getPathname(req.url)) === jsonVersionPath && exposeJsonVersion) {
      const upstreamMetadata = await fetchJsonVersionWithRetry();
      const response = {
        ...upstreamMetadata,
        webSocketDebuggerUrl: buildExternalBrowserWsUrl(req),
      };

      return sendJson(res, 200, response);
    }

    sendJson(res, 404, { error: 'Not Found' });
  } catch (error) {
    logError('HTTP request failed', error);

    if (!res.headersSent) {
      const statusCode = isUpstreamUnavailableError(error) ? 503 : 500;
      sendJson(res, statusCode, { error: statusCode === 503 ? 'Upstream CDP unavailable' : 'Internal Server Error' });
    }
  }
});

const websocketServer = new WebSocketServer({ noServer: true });

server.on('upgrade', async (req, socket, head) => {
  try {
    if (!req.url || normalizePath(getPathname(req.url)) !== browserWsPath) {
      rejectUpgrade(socket, 404, 'Not Found');
      return;
    }

    if (!hasValidBearerAuthorization(req.headers.authorization, bearerToken)) {
      rejectUpgrade(socket, 401, 'Unauthorized');
      return;
    }

    const upstreamMetadata = await fetchJsonVersionWithRetry();
    const upstreamWsUrl = upstreamMetadata.webSocketDebuggerUrl;

    if (typeof upstreamWsUrl !== 'string' || upstreamWsUrl.length === 0) {
      rejectUpgrade(socket, 503, 'Upstream CDP unavailable');
      return;
    }

    websocketServer.handleUpgrade(req, socket, head, (downstreamSocket) => {
      void bridgeBrowserSocket(downstreamSocket, upstreamWsUrl);
    });
  } catch (error) {
    logError('WebSocket upgrade failed', error);
    rejectUpgrade(socket, isUpstreamUnavailableError(error) ? 503 : 500, isUpstreamUnavailableError(error) ? 'Upstream CDP unavailable' : 'Internal Server Error');
  }
});

server.listen(proxyPort, proxyHost, () => {
  log(`listening on http://${proxyHost}:${proxyPort}${browserWsPath}`);
  log(`authenticated /json/version ${exposeJsonVersion ? `enabled at ${jsonVersionPath}` : 'disabled'}`);
  log(`proxying Chromium CDP from ${rawCdpBaseUrl}`);
});

async function bridgeBrowserSocket(downstreamSocket, upstreamWsUrl) {
  const connectionId = randomUUID();
  log(`accepted browser websocket connection ${connectionId}`);

  const upstreamSocket = new WebSocket(upstreamWsUrl, {
    handshakeTimeout: upstreamTimeoutMs,
  });

  let closed = false;
  const bufferedMessages = [];

  const closeBoth = (code = 1011, reason = 'Proxy connection closed') => {
    if (closed) {
      return;
    }

    closed = true;

    if (downstreamSocket.readyState === WebSocket.OPEN || downstreamSocket.readyState === WebSocket.CONNECTING) {
      downstreamSocket.close(code, reason);
    }

    if (upstreamSocket.readyState === WebSocket.OPEN || upstreamSocket.readyState === WebSocket.CONNECTING) {
      upstreamSocket.close();
    }
  };

  upstreamSocket.on('open', () => {
    for (const [data, isBinary] of bufferedMessages) {
      upstreamSocket.send(data, { binary: isBinary });
    }

    bufferedMessages.length = 0;

    downstreamSocket.on('message', (data, isBinary) => {
      if (upstreamSocket.readyState === WebSocket.OPEN) {
        upstreamSocket.send(data, { binary: isBinary });
      }
    });

    upstreamSocket.on('message', (data, isBinary) => {
      if (downstreamSocket.readyState === WebSocket.OPEN) {
        downstreamSocket.send(data, { binary: isBinary });
      }
    });
  });

  downstreamSocket.on('close', () => {
    closeBoth(1000, 'Client closed connection');
    log(`closed browser websocket connection ${connectionId}`);
  });

  downstreamSocket.on('message', (data, isBinary) => {
    if (upstreamSocket.readyState === WebSocket.CONNECTING) {
      bufferedMessages.push([data, isBinary]);
    }
  });

  downstreamSocket.on('error', (error) => {
    logError(`downstream websocket error (${connectionId})`, error);
    closeBoth();
  });

  upstreamSocket.on('close', () => {
    closeBoth(1000, 'Browser closed connection');
  });

  upstreamSocket.on('error', (error) => {
    logError(`upstream websocket error (${connectionId})`, error);
    closeBoth();
  });
}

async function fetchJsonVersionWithRetry() {
  let lastError = null;

  for (let attempt = 1; attempt <= upstreamRetryAttempts; attempt += 1) {
    try {
      return await fetchJsonVersionOnce();
    } catch (error) {
      lastError = error;

      if (!isRetryableUpstreamError(error) || attempt === upstreamRetryAttempts) {
        throw error;
      }

      await sleep(upstreamRetryDelayMs);
    }
  }

  throw lastError ?? new UpstreamUnavailableError('Failed to fetch upstream /json/version');
}

async function fetchJsonVersionOnce() {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), upstreamTimeoutMs);
  timeout.unref?.();

  try {
    const response = await fetch(`${rawCdpBaseUrl}/json/version`, {
      signal: controller.signal,
      headers: {
        accept: 'application/json',
      },
    });

    if (!response.ok) {
      throw new UpstreamUnavailableError(`Upstream /json/version returned ${response.status}`);
    }

    return await response.json();
  } catch (error) {
    if (error instanceof UpstreamUnavailableError) {
      throw error;
    }

    if (error?.name === 'AbortError') {
      throw new UpstreamUnavailableError('Timed out waiting for upstream /json/version');
    }

    throw new UpstreamUnavailableError('Failed to reach upstream /json/version', { cause: error });
  } finally {
    clearTimeout(timeout);
  }
}

function authorizeRequest(req, res) {
  if (hasValidBearerAuthorization(req.headers.authorization, bearerToken)) {
    return true;
  }

  sendJson(res, 401, { error: 'Unauthorized' }, { 'WWW-Authenticate': 'Bearer' });
  return false;
}

function resolveBearerToken() {
  const tokenFile = process.env.CDP_PROXY_BEARER_TOKEN_FILE;
  if (tokenFile) {
    const fileContents = readSecretFile(tokenFile);
    if (fileContents) {
      return fileContents;
    }
  }

  return envOrDefault('CDP_PROXY_BEARER_TOKEN', '').trim();
}

function readSecretFile(filePath) {
  try {
    return readFileSync(filePath, 'utf8').trim();
  } catch {
    return undefined;
  }
}

function normalizePath(value) {
  return value.startsWith('/') ? value : `/${value}`;
}

function getPathname(requestUrl) {
  return new URL(requestUrl, 'http://127.0.0.1').pathname;
}

function buildExternalBrowserWsUrl(req) {
  const publicScheme = envOrDefault('CDP_PROXY_PUBLIC_SCHEME', '').trim();
  const publicHost = envOrDefault('CDP_PROXY_PUBLIC_HOST', '').trim();
  const publicPort = envOrDefault('CDP_PROXY_PUBLIC_PORT', '').trim();

  const forwardedProto = firstHeaderValue(req.headers['x-forwarded-proto']);
  const forwardedHost = firstHeaderValue(req.headers['x-forwarded-host']);
  const hostHeader = firstHeaderValue(req.headers.host);

  const host = publicHost || forwardedHost || hostHeader;
  if (!host) {
    throw new Error('Unable to determine external host for rewritten webSocketDebuggerUrl');
  }

  const wsScheme = publicScheme || forwardedProtoToWebSocketScheme(forwardedProto) || 'ws';
  const authority = publicPort ? `${stripPort(host)}:${publicPort}` : host;
  return `${wsScheme}://${authority}${browserWsPath}`;
}

function stripPort(host) {
  if (host.startsWith('[')) {
    return host;
  }

  return host.replace(/:\d+$/, '');
}

function forwardedProtoToWebSocketScheme(proto) {
  if (!proto) {
    return null;
  }

  return proto.toLowerCase() === 'https' ? 'wss' : 'ws';
}

function firstHeaderValue(value) {
  const rawValue = Array.isArray(value) ? value[0] ?? '' : value ?? '';
  return rawValue.split(',')[0]?.trim() ?? '';
}

function hasValidBearerAuthorization(authorizationHeader, expectedToken) {
  if (!authorizationHeader) {
    return false;
  }

  const parts = authorizationHeader.trim().split(/\s+/);
  if (parts.length !== 2) {
    return false;
  }

  const [scheme, token] = parts;
  return scheme.toLowerCase() === 'bearer' && safeEquals(token, expectedToken);
}

function safeEquals(left, right) {
  const leftBuffer = Buffer.from(left, 'utf8');
  const rightBuffer = Buffer.from(right, 'utf8');

  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }

  return timingSafeEqual(leftBuffer, rightBuffer);
}

function sendJson(res, statusCode, payload, extraHeaders = {}) {
  res.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    ...extraHeaders,
  });
  res.end(JSON.stringify(payload));
}

function rejectUpgrade(socket, statusCode, statusText) {
  socket.write(`HTTP/1.1 ${statusCode} ${statusText}\r\nConnection: close\r\nContent-Length: 0\r\n\r\n`);
  socket.destroy();
}

function isTrue(value) {
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
}

function parsePort(name, value) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > 65535) {
    throw new Error(`${name} must be a valid TCP port, got: ${value}`);
  }

  return parsed;
}

function parsePositiveInteger(name, value) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new Error(`${name} must be a positive integer, got: ${value}`);
  }

  return parsed;
}

function parseNonNegativeInteger(name, value) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new Error(`${name} must be a non-negative integer, got: ${value}`);
  }

  return parsed;
}

function envOrDefault(name, fallback) {
  const value = process.env[name];
  return value === undefined || value === '' ? fallback : value;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isRetryableUpstreamError(error) {
  return error instanceof UpstreamUnavailableError;
}

function isUpstreamUnavailableError(error) {
  return error instanceof UpstreamUnavailableError;
}

function log(message) {
  console.log(`[openclaw-cdp-proxy] ${message}`);
}

function logError(message, error) {
  if (error instanceof UpstreamUnavailableError) {
    console.error(`[openclaw-cdp-proxy] ${message}: ${error.message}`);
    return;
  }

  console.error(`[openclaw-cdp-proxy] ${message}`, error);
}

class UpstreamUnavailableError extends Error {}
