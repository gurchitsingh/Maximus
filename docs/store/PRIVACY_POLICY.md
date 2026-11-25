> **DRAFT. The owner must read every line before publishing.** Claude is not a lawyer and this is not legal
> advice. Every statement was checked against the code and docs in this repo on 2026-11-25, not against any law.
> Items marked TODO or UNVERIFIED must be settled first. The live page is served by the backend from
> `backend/app/templates/privacy.html`; this file is the proposed replacement text (see "Differences from the
> live page" at the end). The app name is still open: "Maximus" is the working title.

# Privacy policy

Last updated: TODO (set the date when the owner approves this text)

Maximus (working title, final name TODO) is a history study app. This page says what we keep about you, why,
where, for how long, who else sees it, and how to delete it.

Developer and contact: TODO (name of the developer as shown on the Google Play listing) and TODO (contact
email; the server shows `CONTACT_EMAIL` on `/privacy`, which is not set yet).

## What we collect

You must create an account to use the app. We keep:

- **Account:** your email address; a password, stored only as a one-way hash (Argon2id), never the password
  itself; if you sign in with Google, the Google account id (`sub`) and the name on your Google profile; a display
  name if you give one.
- **Study data:** the topics and leaders you picked at the start, your study list, your ratings of titles, your
  lesson progress, your quiz results (score, which questions you got wrong), the feed cards you saved or reacted
  to, and your settings (theme, text size, read-aloud voice and speed, whether onboarding is done).
- **Chat messages:** what you type in a title's chat and the answers, with the references to the lessons used.
- **Chat usage count:** how many chats your account has used today, to enforce a daily limit.

We do not collect your location, contacts, photos, files, microphone input, advertising id or device identifiers.
The app makes a random install id for local use; it stays on the phone and is never sent to us. There are no ads
and no analytics or tracking tools in the app.

When your phone contacts our server, the hosting service necessarily sees your IP address and the time of the
request. UNVERIFIED: whether Render keeps IP addresses in its logs and for how long. Check Render's documentation
before publishing and state the answer here. Our own code does not store IP addresses and does not write
passwords or chat text to logs.

## Why we use it

To sign you in; to keep your progress safe if you lose your phone and to show the same data on your other
devices; to show chat history; to limit chat use per account so the free service stays available; to send the
password-reset and account-deletion emails you ask for. We do not use your data for advertising, profiling or
anything else.

## Where it is stored

- The app keeps a working copy on your phone. It works offline and syncs to our server in the background.
- The server runs on **Render** (render.com), region Frankfurt (TODO: confirm after deploy). The database is
  **PostgreSQL hosted by Neon** (neon.com). TODO: confirm the Neon region matches Render (`render.yaml` uses
  Frankfurt).
- Data is sent over HTTPS (the app only allows plain HTTP in debug builds).

## How long we keep it

- **Chat messages: 5 days.** Each message is deleted 5 days after it was written, one by one, so the oldest go
  first. You can delete one title's chat or all your chats at any time in the app.
- **Everything else:** until you delete it, or delete your account. Deleted study items are kept as empty
  "deleted" markers for up to 90 days so your other devices learn about the deletion; they hold no content.
- **Password-reset and deletion links:** valid for 1 hour and one use.
- **Sign-in sessions:** a refresh token lasts 60 days from your last use.

## Backups

The database host keeps a short restore window of about 6 hours (Neon free plan; TODO: re-check at launch).
Separately, the developer makes backup copies of the database to a private computer (never to a public place). The
backup script deletes copies older than 28 days **when it is run**. So after you delete your account, your data
can remain in a backup for up to 28 days. We do not use backups to restore deleted accounts' data on purpose.
TODO: owner must confirm the backup routine really runs often enough to keep the 28-day promise; the script
only deletes old copies when it is run.

## Who receives your data

We do not sell your data and we do not share it for advertising. These companies process data for us:

| Who | What they get | Why |
|---|---|---|
| Render | Everything the app sends to our server (it runs the server) | Hosting |
| Neon | The database: all data listed above | Database hosting |
| Resend (resend.com) | Your email address and the text of the reset or deletion email | Sending those emails. TODO: confirm Resend is the provider actually configured at launch (`EMAIL_PROVIDER=resend`) |
| Google | If you use "Continue with Google": Google handles that sign-in and we receive an ID token with your email and name | Sign-in |
| OpenRouter and Google Gemini | **The text of your chat question, the lessons of the title you are in, and your last few chat turns.** Not your email or account id. Which of the two answers depends on availability | To write the chat answer |

UNVERIFIED: what OpenRouter, the free model's provider behind it, and Google's Gemini free API do with the chat
text they receive (for example whether they keep it or use it to improve their products). Read their current
terms and write the real answer here before publishing. Until then, do not tell users the chat text is
"not stored" by them.

## Deleting your account and data

- **In the app:** Settings, then **Delete my account**. Email accounts type their password to confirm; Google
  accounts must have signed in within the last 5 minutes.
- **Without the app:** open https://maximus-api.onrender.com/account/delete (TODO: replace with the final
  address), enter your account email, and open the link we email you (valid 1 hour). Confirm on that page.
