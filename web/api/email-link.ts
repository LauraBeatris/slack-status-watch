import { verifyTicket } from "./_ticket.js";

/*
 The install confirmation page's "Email me the link" form. Someone who added the app
 from a computer still has to finish on their iPhone, so they can send themselves the
 App Store link. The address goes to Resend as an event, and an automation there sends
 the link now and one reminder a day later. Nothing is stored here.

 Only a page that came out of a finished Slack install can ask, because the callback
 hands it a short-lived signed ticket. Without one the form would send mail to anyone
 */
const eventName = "install.link_requested";
const emailShape = /^[^\s@]+@[^\s@.]+(\.[^\s@.]+)+$/;
const maxEmailLength = 320;
const resendTimeout = 8000;

type Body = { email?: unknown; ticket?: unknown };

export async function POST(request: Request): Promise<Response> {
  let body: Body;
  try {
    body = (await request.json()) as Body;
  } catch {
    return reply(400, "invalid_request");
  }

  const email = typeof body.email === "string" ? body.email.trim() : "";
  const ticket = typeof body.ticket === "string" ? body.ticket : "";

  if (!email || email.length > maxEmailLength || !emailShape.test(email)) {
    return reply(400, "invalid_email");
  }
  if (!(await verifyTicket(ticket))) {
    return reply(403, "expired_ticket");
  }

  try {
    const response = await fetch("https://api.resend.com/events/send", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${required("RESEND_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ event: eventName, email }),
      signal: AbortSignal.timeout(resendTimeout),
    });
    if (!response.ok) {
      return reply(502, "send_failed");
    }
  } catch {
    return reply(502, "send_failed");
  }
  return reply(202);
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
