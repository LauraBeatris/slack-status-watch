import { Resend } from "resend";

import { redis } from "./_redis.js";
import { digest, verifyTicket } from "./_ticket.js";

/*
 The install confirmation page's "Email me the link" form. Someone who added the app
 from a computer still has to finish on their iPhone, so they can send themselves the
 App Store link. The address goes to Resend as an event, and an automation there sends
 the link now and one reminder a day later.

 Only a page that came out of a finished Slack install can ask, because the callback
 hands it a signed ticket, and each ticket sends to one address once. Redis remembers
 which tickets were used and how often each IP asked, under keyed hashes and only for
 an hour. It never holds an email address
 */
const eventName = "install.link_requested";
const emailShape = /^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$/;
const maxEmailLength = 320;
const resendTimeout = 8000;

// A person fixing a typo asks a few times. Anything past this is a script
const requestsPerIpPerHour = 10;

type Body = { email?: unknown; ticket?: unknown };

export async function POST(request: Request): Promise<Response> {
  let body: Body;
  try {
    body = (await request.json()) as Body;
  } catch {
    return reply(400, "invalid_request");
  }

  const email = typeof body.email === "string" ? body.email.trim() : "";
  const rawTicket = typeof body.ticket === "string" ? body.ticket : "";

  try {
    if (await overLimit(clientIp(request))) {
      return reply(429, "too_many_requests");
    }
  } catch {
    return reply(503, "unavailable");
  }

  if (!email || email.length > maxEmailLength || !emailShape.test(email)) {
    return reply(400, "invalid_email");
  }
  const ticket = await verifyTicket(rawTicket);
  if (!ticket) {
    return reply(403, "expired_ticket");
  }

  /*
   Claiming the ticket is one atomic SET NX, so two requests racing with the same ticket
   can't both send. The value says who it was used for: the same address again is a
   retry and gets the same answer without a second email, any other address is refused
   */
  const key = `email-link:ticket:${ticket.id}`;
  const recipient = await digest("recipient", email.toLowerCase());
  const secondsLeft = Math.max(ticket.expires - Math.floor(Date.now() / 1000), 1);
  try {
    const [claimed] = await redis([["SET", key, recipient, "NX", "EX", secondsLeft]]);
    if (claimed !== "OK") {
      const [usedFor] = await redis([["GET", key]]);
      return usedFor === recipient ? reply(202) : reply(409, "ticket_used");
    }
  } catch {
    return reply(503, "unavailable");
  }

  if (!(await sendEvent(email))) {
    // Nothing went out, so the ticket is released for another try
    await redis([["DEL", key]]).catch(() => {});
    return reply(502, "send_failed");
  }
  return reply(202);
}

async function sendEvent(email: string): Promise<boolean> {
  try {
    const resend = new Resend(required("RESEND_API_KEY"));
    const { error } = await resend.events.send(
      { event: eventName, email },
      { signal: AbortSignal.timeout(resendTimeout) },
    );
    return !error;
  } catch {
    return false;
  }
}

async function overLimit(ip: string): Promise<boolean> {
  const key = `email-link:ip:${await digest("ip", ip)}`;
  const [count] = await redis([
    ["INCR", key],
    ["EXPIRE", key, 60 * 60, "NX"],
  ]);
  return Number(count) > requestsPerIpPerHour;
}

// Vercel sets x-real-ip to the address that reached its edge
function clientIp(request: Request): string {
  return (
    request.headers.get("x-real-ip") ??
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    "unknown"
  );
}

function reply(status: number, error?: string): Response {
  return Response.json(error ? { error } : { ok: true }, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
}
