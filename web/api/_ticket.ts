/*
 A ticket proves a page came out of a finished Slack install. It carries an expiry time,
 a random ID and an HMAC of both. The signature needs no storage to check. The ID is what
 api/email-link.ts claims in Redis, so each ticket sends email once. The underscore keeps
 Vercel from serving this file as a function of its own
 */
export const lifetimeSeconds = 60 * 60;
const purpose = "email-link";

export type Ticket = { id: string; expires: number };

export async function issueTicket(now = Date.now()): Promise<string> {
  const expires = Math.floor(now / 1000) + lifetimeSeconds;
  const id = Buffer.from(crypto.getRandomValues(new Uint8Array(16))).toString("base64url");
  return `${expires}.${id}.${await sign(`${purpose}.${expires}.${id}`)}`;
}

export async function verifyTicket(ticket: string, now = Date.now()): Promise<Ticket | null> {
  const match = /^(\d{10})\.([A-Za-z0-9_-]{22})\.([A-Za-z0-9_-]{43})$/.exec(ticket);
  if (!match) return null;

  const expires = Number(match[1]);
  const id = match[2];
  const seconds = Math.floor(now / 1000);
  if (expires < seconds || expires > seconds + lifetimeSeconds) return null;

  const valid = timingSafeEqual(match[3], await sign(`${purpose}.${expires}.${id}`));
  return valid ? { id, expires } : null;
}

/*
 Keyed hashes for what api/email-link.ts keeps in Redis, so an email address or IP
 address never appears there in a form anyone can read back
 */
export function digest(label: string, value: string): Promise<string> {
  return sign(`${purpose}.${label}.${value}`);
}

async function sign(message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret()),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Buffer.from(mac).toString("base64url");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let i = 0; i < a.length; i++) difference |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return difference === 0;
}

/*
 The Slack client secret already lives only on the server, so it doubles as the key.
 The purpose prefix keeps these signatures from meaning anything anywhere else
 */
function secret(): string {
  const value = process.env.SLACK_CLIENT_SECRET;
  if (!value) throw new Error("SLACK_CLIENT_SECRET is not set");
  return value;
}
