// Creates the Storage buckets Shelf expects (apps/docs/supabase-setup.md) and fixes their visibility.
// Talks to Storage directly on the internal network with the service-role key. Idempotent.
// No storage policies are added: with RLS on and no policy, only the service role (Shelf's server)
// can read or write, which is what Shelf's "(bucket_id = ...) AND (false)" policies achieve.
const base = (process.env.STORAGE_INTERNAL_URL || "http://storage:5000").replace(/\/+$/, "");
const key = process.env.SUPABASE_SERVICE_ROLE;
if (!key) {
  console.error("[shelf] FATAL: SUPABASE_SERVICE_ROLE is empty (see README: empty Supabase keys)");
  process.exit(1);
}

const headers = { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" };
const buckets = [
  { id: "profile-pictures", public: true },
  { id: "files", public: true },
  { id: "assets", public: false },
  { id: "kits", public: false },
];
const log = (m) => console.log(`[shelf] ${m}`);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

for (let i = 0; ; i++) {
  try { if ((await fetch(`${base}/status`)).ok) break; } catch {}
  if (i >= 90) { console.error("[shelf] FATAL: Storage did not become ready"); process.exit(1); }
  await sleep(2000);
}

for (const b of buckets) {
  const res = await fetch(`${base}/bucket/${b.id}`, { headers });
  if (res.status === 401 || res.status === 403) {
    console.error("[shelf] FATAL: Storage rejected the service key (see README: empty Supabase keys)");
    process.exit(1);
  }
  if (res.ok) {
    const cur = await res.json();
    if (cur.public !== b.public) {
      const u = await fetch(`${base}/bucket/${b.id}`, { method: "PUT", headers, body: JSON.stringify({ public: b.public }) });
      if (!u.ok) throw new Error(`update ${b.id}: ${u.status} ${await u.text()}`);
      log(`bucket ${b.id}: visibility corrected`);
    }
    continue;
  }
  const c = await fetch(`${base}/bucket`, { method: "POST", headers, body: JSON.stringify({ id: b.id, name: b.id, public: b.public }) });
  if (!c.ok) {
    const t = await c.text();
    if (/already exists/i.test(t)) continue;
    throw new Error(`create ${b.id}: ${c.status} ${t}`);
  }
  log(`bucket ${b.id}: created (${b.public ? "public" : "private"})`);
}
log("storage buckets ready");
