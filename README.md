[README.md](https://github.com/user-attachments/files/30503715/README.md)
# Meridian — Netlify + Supabase

This version keeps the existing Meridian interface, but moves account data from the browser-only storage layer to Supabase.

## What is now persistent

Each signed-in user gets their own:
- Activities / logged hours
- Calendar events
- Daily, weekly, monthly and yearly goals
- Goal completion state

Passwords are handled by Supabase Authentication. The Meridian database never stores plaintext passwords.

## 1. Create the backend

1. Create a project in Supabase.
2. Open **SQL Editor**.
3. Run `supabase_schema.sql`.
4. Go to **Authentication → Providers → Email**.
5. Turn **Confirm email** off for this username-only login flow.

The app intentionally uses a synthetic internal email (`username@meridian.local`) so the visible authentication UI can stay username + password. Do not use this flow if you need email verification or password-reset emails; in that case, change the UI to collect an actual email address.

## 2. Configure Netlify

In your Netlify site:

**Site configuration → Environment variables**

Add:
- `SUPABASE_URL` = your Supabase project URL
- `SUPABASE_ANON_KEY` = your Supabase publishable/anon key

Use the public **anon/publishable** key only. Never put a `service_role` key in the frontend.

The Netlify build automatically generates `config.js`.

## 3. Deploy

Upload this folder to Netlify or connect the repository.

The build command in `netlify.toml` runs automatically.

## Local testing

If you want to test without Netlify, edit `config.js`:

```js
window.MERIDIAN_CONFIG = {
  supabaseUrl: "https://YOUR-PROJECT.supabase.co",
  supabaseAnonKey: "YOUR-PUBLIC-ANON-KEY"
};
```

Then serve the folder through a local web server. Do not open `index.html` directly with `file://`.

## Security

Row Level Security is enabled on every user-data table. Every activity, event and goal is tied to `auth.uid()`, so one account cannot read another account's data through the Supabase API.

The Supabase public/anon key is designed to be exposed in browser code; the database RLS policies are what protect the data. Never expose the service-role key.
