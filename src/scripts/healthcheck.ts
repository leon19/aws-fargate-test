import process from 'node:process';

const response = await fetch('http://localhost:3000/healthz');

if (response.ok) {
  process.stdout.write('Healthcheck passed\n');
  process.exit(0);
} else {
  process.stdout.write('Healthcheck failed\n');
  process.exit(1);
}
