# APP_DETAILS: Study app (working title: Maximus)

Master doc. Version 3 (24 Nov 2026). Replaces the "fact card feed" concept (v2) and adds accounts, sync and the Claude Design export.

# V3 CHANGES (24 Nov 2026) - read first

These override anything below that conflicts.

"V1" now means a fully working app that serves the aim (study history, scroll facts). Extras come later.

Decided by the user:
- **Accounts are in V1 and sign-in is required. No guest mode.** Sign in with Google, or with email and password (no email verification, D48). Real users, so data is stored on our server.
- **The server stores:** ratings, study list, lesson progress, quiz scores, feed saves and likes, onboarding picks and settings, and chat history.
- **Offline-first stays.** The phone is the working copy; the server is the backup and syncs in the background. Reading, quizzes and the feed keep working offline.
- **Study list lives inside Library** (design). Bottom tabs: Home, Library, Feed, Settings. No separate Study tab.
- **Fact of the day** on Home: a compact card (thumbnail, date, one fact under 25 words) picked by date from a bundled hand-written list of about 100 facts. Works offline.
- **Posters:** flat SVG in one style, made in Claude Design, for all 28 topics and all 51 people (79 total). Day and evening versions per the design (v4).
- **People section keeps the name "Think Like..."**.
- **Hosting:** Render free tier for the API.
- **Design source:** the Claude Design export (Maximus_Design.zip, 24 Nov). The first design had 20 topics; all 28 need posters before launch.

My defaults, NOT yet confirmed by the user (change if you disagree):
- Google sign-in ships first; email and password second.
- User data lives in a hosted Postgres (Neon free tier), not SQLite. Render's free disk is wiped on redeploy, so SQLite would lose users' data.
- Chat history is kept 5 days (rolling, per message) per user per title, deletable by the user.

Consequences:
- Play Store needs a privacy policy URL, the Data safety form, and account deletion inside the app plus a public web page for deletion.
- Chat logging reverses the v2 rule "log failures, not conversations". Chat text is now personal data: disclose it, allow deletion, include it in the security audits.
- Security audits (Cloudflare skill, Strix) are required before launch, not optional.

---

## 1. One-line idea
A study app that feels like Netflix, Duolingo and TikTok instead of a textbook: browse a poster library of 28 topics plus a Think Like... section of 51 great leaders and thinkers, add them to your study list, learn in short lessons, test yourself with quizzes, scroll a feed of facts from your topics, and ask a chatbot that only knows the topic you are studying.

## 2. Why it exists
Replace doomscrolling with something that leaves you knowing more. Goals: personal use, portfolio, Play Store launch. Solo builder, Claude writes most code. Free now, paid upgrade possible later. No deadline.

