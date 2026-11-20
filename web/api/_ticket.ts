/*
 A ticket proves a page came out of a finished Slack install. It is an expiry time and
 an HMAC of it, so checking one needs no storage. The underscore keeps Vercel from
 serving this file as a function of its own
 */
const lifetimeSeconds = 60 * 60;
const purpose = "email-link";

export async function issueTicket(now = Date.now()): Promise<string> {
  const expires = Math.floor(now / 1000) + lifetimeSeconds;
  return `${expires}.${await sign(expires)}`;
}

export async function verifyTicket(ticket: string, now = Date.now()): Promise<boolean> {
  const match = /^(\d{10})\.([A-Za-z0-9_-]{43})$/.exec(ticket);
  if (!match) return false;

  const expires = Number(match[1]);
  const seconds = Math.floor(now / 1000);
  if (expires < seconds || expires > seconds + lifetimeSeconds) return false;

  return timingSafeEqual(match[2], await sign(expires));
}

async function sign(expires: number): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret()),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${purpose}.${expires}`));
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
