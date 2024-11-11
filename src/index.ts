import { type IncomingMessage, type ServerResponse, createServer } from 'node:http';
import { performance } from 'node:perf_hooks';
import { URL } from 'node:url';
import { requestStore } from './store.js';

const server = createServer(handleRequest);

server.listen(3000, () => {
  // biome-ignore lint/suspicious/noConsoleLog: Allow console.log for server URL
  console.log('Server is running on http://localhost:3000');
});

function handleRequest(request: IncomingMessage, response: ServerResponse) {
  const start = performance.now();

  const url = new URL(request.url || '/', `http://${request.headers.host}`);

  if (url.pathname === '/healthz') {
    healthcheck(response);
  }

  if (url.pathname === '/') {
    helloWorld(response);
  }

  if (url.pathname === '/requests') {
    getAllRequests(response);
  }

  response.once('finish', async () => {
    const duration = performance.now() - start;
    const readableDuration = durationToHumanReadable(duration);
    const time = new Date().toISOString();
    const method = request.method?.toUpperCase() ?? 'GET';
    const path = url.pathname;
    const status = response.statusCode;

    // biome-ignore lint/suspicious/noConsoleLog: Allow console.log for request duration
    console.log(`[${time}] ${method} ${path} ${status} ${readableDuration}`);

    if (path === '/healthz' || path === '/requests') {
      return;
    }

    try {
      await requestStore.saveOne({
        path,
        method,
        duration,
      });
    } catch (err) {
      // biome-ignore lint/suspicious/noConsoleLog: Allow console.log for error handling
      console.log('Failed to save request', err);
    }
  });
}

function healthcheck(response: ServerResponse<IncomingMessage>): void {
  response.setHeader('Content-Type', 'application/json');
  response.writeHead(200);

  response.write(JSON.stringify({ ok: true }));
  response.end();
}

function helloWorld(response: ServerResponse<IncomingMessage>): void {
  response.setHeader('Content-Type', 'application/json');
  response.writeHead(200);

  response.write(JSON.stringify({ message: 'Hello, World!' }));
  response.end();
}

async function getAllRequests(response: ServerResponse<IncomingMessage>): Promise<void> {
  const requests = await requestStore.findAll().catch(err => ({
    error: err.message,
    stack: err.stack,
  }));

  response.setHeader('Content-Type', 'application/json');
  response.writeHead(200);

  response.write(JSON.stringify(requests));
  response.end();
}

function durationToHumanReadable(duration: number): string {
  if (duration < 1000) {
    const milliseconds = Math.floor(duration);
    return `${milliseconds}ms`;
  }

  const seconds = Math.floor(duration / 1000);

  return `${seconds}s`;
}
