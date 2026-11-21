# APP_DETAILS: Study app (working title: Maximus)

Master doc. Version 2 (21 Nov 2026). Replaces the "fact card feed" concept.

## 1. One-line idea
A study app that feels like Netflix, Duolingo and TikTok instead of a textbook: browse a poster library of 28 topics plus a Think Like... section of 51 great leaders and thinkers, add them to your study list, learn in short lessons, test yourself with quizzes, scroll a feed of facts from your topics, and ask a chatbot that only knows the topic you are studying.

## 2. Why it exists
Replace doomscrolling with something that leaves you knowing more. Goals: personal use, portfolio, Play Store launch. Solo builder, Claude writes most code. Free now, paid upgrade possible later. No deadline.

## 3. What is decided
- Android first, Flutter. No accounts. Everything personal (study list, ratings, progress) lives on the phone.
- 28 topics, exactly ONE title per topic, plus a Think Like... section with 40 leaders and 11 thinkers (full list in TOPICS.md). A topic title = one big Wikipedia article (or a few) split into lessons of about 400 words. People titles are short profiles with traits, reforms and 'impossible' wins (leaders) or core ideas (thinkers).
- Content is stored in our own database, bulk-imported from Wikipedia/Wikimedia, refreshed weekly. Only "On This Day" is live.
- Chatbot: AI model (OpenRouter free models and Google's free Gemini API), answers only from the stored text of the topic you are in. API keys stay on our server, never in the app.
- Vibe: Netflix (library), Duolingo (quizzes, playful), Spotify (made-for-you covers), TikTok/Reels (feed). NOT a news app, NOT serious or paper-like. Keep the warm bronze/gold palette from the first design round, but dark-first.
- Roman look only in logo and splash.

## 4. Topics and people
The final list lives in **TOPICS.md** (single source of truth): 28 topics in five groups (ancient and medieval, India, revolutions and empires, wars and space, money and crashes) and the Think Like... section (leaders: ancient, Rome, medieval, Europe, India, Africa; thinkers: philosophers).
Later (not launch): War strategy, Psychology, Geography, General knowledge.

## 5. Sections of the app
1. **Library**: Netflix-style rows (Ancient, Revolutions, Wars, India...). Each title is a poster with its own title styling (font, colour, treatment per topic) and a picture of the topic. Tap: detail sheet with short brief, match %, rate control, "Add to study list".
2. **Match %**: "You'll like this: 87%". Computed on the phone from your picked interests, titles you added, lessons you finished and your ratings. Rough at first; sharper as you rate.
3. **Rate it**: thumbs up / okay / thumbs down on any title. Feeds match %.
4. **Study list**: titles you added, with progress bars.
5. **Reader**: lessons one at a time, images with credit, read-aloud. Bottom nav gets a **Chat** button while a title is open.
6. **Chat (per topic)**: asks only about the open title. Off-topic questions get a polite refusal. Answers cite the lesson they came from.
7. **Quiz**: per title, 6 random questions from a hand-written bank of ~50, graded on device, Duolingo-style feedback. No streak pressure, no timers.
8. **Feed**: vertical swipe cards (image + one fact) drawn from your study-list topics. "Go deeper" opens the lesson.
9. **Dashboard**: continue studying, study-list progress, quiz scores, topics for you (high match %), On This Day.
10. **Onboarding**: playful and image-led, with surprises (see FLOW.md).
11. **Settings**: theme, text size, read-aloud voice, about and credits (CC BY-SA).
12. **Think Like...**: a library section of people. Each person is a portrait poster; the title page shows traits, what they changed and the wars they won against the odds (leaders), or core ideas and how they apply today (thinkers). The section name is still open (Think Like a Leader / the Greats).

## 6. Build order (no dates)
- V1: Library, title detail, study list, match % + rating, reader, dashboard, onboarding.
- V1.1: Quiz.
- V1.2: Feed.
- V1.3: Topic chatbot.
- V2: Perspective mode (below), more topics.

## 7. V2: Perspective mode
User picks a country and a period inside a title (example: France, 1780s). Then picks a lens: rulers/aristocracy, middle/working class, or poor/peasants. The app shows what that group faced: daily life, grievances, what they gained or lost.
Risks, stated plainly:
- Wikipedia text rarely has clean per-class detail. Needs a curated source text per title and lens (can start with 3 or 4 titles).
- Generated text must be grounded in stored sources and labelled "an interpretation", or it will invent things.
- Do it as pre-written, reviewed lens texts per topic first; live generation only later.

## 8. Cost and limits (chatbot)
- Free tiers have rate caps and can change or disappear. Design for it: server proxy, fallback between providers (OpenRouter free model, then Gemini), per-device daily message cap, friendly "chat is resting" state.
- Because there are only 20 titles, each title's text can be sent as context. No vector database needed in V1.3.
- Free models are weaker at obeying "stay on topic". Use a strict system prompt plus a server-side check, and test with off-topic attacks.

## 9. Open items
Final app name; the section name; launch subset of titles; per-title title-art picks; hosting; quiz banks (20 x ~50 questions); who reviews facts before launch.
