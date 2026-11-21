# Prompts for Claude Design: redo (v3, 21 Nov 2026)

Staged. Run in order inside ONE new Claude Design project (do not reuse the round-1 canvas). Approve each stage before the next.
Attach to Prompt 1 if possible: 3 to 4 screenshots each of Netflix (home + title page), Duolingo (lesson + result), Spotify (home) and TikTok (feed), plus a screenshot of the round-1 colour palette. Say "mood only, do not copy".

| Stage | What you get |
|---|---|
| 1 Foundations | colours, type, illustration style, components |
| 2a Start | splash, 5-step onboarding, Home dashboard |
| 2b Library | library, title sheet, study list |
| 2c Learning | reader, chat, quiz, feed, settings |
| 3 Logo | 3 directions |
| 4 Fix-it | corrections |

Changes from the last round: Netflix-style dark-first, generated illustrations (one style) instead of empty image slots, library/dashboard/quiz/chat/feed added, 4 onboarding surprises.

---

## Prompt 1: Foundations

**Paste from here**

Design the visual system for **Maximus** (working title), an Android app that teaches history. It works like this: a Netflix-style library of 28 topics shown as posters, plus a "Think Like..." section of great leaders and thinkers (kings, queens, philosophers) shown as portrait posters; you add topics to a study list; each topic is a short series of lessons; Duolingo-style quizzes; a TikTok-style vertical feed of facts; a dashboard; and a chatbot that only answers about the topic you are studying. No accounts.

**Feel:** cinematic, playful, image-led, energetic. References for mood only: Netflix (poster rows, title pages), Duolingo (friendly feedback, delight), Spotify (rich covers, "made for you"), TikTok (full-screen vertical cards). It must NOT look like a news app, newspaper, textbook, museum website or serif editorial layout. No paper textures, no column layouts, no dense text screens.

