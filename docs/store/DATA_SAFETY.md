# Google Play Data safety form: proposed answers

Derived from the code and docs on 2026-11-25 (CONTRACTS 11, 14 to 17, BACKEND.md, `AndroidManifest.xml`,
`pubspec.yaml`). Play's rules were read on 2026-11-25 from
https://support.google.com/googleplay/android-developer/answer/10787469 (no "last updated" date shown on the page).
**The owner is responsible for the final answers.** Anything marked UNVERIFIED or TODO needs a decision first.
The form must match the privacy policy (`PRIVACY_POLICY.md`).

Play's definitions (from that page): **Collect** = transmitting data off the user's device. **Share** =
transferring collected data to a third party; transfers to a **service provider** (an entity that processes data on
the developer's behalf and on the developer's instructions) are not "sharing".

## Section 1: Data collection and security

| Question | Answer | Basis |
|---|---|---|
| Does the app collect or share any required user data types? | **Yes** | Accounts are required; email is sent to the server |
| Is all user data encrypted in transit? | **Yes** | All app traffic is HTTPS; HSTS in production; cleartext only in debug builds (CONTRACTS 11, DEPLOY.md 11). Confirm after deploy that no code path uses `http://` |
| Do you provide a way for users to request data deletion? | **Yes** | In-app Settings, Delete my account; web page `/account/delete` (see `ACCOUNT_DELETION.md`) |

## Section 2: Data types

Permissions in the manifest: `INTERNET` only. No location, contacts, camera, microphone, storage or advertising id.
No analytics, ads or crash-reporting SDK (`pubspec.yaml` dependencies: `google_sign_in`, `dio`, `drift`,
`flutter_secure_storage`, `connectivity_plus`, `flutter_tts`, `cached_network_image`, `url_launcher`, `flutter_svg`
and UI libraries). `flutter_tts` speaks text on the device only. UNVERIFIED: re-check transitive plugins in the
release build (for example run the Play pre-launch report) before submitting.

| Data type (Play category) | Collected | Shared | Optional or required | Purpose | Notes |
|---|---|---|---|---|---|
| Personal info: **Email address** | Yes | No | Required | Account management; App functionality | Used to sign in and send reset or deletion mail. Resend sends those mails for us: a service provider, so not "shared" |
| Personal info: **Name** | Yes | No | Optional | Account management | Display name typed at sign-up (optional), or the name on the Google profile. Stored up to 80 characters |
| Personal info: **User IDs** | Yes | No | Required | Account management; App functionality; Fraud prevention, security | Server account id; Google account id (`sub`) when Google is used |
| Personal info: password | Yes | No | Required for email accounts | Account management | Stored only as an Argon2id hash. Play has no separate "password" type. TODO: owner picks where to declare it (usually under User IDs or a note); UNVERIFIED which category Play expects |
| App activity: **App interactions** | Yes | No | Required (for sync) | App functionality | Study list, ratings, lesson progress, quiz results, saved and liked feed cards, onboarding picks. Settings (theme, text size, voice) can be declared here too. UNVERIFIED: Play may expect "Other actions" for some of it; declaring both is safe |
| Messages: **Other in-app messages** | Yes | See next row | Optional (chat is opt-in) | App functionality | Chat questions and answers, kept 5 days. UNVERIFIED: Play may prefer "App activity > Other user-generated content"; the owner picks one or declares both |
| Chat text sent to AI providers | Yes | **Yes, proposed** | Optional | App functionality | OpenRouter and Google Gemini receive the question, the lesson text and the last few turns (no email or id). They process it on our instructions, so Play's service-provider exemption **may** apply, but UNVERIFIED: free-tier providers can keep or train on prompts. Conservative proposal: answer **Shared = Yes** until their terms are read and documented. TODO owner decision |
| Location (any) | No | No | n/a | n/a | Not requested |
| Financial info | No | No | n/a | n/a | No payments or ads |
| Health and fitness | No | No | n/a | n/a | |
| Contacts | No | No | n/a | n/a | |
| Photos and videos; Audio files; Files and docs | No | No | n/a | n/a | |
| Calendar | No | No | n/a | n/a | |
| Web browsing history | No | No | n/a | n/a | The app opens privacy and deletion links in the browser; it does not read history |
| App info and performance: crash logs, diagnostics | No | No | n/a | n/a | No SDK in the app. The server logs errors and timings only (no email, no chat text) |
| Device or other IDs | No | No | n/a | n/a | The install id is random, local only and never sent. No advertising id. UNVERIFIED: Play may treat the IP address the server inevitably sees as collected; check the Play Data safety FAQ and the Render log retention, then decide |
| Search history in the app | No | No | n/a | n/a | No search is sent to the server |

## Section 3: Per-type questions the form will ask

- **Is this data processed ephemerally?** No for all rows above (it is stored). Chat sent to AI providers is
  stored by us for 5 days; the providers' retention is UNVERIFIED.
- **Is this data required or optional?** As in the table.
- **Why is this data collected? / shared?** As in the table. None of it is used for advertising, marketing,
  analytics or developer communications. Do **not** tick Advertising or marketing, Analytics, or Personalization.
  (Match percentages are computed on the phone.)

## Section 4: Security practices and deletion (the form's extra questions)

| Question | Answer |
|---|---|
| Data encrypted in transit | Yes |
| Users can request data deletion | Yes: in the app and at `https://maximus-api.onrender.com/account/delete` (TODO final URL, see `ACCOUNT_DELETION.md`) |
| Committed to the Play Families Policy | No (the app is not designed for children; owner confirms, see PRIVACY_POLICY "Children") |
| Independent security review (MASA badge) | No, unless the owner buys one. The planned security audits are not that |

## Open questions

1. TODO owner: AI providers as "shared" or "service provider" (needs their terms, UNVERIFIED).
2. UNVERIFIED: category for the password and for chat text (see rows).
3. UNVERIFIED: IP address handling by Render.
4. Backups keep data up to 28 days after deletion; Play's account-deletion page says retained data must be
   disclosed in the privacy policy (it does not mention backups specifically). `PRIVACY_POLICY.md` discloses it.
5. Re-fill this form whenever the code changes what is collected (for example if analytics or crash reporting is added).
