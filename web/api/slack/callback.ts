const appScheme = "statusforslack";

export async function GET(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const code = url.searchParams.get("code");
  const state = url.searchParams.get("state") ?? "";
  const denied = url.searchParams.get("error");

  if (denied || !code) {
    return bounce({ error: denied ?? "missing_code", state });
  }

  const form = new URLSearchParams({
    client_id: required("SLACK_CLIENT_ID"),
    client_secret: required("SLACK_CLIENT_SECRET"),
    code,
    redirect_uri: `${url.origin}${url.pathname}`,
  });
  const response = await fetch("https://slack.com/api/oauth.v2.access", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: form,
  });
  const result = (await response.json()) as {
    ok: boolean;
    error?: string;
    authed_user?: { access_token?: string };
  };

  const token = result.authed_user?.access_token;
  if (!result.ok || !token) {
    return bounce({ error: result.error ?? "no_user_token", state });
  }
  return bounce({ token, state });
}

function bounce(fragment: Record<string, string>): Response {
  const params = new URLSearchParams(fragment).toString();
  return Response.redirect(`${appScheme}://connected#${params}`, 302);
}

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set`);
  return value;
}