- **What is deleted:** your account, sign-in sessions, study data, chat messages and chat usage counts are deleted
  from our database at once. There is no "deactivate" state.
- **What may remain for a while:** backup copies (up to 28 days, see Backups), the database host's short restore
  window (about 6 hours), emails already sent to you (held by Resend: UNVERIFIED how long), and any text the chat
  providers kept (UNVERIFIED, see above).
- You can also delete only your chat history, or use "Clear my data" in Settings to remove your study data while
  keeping the account.

## Children

Maximus is not meant for children under 13, and we do not knowingly collect data from them. If you are a parent
and think a child under 13 has an account, contact us and we will delete it.

UNVERIFIED and TODO: (1) The Google Play Families policy page (checked 2026-11-25) does not give a minimum age for
general-audience apps; it covers apps whose target audience includes children, and the Play Console asks you to
declare a target age group. The owner must choose that declaration (for example 13 and over, or 18 and over) and
make this paragraph match. (2) Whether the app must also block or age-screen under-13 sign-ups (there is no age
check in the app today). (3) Laws that set other ages (for example the EU member states' ages of digital
consent, India's data-protection law) were not checked: ask a lawyer.

## Your choices and rights

You can see your stored data in the app, delete chats, clear your data and delete your account. TODO: if you
want to state rights to access or export your data under a particular law (for example GDPR), a lawyer must
write that part; the app has no data export today.

## Security

Passwords are hashed with Argon2id. Access tokens last 15 minutes. The server limits sign-in attempts. No
system is perfectly secure. TODO: add the date of the security audits planned before launch once they are done.

## Changes to this policy

When we change it we update the date at the top. TODO: decide whether the app will tell you about material
changes.

## Open source and credits

Lesson text and images come mostly from **Wikipedia and Wikimedia Commons**. Wikipedia text is available under
the **Creative Commons Attribution-ShareAlike 4.0 licence (CC BY-SA 4.0)**. We shortened and adapted it for
lessons, and our adapted lesson text is shared under the same licence. Each lesson and image carries its author,
licence and a link to the source, and the app has a Credits screen. Fonts are under the SIL Open Font Licence.
The app's source code is in a public repository (TODO: add its URL). Posters were drawn in Claude Design.
TODO: owner to confirm the licence terms and wording with a person qualified to check them.

## Contact

TODO: contact email and, if required by law where you live, a postal address.

---

## Differences from the live page (`backend/app/templates/privacy.html`)

Not edited (docs only). The backend page needs these changes before launch:

1. "We keep no copy" in the deletion paragraph is **wrong** given backups (up to 28 days) and the database host's restore window.
2. "Our email provider" is unnamed; DEPLOY.md names Resend. Name it.
3. "a display name if you give one": the server also stores the name from the Google profile (`google.py`, up to 80 characters).
4. No mention of 60-day sign-in sessions, 90-day deletion markers, or the chat usage counter.
5. No age statement, no Wikipedia CC BY-SA credit, no developer name, no backup statement.
6. The "last updated" date is 24 November 2026 and the contact line falls back to "the Google Play listing" until `CONTACT_EMAIL` is set.
