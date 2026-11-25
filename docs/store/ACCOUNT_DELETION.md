# Account deletion (Play requirement)

**Source status.** My fetch of https://support.google.com/googleplay/android-developer/answer/13327111 returned an error stub, so I did not read it. The URL is only where to check. UNVERIFIED, as recalled: an app that lets users create an account needs an in-app deletion path and a web link for deletion requests; the web link must work without reinstalling and refer to the app or developer name; retained data must be explained to users, for example in the privacy policy; temporary deactivation does not count.

## In-app steps (code: `app/lib/features/settings/account_section.dart`)

1. Open the app, tab **Settings**.
2. In the account section tap **Delete my account**.
3. The dialog says what is removed. Email accounts enter their password; Google accounts must have signed in within
   the last 5 minutes (otherwise the server answers `reauth_required` and the user signs in again).
4. Confirm. The app calls `DELETE /v1/me`; on success it wipes the local data and tokens and returns to the sign-in screen.

## Public web page (code: `backend/app/routers/web.py`, `templates/delete_request.html`)

- **URL path:** `/account/delete` on the API host. With the planned Render service name that is
  `https://maximus-api.onrender.com/account/delete` (from `DEPLOY.md`). UNVERIFIED: the service is not deployed
  yet, so this address is untested. TODO: replace if a custom domain is used, and open it in a private browser
  window before submitting.
- Flow: enter the account email, then `POST /account/delete/request`. The page always says "If an account exists
  for that address, we sent a link" and emails a one-hour, one-use link (limits: 3 per hour per email, 10 per minute
  per IP). The link opens `/account/delete/confirm?token=...`, which shows a **Delete my account** button; the
  button posts and deletes. Works for Google and email accounts. It needs working email sending in production
  (`EMAIL_PROVIDER=resend` with a verified sender); with the default `console` provider no email is sent.
- Page title today: "Delete your Maximus account" (the working name). If the app is renamed, the page must be
  updated (Play wants the app or developer name on it: UNVERIFIED).

## What is deleted, what is kept

Deleted at once, in one transaction (CONTRACTS 17): refresh tokens, email tokens, all synced records (study list,
ratings, progress, quiz results, feed state, picks, settings), chat messages, chat usage counts, and the user row.
No soft delete.

Kept for a while (must be disclosed, and is in `PRIVACY_POLICY.md`):
- Backups made by the owner with `backend/tools/backup.ps1`: up to 28 days, and only when the script is run.
- Neon's restore window: about 6 hours (free plan, per DEPLOY.md; re-check).
- Emails already sent (Resend): UNVERIFIED retention.
- Chat text at OpenRouter / Google Gemini: UNVERIFIED.

## Text for the Play Console form (App content, Data safety, Data deletion questions)

- Does your app let users create an account? **Yes** (email and password, or Google).
- Deletion link (URL): `https://maximus-api.onrender.com/account/delete` (TODO final).
- Suggested description of what is deleted and kept (paste or adapt):

  > Users can delete their account in the app (Settings, Delete my account) or on the web page above. Deleting the
  > account permanently removes the email address, sign-in data, study progress, ratings, quiz results, saved items,
  > settings and chat messages from our database immediately. Backup copies kept on the developer's private
  > computer are deleted within 28 days. The database host keeps a restore window of about 6 hours.
  > TODO: owner confirms every sentence is true on launch day.

## Check before launch

- [ ] Delete a test email account in the app; sign in again fails; the row is gone.
- [ ] Delete a test Google account the same way (inside 5 minutes of signing in).
- [ ] Use the web page with a test account; confirm the email arrives and the link works once only.
- [ ] Open the web URL logged out, on a phone, after the server has been idle (it sleeps; the first load can take about a minute).
