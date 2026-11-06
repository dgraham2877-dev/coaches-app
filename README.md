# Coaches App V14 — Android + iPhone team edition

This is a mobile-first PWA. Existing V13 features are preserved. Team Cloud adds optional email sign-in, invite-code team membership, and explicit upload/download of a shared team snapshot using Supabase Auth and row-level security.

## Deploy
1. Create a Supabase project, enable email/password sign-in, and run `supabase_setup.sql` in the SQL editor. Use the **publishable/anon** key, never a secret/service-role key.
2. Host all files in this folder at an HTTPS origin (e.g. GitHub Pages). The GitHub Pages repo can be public; do not commit secrets or private player data.
3. Open Team Cloud in the app and enter Supabase project URL and public key. Each coach creates their own account and signs in.
4. Head coach creates a team and privately shares the invite code. Assistants join the team. Upload/download shared team data manually.
5. Android: Chrome → Install app/Add to Home screen. iPhone: Safari → Share → Add to Home Screen → Open as Web App (if offered).

## Limitations
- Cloud is **not active** until Supabase is configured; it is not a hosted service supplied by this ZIP.
- Manual snapshot sync only; uploads overwrite the team snapshot. No automatic conflict resolution, real-time collaboration, or granular permissions beyond membership. Export JSON backups before downloading.
- Auth session is kept in memory; sign in again after refreshing. No passwords or access tokens are stored persistently.
- Cloud team data is private to signed-in members subject to SQL policies, but anyone holding the invite code can join. Rotate codes/revoke members through an administrator process before sensitive use.
- Club branding stays device-local. Videos are not uploaded; only manual video tags/notes in the state are shared.
- Test on actual Android/iPhone devices before using for club operations.