**Keep one thing from the last round:** the warm bronze/gold accent (about #C8933A). Everything else is new. Dark-first: near-black warm background (#0F0D0A to #17130E). Also design a light theme with the same structure.

**Illustration style (important):** every topic picture is a **generated illustration in ONE consistent style** (propose it: for example bold painterly poster art with a strong silhouette and a limited palette per topic). Not photos, not empty grey boxes. Show it working for topics as different as the Roman Empire, the French Revolution, WW2 and Ancient Egypt. Each topic poster has its own accent colour taken from its illustration.

**Title lettering:** each topic gets its own title treatment so posters feel like different shows (examples: Roman = chiselled capitals; French Revolution = hand-lettered; WW2 = stencil; Egypt = carved). Use at most 4 font families in total, all free to bundle (Google Fonts). UI and reading text: a clean modern sans. Justify each font in one line.

**Hard rules**
- Must not look generic or AI-templated: no default purple gradients, no glossy glass cards.
- Playful but not childish. Rewards are gentle: no streak loss, no lives, no guilt, no timers.
- Android, 48 dp tap targets, AA contrast (use scrims over illustrations), survives large system text.

**Deliver**
1. Dark and light palettes as named roles with hex values (background, surface, text, muted text, accent, per-poster tint rule, success, error). Right/wrong must also differ by icon, not colour only.
2. Type system with sizes and line heights.
3. Spacing, radii, elevation.
4. Illustration style guide in a few lines, with 4 sample posters (Roman history, French Revolution, WW2, Ancient Egypt) each in its own title lettering.
5. Components: poster card 2:3, hero banner, title bottom sheet, match-percentage badge ("87% match"), thumbs rating (up / okay / down), Add-to-study-list button (idle and Added), progress bar, lesson card, quiz answer button (idle, right, wrong), chat bubbles (user, assistant, "From lesson 4" tag), full-screen feed card 9:16, dashboard tiles, bottom navigation (Home, Library, Feed, Study) plus a contextual bottom bar inside a topic (Lessons, Chat, Quiz).
6. Motion notes: poster row parallax, Added pop, match % count-up, tile pop, answer bounce, finish-celebration confetti (gentle).
7. Short style summary and token table for a developer.

---

## Prompt 2a: Start and Home

**Paste from here**

Using the approved system, design these in dark and light.

1. **Splash:** animated Roman engraved-M roundel on the dark background, about 1.5 seconds.
2. **Onboarding, 5 screens, skippable, one idea each, full of surprise:**
   - (1) **Guess the year:** a striking illustration of a historical scene; three year buttons; show the reveal state (correct and wrong) with a one-line fact and a playful reaction.
   - (2) **Mystery card:** a sealed card on screen; tap it and it flips to reveal a surprising fact with its own illustration.
   - (3) **Pick what pulls you:** a grid of **illustrated image tiles** (not text chips) for these topics (scrollable, show about 12): Roman history, Ancient Greece, Ancient Egypt, Ancient India, Vikings, Mongol Empire, Renaissance, Ottoman Empire, Black Death, Sikh history, Maratha Empire, Rajput history, Indian independence movement, Green Revolution, Industrial Revolution, American Revolution, French Revolution, Napoleon, Russian Revolution, British Empire, American Civil War, WW1, WW2, Cold War, Space history, Great Depression, Dotcom bubble, 2008 housing crisis; plus a few people tiles (Alexander the Great, Cleopatra, Shivaji, Socrates). Each tile pops on tap. Show selected state and a "pick at least 3" hint.
   - (4) **Your first matches:** three posters with a match percentage counting up from 0 (for example 94%, 88%, 81%) and an "Add to study list" button on each.
   - (5) **Theme and text size:** dark / light preview plus one text-size slider, then a "Start exploring" button.
3. **Home / dashboard:** greeting, a continue-studying card (resume last lesson with progress), study-list progress rows, a "For you" row of posters with match %, a quiz scores row (with an empty state), and an On This Day card. It must feel like a streaming home screen, not a report.

Write all copy by hand in a friendly, short voice. No marketing language. No login or profile screens exist.

---

## Prompt 2b: Library, Title sheet, Study

**Paste from here**

Design in dark and light:

1. **Library:** a Netflix-style screen: hero banner for a featured topic with a play-style button, then horizontal poster rows: "For you", "Ancient", "India", "Revolutions", "Wars and space", "Money and crashes", and a **"Think Like..." row of portrait posters** (Alexander the Great, Cleopatra, Julius Caesar, Chhatrapati Shivaji Maharaj, Maharaja Ranjit Singh, Socrates, Chanakya) in a distinct poster format from topic posters. Each poster shows the illustration, the topic's own title lettering, and a match % badge. Show 12 different posters with 12 different title treatments.
2. **Title bottom sheet** (opens on poster tap): big illustration, styled title, 2 to 3 line brief, match % with a short reason ("because you liked Roman history"), lessons count and read time, thumbs rating with selected states, a large **Add to study list** button and its **Added** state, and a Start / Continue button.
3. **Person sheet** (opens from a Think Like... poster): portrait illustration, name lettering, era, one-line headline, 3 to 5 trait cards, "What they changed", "Odds they beat" (for a leader) or core ideas and "Use it today" (for a thinker), match %, rating, Add to study list.
4. **Study list:** the added topics with progress bars, swipe-to-remove, and an empty state with an illustration and one action.
5. Show the **rate-it moment**: thumbs tapped, and the match % on other posters updating.

---

## Prompt 2c: Learning screens

**Paste from here**

Design in dark and light:

1. **Reader:** lesson text (about 400 words) in a comfortable sans, one illustration, lesson progress, read-aloud bar, previous / next, and a bottom bar with Lessons, **Chat**, Quiz. Include the finished-topic celebration (gentle confetti) that offers the quiz. It must NOT look like a news article: short paragraphs, big headings, plenty of space and images.
2. **Chat (locked to the open topic):** header showing the topic title; suggested questions ("Why did the Republic fall?"); user and assistant bubbles; assistant answer with a "From lesson 4" tag; the off-topic refusal ("I only know about the Roman Empire."); a "Chat is resting, back tomorrow" state; an offline state.
3. **Quiz (Duolingo-style, gentle):** question screen ("2 of 6"), big answer buttons, right and wrong feedback with a one-line explanation and Next, then a result screen with score and "Review lessons you missed" plus "Try 6 new questions". No timer, no streak, no lives.
4. **Feed (TikTok-style):** full-screen vertical card with the illustration, one short fact, topic tag, and buttons: Go deeper, Save, thumbs. Show 3 cards with different topics.
5. **Settings:** theme, text size, voice and speed, clear my data, about, credits.

Write six sample quiz questions about Roman history, plain and factual.

---

## Prompt 3: Logo

**Paste from here**

Design the logo for **Maximus** (the name may change, so the letter must be swappable). Three directions. A (preferred): an engraved letter M inside a stamp or roundel, like a Roman coin or seal, simplified to read at 48 px. B and C: your own, clearly different, one-line rationale each. No laurel wreaths, helmets, columns or eagles. Show each on dark and light, as an Android adaptive icon (circle and squircle masks), as a one-colour mark, and at 48 px and 24 px. Match the bronze/gold accent. Report which one still reads at 24 px.

---

## Prompt 4: Fix-it

**Paste from here**

Screen: [name]. Fix: [1], [2]. Keep everything else. Then check the screen: does it look like a news or textbook app anywhere; are images big and colourful; is there less than about 60 words of text visible at once outside the reader; do right and wrong differ by icon; does it work at the largest text size. List anything that still fails.
