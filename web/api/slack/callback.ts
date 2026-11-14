const appScheme = "statusforslack";

/*
 Slack's codes are digits and hex joined by dots, and the app's state is a UUID.
 Anything else is noise, so it is turned away before the client secret is used
 */
const codeShape = /^[A-Za-z0-9._-]{16,512}$/;
const stateShape = /^[A-Za-z0-9-]{8,128}$/;
const slackTimeout = 8000;

/*
 Installs from the website's "Add to Slack" button carry a "web-" state and a matching
 cookie set by install.ts. They end on the site's confirmation page, not in the app
 */
const webStatePrefix = "web-";
const installCookie = "__Host-slack_install";
const installedPage = "https://www.wriststatus.com/installed";

type OAuthAccess = {
  ok: boolean;
  error?: string;
  authed_user?: { access_token?: string };
  team?: { name?: string };
};

export async function GET(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const rawState = url.searchParams.get("state") ?? "";
  const state = stateShape.test(rawState) ? rawState : "";
  const denied = url.searchParams.get("error");

  if (state.startsWith(webStatePrefix)) {
    return completeWebInstall(request, url, state, code, denied);
  }

  if (denied) {
    return bounce({ error: denied.slice(0, 64), state });
  }
  if (!code) {
    return bounce({ error: "missing_code", state });
  }
  if (!state || !codeShape.test(code)) {
    return bounce({ error: "invalid_request", state });
  }

  const result = await exchange(url, code);
  if (!result) {
    return bounce({ error: "slack_unreachable", state });
  }

  const token = result.authed_user?.access_token;
  if (!result.ok || !token) {
    return bounce({ error: result.error ?? "no_user_token", state });
  }
  return bounce({ token, state });
}

/*
 Finishing the exchange is what installs the app in the workspace. The token Slack
 returns is never read, stored or sent anywhere. The person signs in again in the app
 */
async function completeWebInstall(
  request: Request,
  url: URL,
  state: string,
  code: string | null,
  denied: string | null,
): Promise<Response> {
  if (denied) {
    return installed({ error: denied.slice(0, 64) });
  }
  if (readCookie(request, installCookie) !== state) {
    return installed({ error: "expired_install" });
  }
  if (!code || !codeShape.test(code)) {
    return installed({ error: "invalid_request" });
  }

  const result = await exchange(url, code);
  if (!result) {
    return installed({ error: "slack_unreachable" });
  }
  if (!result.ok) {
    return installed({ error: result.error ?? "install_failed" });
  }
  return installed({ workspace: (result.team?.name ?? "").slice(0, 80) });
}

async function exchange(url: URL, code: string): Promise<OAuthAccess | null> {
  const form = new URLSearchParams({
    client_id: required("SLACK_CLIENT_ID"),
    client_secret: required("SLACK_CLIENT_SECRET"),
    code,
    redirect_uri: `${url.origin}${url.pathname}`,
  });
  try {
    const response = await fetch("https://slack.com/api/oauth.v2.access", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
      signal: AbortSignal.timeout(slackTimeout),
    });
    return (await response.json()) as OAuthAccess;
  } catch {
    return null;
  }
}

function installed(query: Record<string, string>): Response {
  const params = new URLSearchParams(query).toString();
  return new Response(null, {
    status: 302,
    headers: {
      Location: `${installedPage}?${params}`,
      "Set-Cookie": `${installCookie}=; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=0`,
      "Cache-Control": "no-store",
      "Referrer-Policy": "no-referrer",
    },
  });
}

function readCookie(request: Request, name: string): string | undefined {
  const header = request.headers.get("cookie") ?? "";
  for (const part of header.split(";")) {
    const [key, ...rest] = part.trim().split("=");
    if (key === name) return rest.join("=");
  }
  return undefined;
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
