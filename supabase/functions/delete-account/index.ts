import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, string>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function hasRecentAuthentication(token: string): boolean {
  try {
    const encodedClaims = token.split(".")[1];
    if (!encodedClaims) return false;
    const base64 = encodedClaims.replace(/-/g, "+").replace(/_/g, "/");
    const paddedBase64 = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
    const claims = JSON.parse(atob(paddedBase64)) as { auth_time?: unknown };
    if (typeof claims.auth_time !== "number") return false;
    const ageSeconds = Math.floor(Date.now() / 1000) - claims.auth_time;
    return ageSeconds >= 0 && ageSeconds <= 900;
  } catch {
    return false;
  }
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Authentication required" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    console.error("Account deletion function is missing required secrets.");
    return jsonResponse({ error: "Account deletion is not configured" }, 500);
  }

  const callerClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: { user }, error: authError } = await callerClient.auth.getUser();
  if (authError || !user) {
    return jsonResponse({ error: "Authentication required" }, 401);
  }
  const accessToken = authorization.substring("Bearer ".length);
  if (!hasRecentAuthentication(accessToken)) {
    return jsonResponse(
      { error: "Please reauthenticate before deleting your account" },
      403,
    );
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { error: deleteUserError } = await adminClient.auth.admin.deleteUser(
    user.id,
  );
  if (deleteUserError) {
    console.error("Unable to atomically delete the authenticated account.");
    return jsonResponse({ error: "Unable to delete account" }, 500);
  }

  return jsonResponse({ message: "Account deleted" }, 200);
});