## 3. What is decided
- Android first, Flutter. Accounts required (see V3 CHANGES). The phone keeps the working copy of everything personal and syncs it to the server.
- 28 topics, exactly ONE title per topic, plus a Think Like... section with 40 leaders and 11 thinkers (full list in TOPICS.md). A topic title = one big Wikipedia article (or a few) split into lessons of about 400 words. People titles are short profiles with traits, reforms and 'impossible' wins (leaders) or core ideas (thinkers).
- Content is stored in our own database, bulk-imported from Wikipedia/Wikimedia, refreshed weekly. Only "On This Day" is live.
- Chatbot: AI model (OpenRouter free models and Google's free Gemini API), answers only from the stored text of the topic you are in. API keys stay on our server, never in the app.
- Vibe: Netflix (library), Duolingo (quizzes, playful), Spotify (made-for-you covers), TikTok/Reels (feed). NOT a news app, NOT serious or paper-like. Warm bronze/gold palette, dark-first, with a light theme.
- Roman look only in logo and splash.

## 4. Topics and people
The final list lives in **TOPICS.md** (single source of truth): 28 topics in five groups (ancient and medieval, India, revolutions and empires, wars and space, money and crashes) and the Think Like... section (leaders: ancient, Rome, medieval, Europe, India, Africa; thinkers: philosophers).
Later (not launch): War strategy, Psychology, Geography, General knowledge.

## 5. Sections of the app
1. **Sign in / Create account**: Google, or email and password. Create account asks email, password and confirm password and signs the user in at once; there is no email verification (D48). Required before onboarding.
2. **Library**: Netflix-style rows (Ancient, Revolutions, Wars, India...). The **study list is the first section under the hero**. Each title is a poster with its own title styling and a picture. Tap: detail sheet with short brief, match %, rate control, "Add to study list".
3. **Match %**: "You'll like this: 87%". Computed on the phone from your picked interests, titles you added, lessons you finished and your ratings. Rough at first; sharper as you rate.
4. **Rate it**: thumbs up / okay / thumbs down on any title. Feeds match %. (Design: up raises other titles in the group, down lowers them; exact numbers come from CONTRACTS section 6.)
5. **Study list**: titles you added, with progress bars. Lives in Library.
6. **Reader**: lessons one at a time, images with credit, read-aloud. Bottom nav gets a **Chat** button while a title is open.
7. **Chat (per topic)**: asks only about the open title. Off-topic questions get a polite refusal. Answers cite the lesson they came from. History is saved to your account.
8. **Quiz**: per title, 6 random questions from a hand-written bank of ~50, graded on device, Duolingo-style feedback. No streak pressure, no timers.
9. **Feed**: vertical swipe cards (image + one fact) drawn from your study-list topics. "Go deeper" opens the lesson.
10. **Home (dashboard)**: continue studying, study-list progress, quiz scores or the quiz tile, topics for you (high match %), **Fact of the day**, On This Day.
11. **Onboarding**: sign in, theme and text size, interests by era or region (3 to 5), favourite leaders (1 to 3), first matches.
12. **Settings**: profile, taste, theme, text size, read-aloud voice, clear my data, **sign out**, **delete my account**, about and credits (CC BY-SA), privacy policy.
13. **Think Like...**: a library section of people. Each person is a portrait poster; the title page shows traits, what they changed and the wars they won against the odds (leaders), or core ideas and how they apply today (thinkers).

## 6. Build order (no dates)
Built and merged (S1 to S14): backend, ingest, library, title sheet, study list, match %, ratings, reader, settings, quiz, feed, chat proxy.
Next: S12 (real API client), docs/design-delta, S17 (backend accounts + sync on Postgres), S18 (app sign-in + sync), S5 (onboarding + Think Like), S15 (chat UI), Fact of the day, Library/Study-list restructure, poster art, S11b (people titles), S16 (QA, security audits, store prep).
V2: Perspective mode (below), more topics.

## 7. V2: Perspective mode
User picks a country and a period inside a title (example: France, 1780s). Then picks a lens: rulers/aristocracy, middle/working class, or poor/peasants. The app shows what that group faced: daily life, grievances, what they gained or lost.
Risks, stated plainly:
- Wikipedia text rarely has clean per-class detail. Needs a curated source text per title and lens (can start with 3 or 4 titles).
- Generated text must be grounded in stored sources and labelled "an interpretation", or it will invent things.
- Do it as pre-written, reviewed lens texts per topic first; live generation only later.

## 8. Cost and limits (chatbot)
- Free tiers have rate caps and can change or disappear. Design for it: server proxy, fallback between providers (OpenRouter free model, then Gemini), daily message cap (per install and global, and per account once accounts exist), friendly "chat is resting" state.
- Because titles are small (about 80), each title's text can be sent as context. No vector database needed.
- Free models are weaker at obeying "stay on topic". Use a strict system prompt plus a server-side check, and test with off-topic attacks.

## 9. Open items
Final app name; launch subset of titles; per-title title-art picks; Postgres host (default Neon); email-and-password timing; chat retention (default 5 days, decided D46); person sheet and people posters design; poster art for the 8 topics the design lacks; quiz banks (~50 questions per topic and per person, launch subset first); who reviews facts before launch.
