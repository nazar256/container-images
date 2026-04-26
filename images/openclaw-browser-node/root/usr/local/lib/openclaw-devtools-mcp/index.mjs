import express from 'express';
import { randomUUID, timingSafeEqual } from 'node:crypto';
import process from 'node:process';

import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { isInitializeRequest } from '@modelcontextprotocol/sdk/types.js';

const browserUrl = process.env.OPENCLAW_BROWSER_CDP_URL ?? `http://127.0.0.1:${process.env.CDP_PORT ?? '9222'}`;
const listenHost = process.env.OPENCLAW_DEVTOOLS_MCP_HOST ?? '0.0.0.0';
const listenPort = Number.parseInt(process.env.OPENCLAW_DEVTOOLS_MCP_PORT ?? '9223', 10);
const endpointPath = normalizePath(process.env.OPENCLAW_DEVTOOLS_MCP_PATH ?? '/mcp');
const bearerToken = process.env.OPENCLAW_DEVTOOLS_MCP_AUTH_BEARER_TOKEN ?? '';
const disablePerformanceCrux = isTrue(process.env.OPENCLAW_DEVTOOLS_MCP_DISABLE_PERFORMANCE_CRUX ?? 'true');
const maxSessions = parseIntegerEnv('OPENCLAW_DEVTOOLS_MCP_MAX_SESSIONS', 16, { min: 1 });
const sessionTimeoutMs = parseIntegerEnv('OPENCLAW_DEVTOOLS_MCP_SESSION_TIMEOUT_MS', 300000, { min: 0 });
const sessionTimeoutEnabled = sessionTimeoutMs > 0;

if (!Number.isInteger(listenPort) || listenPort < 1 || listenPort > 65535) {
  throw new Error(`OPENCLAW_DEVTOOLS_MCP_PORT must be a valid TCP port, got: ${process.env.OPENCLAW_DEVTOOLS_MCP_PORT ?? ''}`);
}

const app = express();
const sessions = new Map();
let reservedSessionSlots = 0;

app.disable('x-powered-by');
app.use(express.json({ limit: '10mb' }));
app.use((req, res, next) => {
  if (!bearerToken) {
    return next();
  }

  const authorization = req.header('authorization') ?? '';
  if (safeEquals(authorization, `Bearer ${bearerToken}`)) {
    return next();
  }

  res.status(401).json({
    jsonrpc: '2.0',
    error: {
      code: -32001,
      message: 'Unauthorized',
    },
    id: null,
  });
});

app.post(endpointPath, async (req, res) => {
  try {
    const requestedSessionId = getSessionId(req);
    let session = requestedSessionId ? sessions.get(requestedSessionId) : undefined;

    if (!session) {
      if (requestedSessionId || !isInitializeRequest(req.body)) {
        return jsonRpcError(res, 400, -32000, 'Bad Request: missing or invalid MCP session');
      }

      try {
        session = await createSession();
      } catch (error) {
        if (error instanceof Error && error.message.startsWith('session limit reached')) {
          return jsonRpcError(res, 429, -32002, error.message);
        }

        throw error;
      }
    }

    touchSession(session);
    return await session.httpTransport.handleRequest(req, res, req.body);
  } catch (error) {
    console.error('[openclaw-devtools-mcp] failed handling POST request', error);
    return jsonRpcError(res, 500, -32603, 'Internal server error');
  }
});

app.get(endpointPath, async (req, res) => {
  try {
    const session = requireSession(req, res);
    if (!session) {
      return;
    }

    return await session.httpTransport.handleRequest(req, res);
  } catch (error) {
    console.error('[openclaw-devtools-mcp] failed handling GET request', error);
    return jsonRpcError(res, 500, -32603, 'Internal server error');
  }
});

app.delete(endpointPath, async (req, res) => {
  try {
    const session = requireSession(req, res);
    if (!session) {
      return;
    }

    return await session.httpTransport.handleRequest(req, res);
  } catch (error) {
    console.error('[openclaw-devtools-mcp] failed handling DELETE request', error);
    return jsonRpcError(res, 500, -32603, 'Internal server error');
  }
});

app.listen(listenPort, listenHost, () => {
  log(`listening on http://${listenHost}:${listenPort}${endpointPath}`);
  log(`proxying Chrome DevTools MCP to ${browserUrl}`);
  log(`max sessions: ${maxSessions}`);
  log(`session timeout: ${sessionTimeoutMs === 0 ? 'disabled' : `${sessionTimeoutMs}ms`}`);
});

function bindSessionResponseLifecycle(session) {
  session.httpTransport.onerror = (error) => {
    console.error('[openclaw-devtools-mcp] transport error', error);
  };

  session.httpTransport.onclose = () => {
    void cleanupSession(session, 'http transport closed');
  };

  session.stdioTransport.onerror = (error) => {
    console.error('[openclaw-devtools-mcp] chrome-devtools-mcp stdio error', error);
  };

  session.stdioTransport.onclose = () => {
    void cleanupSession(session, 'chrome-devtools-mcp exited');
  };

  session.stdioTransport.stderr?.on('data', (chunk) => {
    process.stderr.write(`[chrome-devtools-mcp] ${chunk.toString('utf8')}`);
  });

  session.stdioTransport.onmessage = (message) => {
    touchSession(session);
    void session.httpTransport.send(message).catch((error) => {
      console.error('[openclaw-devtools-mcp] failed sending MCP response', error);
    });
  };

  session.httpTransport.onmessage = (message) => {
    touchSession(session);
    void session.stdioTransport.send(message).catch((error) => {
      console.error('[openclaw-devtools-mcp] failed forwarding MCP request', error);
    });
  };
}

