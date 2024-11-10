import { type IncomingMessage, type ServerResponse, createServer } from 'node:http';
import { performance } from 'node:perf_hooks';
import { URL } from 'node:url';

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

  response.once('finish', () => {
    const duration = durationToHumanReadable(performance.now() - start);
    const time = new Date().toISOString();
    const method = request.method;
    const path = url.pathname;
    const status = response.statusCode;

    // biome-ignore lint/suspicious/noConsoleLog: Allow console.log for request duration
    console.log(`[${time}] ${method} ${path} ${status} ${duration}`);
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

function durationToHumanReadable(duration: number): string {
  if (duration < 1000) {
    const milliseconds = Math.floor(duration);
    return `${milliseconds}ms`;
  }

  const seconds = Math.floor(duration / 1000);

  return `${seconds}s`;
}
