const appScheme = "statusforslack";

/*
 Slack's codes are digits and hex joined by dots, and the app's state is a UUID.
 Anything else is noise, so it is turned away before the client secret is used
 */
const codeShape = /^[A-Za-z0-9._-]{16,512}$/;
const stateShape = /^[A-Za-z0-9-]{8,128}$/;
const slackTimeout = 8000;

type OAuthAccess = {
  ok: boolean;
  error?: string;
  authed_user?: { access_token?: string };
};

export async function GET(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const rawState = url.searchParams.get("state") ?? "";
  const state = stateShape.test(rawState) ? rawState : "";
  const denied = url.searchParams.get("error");

  if (denied) {
    return bounce({ error: denied.slice(0, 64), state });
  }
  if (!code) {
    return bounce({ error: "missing_code", state });
  }
  if (!state || !codeShape.test(code)) {
    return bounce({ error: "invalid_request", state });
  }

  const form = new URLSearchParams({
    client_id: required("SLACK_CLIENT_ID"),
    client_secret: required("SLACK_CLIENT_SECRET"),
    code,
    redirect_uri: `${url.origin}${url.pathname}`,
  });

  let result: OAuthAccess;
  try {
    const response = await fetch("https://slack.com/api/oauth.v2.access", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
      signal: AbortSignal.timeout(slackTimeout),
    });
    result = (await response.json()) as OAuthAccess;
  } catch {
    return bounce({ error: "slack_unreachable", state });
  }

  const token = result.authed_user?.access_token;
  if (!result.ok || !token) {
    return bounce({ error: result.error ?? "no_user_token", state });
  }
  return bounce({ token, state });
}

/*
 The token rides in the fragment of a redirect, so nothing may keep a copy of the response
 */
function bounce(fragment: Record<string, string>): Response {
  const params = new URLSearchParams(fragment).toString();
  return new Response(null, {
    status: 302,
    headers: {
      Location: `${appScheme}://connected#${params}`,
      "Cache-Control": "no-store",
      "Referrer-Policy": "no-referrer",
    },
  });
}

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
}
