/*
 The few Redis commands api/email-link.ts needs, over Upstash's REST API. The Upstash
 integration on Vercel sets KV_REST_API_URL and KV_REST_API_TOKEN
 */
const redisTimeout = 4000;

type Command = (string | number)[];

export async function redis(commands: Command[]): Promise<unknown[]> {
  const response = await fetch(`${required("KV_REST_API_URL")}/pipeline`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${required("KV_REST_API_TOKEN")}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(commands),
    signal: AbortSignal.timeout(redisTimeout),
  });
  if (!response.ok) throw new Error(`Redis answered ${response.status}`);

  const replies = (await response.json()) as { result?: unknown; error?: string }[];
  return replies.map((reply) => {
    if (reply.error) throw new Error(`Redis error: ${reply.error}`);
    return reply.result;
  });
}

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
}
