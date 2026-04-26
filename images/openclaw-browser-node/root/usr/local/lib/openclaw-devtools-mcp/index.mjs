import express from 'express';
import { randomUUID } from 'node:crypto';
import process from 'node:process';

import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StreamableHTTPServerTransport } from '@modelcontextprotocol/sdk/server/streamableHttp.js';
import { isInitializeRequest } from '@modelcontextprotocol/sdk/types.js';

const bridgeVersion = '1.0.0';
const browserUrl = process.env.OPENCLAW_BROWSER_CDP_URL ?? `http://127.0.0.1:${process.env.CDP_PORT ?? '9222'}`;
const listenHost = process.env.OPENCLAW_DEVTOOLS_MCP_HOST ?? '0.0.0.0';
const listenPort = Number.parseInt(process.env.OPENCLAW_DEVTOOLS_MCP_PORT ?? '9223', 10);
const endpointPath = normalizePath(process.env.OPENCLAW_DEVTOOLS_MCP_PATH ?? '/mcp');
const bearerToken = process.env.OPENCLAW_DEVTOOLS_MCP_AUTH_BEARER_TOKEN ?? '';
const disablePerformanceCrux = isTrue(process.env.OPENCLAW_DEVTOOLS_MCP_DISABLE_PERFORMANCE_CRUX ?? 'true');

if (!Number.isInteger(listenPort) || listenPort < 1 || listenPort > 65535) {
  throw new Error(`OPENCLAW_DEVTOOLS_MCP_PORT must be a valid TCP port, got: ${process.env.OPENCLAW_DEVTOOLS_MCP_PORT ?? ''}`);
}

const app = express();
const sessions = new Map();

app.disable('x-powered-by');
app.use(express.json({ limit: '10mb' }));
app.use((req, res, next) => {
  if (!bearerToken) {
    return next();
  }

  const authorization = req.header('authorization') ?? '';
  if (authorization === `Bearer ${bearerToken}`) {
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
  const requestedSessionId = getSessionId(req);
  let session = requestedSessionId ? sessions.get(requestedSessionId) : undefined;

  if (!session) {
    if (requestedSessionId || !isInitializeRequest(req.body)) {
      return res.status(400).json({
        jsonrpc: '2.0',
        error: {
          code: -32000,
          message: 'Bad Request: missing or invalid MCP session',
        },
        id: null,
      });
    }

    session = await createSession();
  }

  return session.httpTransport.handleRequest(req, res, req.body);
});

app.get(endpointPath, async (req, res) => {
  const session = requireSession(req, res);
  if (!session) {
    return;
  }

  return session.httpTransport.handleRequest(req, res);
});

app.delete(endpointPath, async (req, res) => {
  const session = requireSession(req, res);
  if (!session) {
    return;
  }

  return session.httpTransport.handleRequest(req, res);
});

app.listen(listenPort, listenHost, () => {
  log(`listening on http://${listenHost}:${listenPort}${endpointPath}`);
  log(`proxying Chrome DevTools MCP to ${browserUrl}`);
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
    void session.httpTransport.send(message).catch((error) => {
      console.error('[openclaw-devtools-mcp] failed sending MCP response', error);
    });
  };

  session.httpTransport.onmessage = (message) => {
    void session.stdioTransport.send(message).catch((error) => {
      console.error('[openclaw-devtools-mcp] failed forwarding MCP request', error);
    });
  };
}

async function createSession() {
  const sdkServer = new Server(
    { name: 'openclaw-devtools-mcp', version: bridgeVersion },
    { capabilities: {} },
  );

  const stdioTransport = new StdioClientTransport({
    command: 'chrome-devtools-mcp',
    args: buildChromeDevToolsArgs(),
    env: process.env,
    stderr: 'pipe',
  });

  await stdioTransport.start();

  const session = {
    httpTransport: null,
    sdkServer,
    sessionId: null,
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
  await sdkServer.connect(httpTransport);
  bindSessionResponseLifecycle(session);
  return session;
}

async function cleanupSession(session, reason) {
  const sessionId = session.sessionId;
  if (session.cleanedUp) {
    return;
  }

  session.cleanedUp = true;
  if (sessionId) {
    sessions.delete(sessionId);
    log(`cleaning up session ${sessionId}: ${reason}`);
  } else {
    log(`cleaning up uninitialized session: ${reason}`);
  }

  await Promise.allSettled([
    session.httpTransport?.close(),
    session.stdioTransport?.close(),
    session.sdkServer?.close(),
  ]);
}

function requireSession(req, res) {
  const sessionId = getSessionId(req);
  const session = sessionId ? sessions.get(sessionId) : undefined;

  if (session) {
    return session;
  }

  res.status(400).send('Invalid or missing MCP session');
  return null;
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

function log(message) {
  console.error(`[openclaw-devtools-mcp] ${message}`);
}
