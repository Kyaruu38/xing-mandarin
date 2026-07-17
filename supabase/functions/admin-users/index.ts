import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL      = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

// DEBT, not a free choice -- DECISIONS_NEEDED #34. Tried the new-format secret key
// (SUPABASE_SECRET_KEYS['default']) first, in 2 rounds: plain createClient(), then with
// { auth: { persistSession:false, autoRefreshToken:false } } to rule out the Authorization-
// header-fallback theory. Both rounds gave the IDENTICAL failure: auth.admin.* (GoTrue) works
// fine with the new key (listEmails succeeded live), but from('profiles').update() (PostgREST)
// fails with "permission denied for table profiles" -- a GRANT-level error, meaning the request
// reaches PostgREST with no recognized role/grant at all, not even an RLS-policy rejection.
// Same bug class as supabase-js #1568, manifesting on the PostgREST side instead of GoTrue.
// Falling back to the legacy JWT service_role key, which both endpoints accept without issue.
// MUST be revisited before the legacy key's end-of-2026 deprecation target -- if Supabase fixes
// secret-key-to-PostgREST conversion before then, swap back (one line, keep this comment as the
// pointer). If not fixed by then, this is a real blocker, not a nice-to-have.
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Mirrors profiles' own column defaults (handle_new_user() / DB DEFAULT) -- not invented here.
const DEFAULT_PACKAGE = "hsk_1_4";
const DEFAULT_STATUS  = "active";
const DEFAULT_ROLE    = "user";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const json = (obj: unknown, status = 200) =>
    new Response(JSON.stringify(obj), { status, headers: { ...cors, "content-type": "application/json" } });

  // ---------- GERBANG WAJIB (DECISIONS_NEEDED #32) ----------
  // Verify the CALLER is an admin using their own forwarded JWT + anon key -- RLS's "user reads
  // own profile" policy scopes this query to exactly their own row, so this can't be used to
  // probe other users' roles. This MUST happen before the secret/service_role client is ever
  // constructed -- without it, anyone who knows this function's URL could create arbitrary
  // accounts or read every user's email.
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

  const callerClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user: caller }, error: callerErr } = await callerClient.auth.getUser();
  if (callerErr || !caller) return json({ error: "Invalid session" }, 401);

  const { data: callerProfile, error: profileErr } = await callerClient
    .from("profiles").select("role").eq("id", caller.id).single();
  if (profileErr || !callerProfile || callerProfile.role !== "admin") {
    return json({ error: "Admin access required" }, 403);
  }

  // ---------- Only past the gate does the privileged client get created ----------
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON body" }, 400); }
  const action = body.action;

  if (action === "createUser") {
    const email = String(body.email || "").trim();
    const password = String(body.password || "");
    const display_name = body.display_name ? String(body.display_name).trim() : null;
    if (!email || !email.includes("@")) return json({ error: "Email tidak valid" }, 400);
    if (!password) return json({ error: "Password wajib diisi" }, 400);

    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email, password, email_confirm: true,
      user_metadata: display_name ? { display_name } : {},
    });
    if (createErr || !created?.user) {
      return json({ error: "Gagal membuat user: " + (createErr?.message || "unknown error") }, 400);
    }

    const newUserId = created.user.id;
    const profilePayload: Record<string, unknown> = {
      package: body.package || DEFAULT_PACKAGE,
      target_level: body.target_level ? Number(body.target_level) : null,
      status: body.status || DEFAULT_STATUS,
      subscription_end: body.subscription_end || null,
      role: body.role || DEFAULT_ROLE,
    };

    // handle_new_user() already inserted (id, display_name) synchronously as part of the
    // createUser() call above -- this UPDATE fills in the rest of the form's fields.
    const { error: updateErr } = await admin.from("profiles").update(profilePayload).eq("id", newUserId);

    if (updateErr) {
      // DECISIONS_NEEDED #32 -- partial failure is NEVER reported as success. The auth user and
      // profiles row both exist (trigger ran), just left at DB defaults (hsk_1_4/active/user)
      // instead of the form's values -- recoverable via the existing Edit modal, but the admin
      // must be told explicitly, not left believing the form's settings applied. No rollback or
      // delete-on-failure: there's no RLS DELETE policy, and deleting the new auth user would
      // CASCADE through anything already tied to that id -- too dangerous for an automatic path.
      return json({
        status: "partial",
        user: { id: newUserId, email },
        error: "User dibuat, tapi update paket/level/status gagal: " + updateErr.message,
      }, 207);
    }

    return json({ status: "ok", user: { id: newUserId, email } });
  }

  if (action === "listEmails") {
    // Single-page fetch -- fine at current scale. Revisit with real pagination once the user
    // list crosses ~50 (DECISIONS_NEEDED #32), not before.
    const { data, error } = await admin.auth.admin.listUsers({ page: 1, perPage: 200 });
    if (error) return json({ error: "Gagal ambil daftar email: " + error.message }, 500);
    const emails: Record<string, string> = {};
    for (const u of data.users) emails[u.id] = u.email ?? "";
    return json({ emails });
  }

  return json({ error: "Unknown action" }, 400);
});
