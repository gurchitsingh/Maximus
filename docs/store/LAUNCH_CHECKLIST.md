# Play Console launch checklist (new personal developer account)

**Source status.** My earlier fetches of the Google Play help pages returned error stubs, so none of those pages
was actually read. Every Play rule below is **UNVERIFIED** and is written from memory or from unconfirmed second-hand
summaries; the URL beside each is only "where to check". The one exception is the closed-testing rule in section 2,
verified from the official page by the owner on 2026-11-25. Recheck every other rule in the Console or on the Play
help page before relying on it. Never commit keystores, `key.properties` or passwords (`.gitignore` already lists
`*.jks` and `key.properties`).

## 0. Blockers found in this repo (fix before any upload)

- [ ] **Release build is signed with the debug key** (`app/android/app/build.gradle.kts`, "TODO: Add your own
      signing config"). Play will not accept a debug-signed bundle. Create an upload key (section 4).
- [ ] The backend is **not deployed yet** (`backend/DEPLOY.md` says nothing has been run). The privacy and deletion
      URLs must work before you fill the forms.
- [ ] **Image storage is undecided** (DECISIONS D44, DEPLOY.md 10): `/media` images 404 on Render's free disk.
- [ ] Final app name and package id (`com.gurchit.maximus.maximus`) are undecided; the package name is permanent once uploaded.
- [ ] Privacy page and deletion page need the edits listed at the end of `PRIVACY_POLICY.md`.
- [ ] Security audits planned before launch (APP_DETAILS) are not done: TODO.

## 1. Account (Play rules UNVERIFIED)

| Step | Rule | Where to check (all UNVERIFIED) |
|---|---|---|
| One-time fee | US$25, one time; credit or debit card, no prepaid cards | https://support.google.com/googleplay/android-developer/answer/6112435 |
| Age and agreement | Must be 18 or older; accept the Developer Distribution Agreement | same page |
| Identity | A personal account without a verified Google Payments profile must provide an official government ID; Google may require ID and a card in your legal name; an invalid entry means the fee is not refunded | https://support.google.com/googleplay/android-developer/answer/10841920 |
| Contact | Verify a public developer email with a 6-digit code; contact phone and email (not public) also verified. The phone cannot be verified until identity and device verification are done | same page |
| Device verification | New personal accounts must verify access to a real Android phone with the Play Console mobile app before they can make an app available on Google Play | same page |
| Document list by country | not read: https://support.google.com/googleplay/android-developer/answer/15633622 | UNVERIFIED |

- [ ] Choose the developer name carefully: it is shown on the listing and must appear in or match the privacy policy.

## 2. Testing requirement for new personal accounts

**VERIFIED** (official page https://support.google.com/googleplay/android-developer/answer/14151465, checked
2026-11-25 by the owner's other session): personal developer accounts created after 13 November 2023 need a
**closed test with at least 12 testers opted in continuously for at least 14 days** before applying for production
access.

UNVERIFIED (recheck on that page): the 14 days must be consecutive if a tester opts out and back in; the
"Apply for production" step is on the Dashboard and asks about the closed test, the app and production readiness;
review time (usually about 7 days or less); internal testing has no such requirement; open testing and
production need production access; no exemption for personal accounts.

Plan: recruit 15 or more testers (a margin above 12), by Google Group or email list in the closed track. TODO:
who they are. Testers should use the app on real phones for the full period and give feedback you can cite in the application.

## 3. App content and forms (Policy, App content) (Play rules UNVERIFIED)

| Item | What to enter | Doc |
|---|---|---|
| Privacy policy URL | `https://maximus-api.onrender.com/privacy` (TODO final). Must be a public, active, non-geofenced URL that is not a PDF, and a link or text must also be inside the app (Settings has it) | https://support.google.com/googleplay/android-developer/answer/10144311; where to check, UNVERIFIED |
| Account deletion URL and answers | `/account/delete` and in-app path | `ACCOUNT_DELETION.md`; rule at https://support.google.com/googleplay/android-developer/answer/13327111; where to check, UNVERIFIED |
| Data safety form | Required for closed, open and production tracks (apps only on internal testing are exempt) | `DATA_SAFETY.md`; https://support.google.com/googleplay/android-developer/answer/10787469; where to check, UNVERIFIED |
| App access instructions | Reusable login the reviewer can use; see below | https://support.google.com/googleplay/android-developer/answer/15748846; where to check, UNVERIFIED |
| Ads | No ads | |
| Content rating | IARC questionnaire; answer honestly | `STORE_LISTING.md`; https://support.google.com/googleplay/android-developer/answer/9859655; where to check, UNVERIFIED |
| Target audience | Owner decision; Families policy applies if children are in the target audience | https://support.google.com/googleplay/android-developer/answer/9893335; where to check, UNVERIFIED |
| Store listing | Name, short and full description, icon, feature graphic, screenshots | `STORE_LISTING.md` |

### App access instructions for reviewers

UNVERIFIED (recalled): Play requires sign-in details that are reusable, always valid, valid regardless of location, in English, and
that work without 2-step verification or one-time codes (page above). For this app:

- [ ] Create a dedicated account such as `TODO-review@<your domain>` with a password of 10 to 128 characters.
      Because email verification was removed (D48) the account signs in at once, with no mail step.
- [ ] Put in the instructions: "Tap Create account or Sign in, choose email and password, and use the
      credentials below. Google sign-in is also available." Give email and password here in the Console only
      (never in git or chat).
- [ ] The account must keep working. Do not delete it, and keep its rate limits in mind (5 failed sign-ins per
      15 minutes per email).
- [ ] Say that the server is on a free tier and **the first request after idle can take about a minute**
      (DEPLOY.md 11 item 1); the app shows a "Waking the server" state. Warm it up just before review.
- [ ] Say that chat has a daily limit per account (20 per UTC day) and may show "chat is resting" if the AI
      providers are unavailable.
- [ ] Reset-password email needs the mail provider to be live (Resend, DEPLOY.md 5); not needed for review.

## 4. App signing and the upload key (Play rules UNVERIFIED)

Where to check (rules below UNVERIFIED): https://support.google.com/googleplay/android-developer/answer/9842756

- Use **Play App Signing**: Google holds the app signing key; you hold an **upload key** and sign each bundle
  with it. A lost or compromised upload key can be reset through Play Console (create a new key, export its
  certificate as PEM with `keytool`, "Request upload key reset"). An app signing key you manage yourself cannot
  be reset if lost. Keep the upload key and app signing key different.
- Once an app is published to an open track the signing key is fixed (https://support.google.com/googleplay/android-developer/answer/9859348; where to check, UNVERIFIED).
- [ ] Generate the upload keystore **outside the repo** (for example under `%USERPROFILE%\keys\`), back it up to
      a private place, and record its password in a password manager. Create `app/android/key.properties`
      (gitignored) and wire it into `build.gradle.kts` in a **separate** change; this docs branch does not touch `app/`.
- [ ] After the first upload, copy the **app signing certificate SHA-1** from Play Console (Test and release,
      App integrity) into the Google Cloud **Android** OAuth client (DEPLOY.md section 4). Without it Google
      sign-in fails in Play builds. Also keep the upload key's SHA-1 there if you test with it.

## 5. Build facts (Play rules UNVERIFIED)

| Item | Value now | Rule |
|---|---|---|
| Format | Build an **app bundle** (`flutter build appbundle`) | One signed bundle; https://support.google.com/googleplay/android-developer/answer/113469; where to check, UNVERIFIED |
| versionCode | `1` (from `version: 1.0.0+1` in `app/pubspec.yaml`) | Must increase with every update; maximum 2100000000 (same page). Bump the number after `+` for each upload |
| Package name | `com.gurchit.maximus.maximus` | Permanent and cannot be reused (same page) |
| Target API | Flutter in this PC's SDK sets `targetSdkVersion = 36` (`flutter/packages/flutter_tools/gradle/.../FlutterExtension.kt`, version of the local SDK folder) | From 31 Aug 2026 new apps and updates must target Android 16 (API 36) or higher; an extension to 1 Nov 2026 has already passed. https://support.google.com/googleplay/android-developer/answer/11926878; where to check, UNVERIFIED |
| minSdk | `flutter.minSdkVersion` | No Play rule known; UNVERIFIED which Android versions you want to support |
| App size | not measured | Limit number: UNVERIFIED |

- [ ] Recheck the target-API page on the day you build: Play raises the level yearly, and the Flutter SDK must be recent enough.
- [ ] Confirm the release build actually has `targetSdk` 36 (inspect the merged manifest in the built bundle).

## 6. Release track order (Play rules UNVERIFIED)

Where to check the track rules (UNVERIFIED): https://support.google.com/googleplay/android-developer/answer/9859348

1. **Internal testing** (up to 100 testers, no extra requirements). Upload the first signed bundle here, install
   from the Play link, test sign-in (Google and email), sync, chat, deletion.
2. **Closed testing**, 12 or more testers for 14 or more consecutive days (section 2). A new release cannot be
   created while another is outstanding on that track.
3. **Apply for production** from the Dashboard.
4. **Production.** A first release cannot use a staged rollout; staged rollouts work for updates only
   (https://support.google.com/googleplay/android-developer/answer/6346149; where to check, UNVERIFIED). Use a staged percentage
   (for example 10 %, then raise manually: it does not increase by itself) from the second release on.
5. Open testing is optional and requires production access.

## 7. Pre-launch report (Play rules UNVERIFIED)

Where to check (rules below UNVERIFIED): https://support.google.com/googleplay/android-developer/answer/7002270

- It is generated automatically when you upload a bundle (device-lab capacity permitting) and tests stability,
  Android compatibility, performance and accessibility. A crawler taps, types and swipes for several minutes.
- Test devices are in the US and need a main launch activity.
- Credentials: it recommends not adding real credentials; give a test account. With "Sign-in with Google" the
  crawler cannot do it, so give it the **email test account** and mention the server's cold start.
- [ ] Read the report for every upload to closed testing and production; fix crashes and accessibility issues first.

## 8. Rollback plan (Play rules UNVERIFIED)

UNVERIFIED: I could not read Google's pages; as recalled they do not describe reverting a published release to an old build (the word "rollback" is not
used; check the staged-rollout page above and https://support.google.com/googleplay/android-developer/answer/16285429). What exists:

- **Halt a staged rollout:** no further users get the version; those who have it keep it.
- **Halt a fully rolled-out release** (not available for the first release on a track, not on internal tracks):
  the previous live version takes its place for new installs and updates; users already updated stay on the
  halted version. If the previous release has a policy violation it cannot be used.
- **Fix forward:** build a fixed bundle with a **higher versionCode** and roll it out.

Plan:
- [ ] Keep the previous release's bundle and keystore reference so you can ship it again under a new versionCode if halting is not enough.
- [ ] First production release goes to everyone at once (no staged option); so test hard in closed testing.
- [ ] Server side: sync and API changes must stay compatible with older app versions (API is `/v1`; a breaking change needs `/v2`), so a halt does not break the old app.
- [ ] Deployment: Render `autoDeploy` is off; deploy the backend after CI is green (DEPLOY.md), and run `backend/tools/backup.ps1` first. Know the Render dashboard's rollback to a previous deploy (UNVERIFIED: check the current Render feature before relying on it).
- [ ] Kill switch: nothing exists to disable the app remotely. TODO decide if one is needed.

## 9. Final pre-submit pass

- [ ] Privacy URL, deletion URL open in a private window on a phone, with the server asleep first.
- [ ] Data safety answers match the privacy policy and the shipped build (`DATA_SAFETY.md`).
- [ ] Content rating answers recorded; screenshots show no personal data.
- [ ] Credits screen present (CC BY-SA); store text does not claim more than the build does.
- [ ] Backups: run `backup.ps1` once, test one restore (DEPLOY.md 9).
- [ ] Contact email set as `CONTACT_EMAIL` on Render so `/privacy` shows it.
