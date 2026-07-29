# Meridian — Cloudflare Pages + Supabase (Fixed)

This version fixes the authentication and persistence problems in the previous package.

## What was fixed

- `config.js` is included in the package, so the app no longer crashes when deployed by Cloudflare Pages Direct Upload.
- Supabase client initialization is guarded and gives a useful configuration error instead of silently breaking the login/sign-up buttons.
- Supabase sessions explicitly use persistent browser storage and token refresh.
- Username/password sign-in and sign-up remain the UI flow.
- Account data is loaded again after every successful login/session restore.
- Activities, goals, and calendar events are saved to the signed-in user's rows.
- Normal saves no longer perform a destructive replace-all DELETE operation.
- User-initiated delete actions only delete the specific record the user selected.
- The database SQL has been rewritten to be non-destructive: it contains no `DROP`, `TRUNCATE`, or data `DELETE` statements.
- Existing policies created by the earlier Meridian schema are safely updated with `ALTER POLICY` instead of being dropped.
- The service-worker cache version was bumped so the fixed JavaScript/config is not trapped behind an old cached version.

## 1. Create / repair the Supabase database

1. Open your Supabase project.
2. Go to **SQL Editor**.
3. Run the complete `supabase_schema.sql` file in this package.
4. Go to **Authentication → Providers → Email**.
5. Make sure **Email provider** is enabled.
6. Make sure **Confirm email** is OFF for this username-only flow.
7. Make sure **Allow new users to sign up** is ON.

Supabase password authentication requires an email address or phone number. Meridian keeps the visible UI as username + password and internally maps a username to a synthetic identifier such as `kelechi@meridian.local`. The app does not store passwords in the Meridian tables.

Supabase documents that when email confirmation is enabled, `signUp()` can return a user with a null session; when confirmation is disabled, a session is returned immediately. That is why this app requires Confirm email to be OFF for this username-only flow.

## 2. Cloudflare Pages — Git deployment

Recommended settings:

- **Build command:** `npm run build`
- **Build output directory:** `.`
- **Node.js:** 20+

Add these environment variables to the Cloudflare Pages project:

- `SUPABASE_URL` — your Supabase project URL
- `SUPABASE_ANON_KEY` — your Supabase public anon/publishable key

Never put a Supabase `service_role` or secret key in this project.

## 3. Cloudflare Pages — Direct Upload

If you are uploading the folder directly instead of connecting Git:

1. Open `config.js`.
2. Replace `YOUR_SUPABASE_URL` with your Supabase project URL.
3. Replace `YOUR_SUPABASE_ANON_KEY` with your public anon/publishable key.
4. Upload the folder to Cloudflare Pages.

Do not put a secret/service-role key in `config.js`.

## 4. Test authentication

After the database setup and deployment:

1. Open the app.
2. Select **Create account**.
3. Enter a username of 3–24 letters, numbers, or underscores.
4. Enter a password of at least 6 characters.
5. Create the account.
6. Add an activity, goal, or calendar event.
7. Log out.
8. Log in with the same username/password.
9. The saved records should return automatically.

If sign-up still reports that email confirmation is enabled, change **Confirm email** to OFF in the Supabase Email provider settings and try again.

## Security

- Supabase Authentication manages password hashing and verification.
- Passwords are not stored in the Meridian database tables.
- Row Level Security is enabled on profiles, activities, events, and goals.
- Each user can access only rows whose `user_id` matches their authenticated `auth.uid()`.
- Only the public Supabase browser key belongs in frontend code.

## Files

- `index.html` — Meridian application
- `config.js` — browser-safe Supabase connection configuration
- `supabase_schema.sql` — non-destructive database schema and RLS policies
- `scripts/generate-config.js` — injects Cloudflare environment variables when available
- `manifest.json` — PWA manifest
- `sw.js` — service worker
- `_headers` — Cloudflare security headers
- `wrangler.toml` — Cloudflare Pages configuration
