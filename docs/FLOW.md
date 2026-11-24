# FLOW: screens and what each button does (v3)

# V3 CHANGES (24 Nov 2026) - read first

These override anything below that conflicts. Source: Claude Design export (Maximus v3 All Pages and v4).

- **Accounts required.** Flow starts: Splash, Sign in (or Create account), then onboarding. No guest mode.
- **Bottom nav: Home, Library, Feed, Settings.** The **study list is inside Library**, the first section under the hero. No separate Study tab. Chat button still appears only inside an open title.
- **Onboarding order (replaces the old five screens):** theme and text size, interests by era or region (3 to 5 topics), favourite leaders (1 to 3), your first matches, Home. Skippable parts per design.
- **Home for a new user:** "Your picks" replaces Continue studying; a full-width quiz tile sits over the poster of a topic with Begin and Pick another topic.
- **Fact of the day:** compact Home card above On This Day, with thumbnail, date and one fact under 25 words, from a bundled list by date. Works offline.
- **Posters:** day version in light theme, evening version in dark. Roman Empire and Ancient Egypt are redrawn pairs; others use one drawing with a day wash or an evening dusk wash; WW1, WW2, Cold War and American Civil War are fixed.
- **Settings:** profile, taste, theme, text size, voice, clear my data, sign out, delete my account, credits, privacy policy.
- **Chat history** is saved to the account.

---

## 1. Splash
Logo (split-disc mark) animates, about 1.5 s, then Sign in (first run or signed out) or Home.

## 1b. Sign in and Create account
Google button, or email and password. Create account asks email and password, then verifies the email. Forgot password. Required before anything else.

## 2. Onboarding (first run only, skippable parts)
1. **Theme and text size:** dark (default) or light, one slider.
2. **What are you into?** Interests by era, then by region; pick 3 to 5 topics. Each tile pops. Seeds match %.
3. **Favourite leader:** pick 1 to 3 from the Think Like... people.
4. **Your first matches:** 3 posters with match % counting up, plus "Add to study list".
Then Home.

## 3. Home (dashboard)
- Greeting + continue-studying card (resume last lesson), or "Your picks" and the quiz tile for a new user.
- Study list progress (small rows with bars).
- Quiz scores row (once quizzes exist).
- "For you" row: top match % titles you have not added.
- **Fact of the day** card.
- On This Day card (live, daily).
Tap anything: opens the title or lesson.

## 4. Library
Netflix-style: hero title at top, then **Your study list** (first section), then horizontal rows (For you, Ancient and medieval, India, Revolutions and empires, Wars and space, Money and crashes, Because you liked X) and a **Think Like...** row of portrait posters (people). Empty study list shows a picture and a link to browse.
Poster: topic picture + title in that topic's own style + match % badge.
Tap poster: **Title sheet**.

### Title sheet
Big picture, styled title, 2 to 3 line brief, match %, lesson count and read time, rate control (thumbs), **Add to study list** (toggles to "Added"), **Start / Continue**.
Rate: tap thumb, instant, updates match % across the app.

### Person sheet (Think Like... titles) - DESIGN NOT DONE YET
Portrait illustration, name in its own lettering, era and place, one-line headline, the 3 to 5 traits as tappable cards, "What they changed" and (leaders) "Odds they beat", or (thinkers) core ideas and "Use it today". Same match %, rating and Add to study list as topics.

## 5. Reader
Lesson text, images with credit, read-aloud, previous/next lesson, progress bar. Finish all lessons: celebrate (gentle), offer the quiz.
Bottom bar: Lessons (list), **Chat**, Quiz.

## 6. Chat (inside a title)
Chat bubbles, suggested questions. Header shows the title it is locked to. Off-topic: "I only know about <title>." Answers show a small "From lesson 4" tag that jumps to the lesson. Daily cap reached: "Chat is resting, back tomorrow." Offline: disabled with message. History is saved to your account and can be deleted.

## 7. Quiz
Per title. 6 random questions from the bank. One question per screen, big option buttons, instant right/wrong with a one-line explanation (icon and word, not only colour), summary at the end with the score and the questions missed. No timer, no streak.

## 8. Feed
Full-screen vertical cards: image, one short fact, title tag. Swipe up: next. Buttons: Go deeper (opens lesson), Save, thumbs. Only topics on your study list (plus a few "try this" cards from high-match titles).

## 9. Settings
Profile, taste, theme, text size, voice and speed, clear my data, sign out, delete my account, image and text credits (CC BY-SA 4.0 notice), privacy policy, version.

## 10. V2: Perspective mode (inside a title)
Pick country and period, then lens (rulers, middle/working, poor). Shows that group's story with an "interpretation" label.

## Rules
- Every screen works offline except Chat, On This Day and sign-in. Personal data syncs in the background when online.
- No notifications in V1.
- Empty states always have a picture and one action.
