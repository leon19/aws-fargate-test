import process from 'node:process';
import { GlideClient } from '@valkey/valkey-glide';

const valkeyURI = process.env.VALKEY_URI ? new URL(process.env.VALKEY_URI) : new URL('valkey://localhost:6379');

// Check `GlideClientConfiguration/GlideClusterClientConfiguration` for additional options.
const client = await GlideClient.createClient({
  addresses: [
    {
      host: valkeyURI.hostname,
      port: valkeyURI.port ? Number(valkeyURI.port) : 6379,
    },
  ],
  // if the server uses TLS, you'll need to enable it. Otherwise, the connection attempt will time out silently.
  useTLS: true,
  clientName: 'test_standalone_client',
});

export interface RequestInformation {
  method: string;
  path: string;
  duration: number;
}

export class RequestStore {
  constructor(private readonly client: GlideClient) {}

  async saveOne(request: RequestInformation): Promise<void> {
    await this.client.lpush('request', [JSON.stringify(request)]);
  }

  async findAll(): Promise<RequestInformation[]> {
    const response = await this.client.lrange('request', 0, -1);

    if (!response) {
      return [];
    }

    return Object.values(response).map((value: any) => JSON.parse(value));
  }
}

export const requestStore = new RequestStore(client);
