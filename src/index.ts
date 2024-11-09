import { type IncomingMessage, type ServerResponse, createServer } from 'node:http';
import { URL } from 'node:url';

const server = createServer(handleRequest);

server.listen(3000, () => {
  // biome-ignore lint/suspicious/noConsoleLog: Allow console.log for server URL
  console.log('Server is running on http://localhost:3000');
});

function handleRequest(request: IncomingMessage, response: ServerResponse) {
  const url = new URL(request.url || '/', `http://${request.headers.host}`);
  if (url.pathname === '/healthz') {
    healthcheck(response);
  }
  if (url.pathname === '/') {
    helloWorld(response);
  }
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
