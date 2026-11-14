/*
 The website's "Add to Slack" button. It starts the same OAuth flow as the iPhone app,
 with a state that starts with "web-" and a cookie to check it against on the way back,
 then hands off to Slack's consent screen
 */
const installCookie = "__Host-slack_install";
const scopes = ["users.profile:read", "users.profile:write"];

export function GET(request: Request): Response {
  const url = new URL(request.url);
  const state = `web-${crypto.randomUUID()}`;

  const authorize = new URL("https://slack.com/oauth/v2/authorize");
  authorize.searchParams.set("client_id", required("SLACK_CLIENT_ID"));
  authorize.searchParams.set("user_scope", scopes.join(","));
  authorize.searchParams.set("redirect_uri", `${url.origin}/api/slack/callback`);
  authorize.searchParams.set("state", state);

  return new Response(null, {
    status: 302,
    headers: {
      Location: authorize.toString(),
      "Set-Cookie": `${installCookie}=${state}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=600`,
      "Cache-Control": "no-store",
    },
  });
}

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
}