async function createSession() {
  reserveSessionSlot();
  let slotReserved = true;
  let stdioTransport = null;

  try {
    stdioTransport = new StdioClientTransport({
      command: 'chrome-devtools-mcp',
      args: buildChromeDevToolsArgs(),
      env: process.env,
      stderr: 'pipe',
    });

    await stdioTransport.start();

    const session = {
      cleanedUp: false,
      httpTransport: null,
      inactivityTimer: null,
      lastActivityAt: Date.now(),
      sessionId: null,
      slotReserved: true,
      stdioTransport,
    };

    const httpTransport = new StreamableHTTPServerTransport({
      sessionIdGenerator: () => randomUUID(),
      onsessioninitialized: (sessionId) => {
        session.sessionId = sessionId;
        sessions.set(sessionId, session);
        log(`created session ${sessionId}`);
      },
    });

    session.httpTransport = httpTransport;
    bindSessionResponseLifecycle(session);
    touchSession(session);
    return session;
  } catch (error) {
    if (slotReserved) {
      reservedSessionSlots -= 1;
      slotReserved = false;
    }

    await stdioTransport?.close().catch(() => {});
    throw error;
  }
}

async function cleanupSession(session, reason) {
  const sessionId = session.sessionId;
  if (session.cleanedUp) {
    return;
  }

  session.cleanedUp = true;
  if (session.slotReserved) {
    session.slotReserved = false;
    reservedSessionSlots -= 1;
  }

  if (session.inactivityTimer) {
    clearTimeout(session.inactivityTimer);
    session.inactivityTimer = null;
  }

  if (sessionId) {
    sessions.delete(sessionId);
    log(`cleaning up session ${sessionId}: ${reason}`);
  } else {
    log(`cleaning up uninitialized session: ${reason}`);
  }

  await Promise.allSettled([
    session.httpTransport?.close(),
    session.stdioTransport?.close(),
  ]);
}

function requireSession(req, res) {
  const sessionId = getSessionId(req);
  const session = sessionId ? sessions.get(sessionId) : undefined;

  if (session) {
    touchSession(session);
    return session;
  }

  jsonRpcError(res, 400, -32000, 'Bad Request: missing or invalid MCP session');
  return null;
}

function touchSession(session) {
  if (session.cleanedUp || !sessionTimeoutEnabled) {
    return;
  }

  session.lastActivityAt = Date.now();
  const inactivityStartTime = session.lastActivityAt;

  if (session.inactivityTimer) {
    clearTimeout(session.inactivityTimer);
  }

  session.inactivityTimer = setTimeout(() => {
    if (session.cleanedUp) {
      return;
    }

    void cleanupSession(
      session,
      `inactive for ${sessionTimeoutMs}ms since ${new Date(inactivityStartTime).toISOString()}`,
    );
  }, sessionTimeoutMs);

  // Do not keep the Node process alive solely because an inactivity timer is pending.
  session.inactivityTimer.unref();
}

function getSessionId(req) {
  const header = req.header('mcp-session-id');
  return header?.trim() || '';
}

function buildChromeDevToolsArgs() {
  const args = [`--browserUrl=${browserUrl}`];

  if (isTrue(process.env.OPENCLAW_DEVTOOLS_MCP_DISABLE_USAGE_STATISTICS ?? 'true')) {
    args.push('--no-usage-statistics');
  }

  if (disablePerformanceCrux) {
    args.push('--no-performance-crux');
  }

  return args;
}

function isTrue(value) {
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
}

function normalizePath(value) {
  return value.startsWith('/') ? value : `/${value}`;
}

function safeEquals(left, right) {
  const leftBuffer = Buffer.from(left, 'utf8');
  const rightBuffer = Buffer.from(right, 'utf8');

  if (leftBuffer.length !== rightBuffer.length) {
    return false;
  }

  return timingSafeEqual(leftBuffer, rightBuffer);
}

function reserveSessionSlot() {
  if (reservedSessionSlots >= maxSessions) {
    throw new Error(`session limit reached (${maxSessions})`);
  }

  reservedSessionSlots += 1;
}

function parseIntegerEnv(name, fallback, { min }) {
  const rawValue = process.env[name];
  const usingFallback = rawValue === undefined || rawValue === '';
  const parsed = usingFallback ? fallback : Number.parseInt(rawValue, 10);

  if (!Number.isInteger(parsed) || parsed < min) {
    const sourceValue = usingFallback
      ? `default fallback value ${fallback}`
      : `environment value ${rawValue}`;
    throw new Error(`${name} must be an integer >= ${min}, got ${sourceValue}`);
  }

  return parsed;
}

function jsonRpcError(res, status, code, message, id = null) {
  return res.status(status).json({
    jsonrpc: '2.0',
    error: {
      code,
      message,
    },
    id,
  });
}

function log(message) {
  console.error(`[openclaw-devtools-mcp] ${message}`);
}
