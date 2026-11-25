# Store listing draft

Facts about Play limits come from https://support.google.com/googleplay/android-developer/answer/9866151 and
https://support.google.com/googleplay/android-developer/answer/9859655, both read on 2026-11-25 (neither page
shows a "last updated" date). Nothing here is final: the owner decides names and every claim. Counts of titles
(28 topics, 51 people) must match what actually ships; the launch subset is still an open item (APP_DETAILS 9).

## App name candidates (the final name is open; none is chosen)

| Candidate | Note |
|---|---|
| Maximus | Current working title and Android label. UNVERIFIED: not checked for name clashes on Play or trademark databases |
| Maximus: Study History | Says what it is. UNVERIFIED: Play's app-name length limit is not on the pages read (commonly 30 characters; UNVERIFIED), this one is 22 |
| TODO more candidates | The owner may add; do a Play search and a trademark check on each before choosing |

The package name is `com.gurchit.maximus.maximus` (`app/android/app/build.gradle.kts`). Play says package names
are unique and permanent and cannot be deleted or reused (answer 113469, read 2026-11-25), so decide whether to
keep it **before the first upload**. TODO owner decision.

## Short description (80 characters maximum, per the graphic-assets page)

1. `Study history in short lessons, with quizzes and a fact feed. Works offline.` (76)
2. `Learn history in short lessons. Quiz yourself, scroll facts, ask the chat.` (74)
3. `A history study app: lessons, quizzes, a fact feed and a topic chat.` (68)

Option 1 claims offline use; "works offline" is true for opened lessons, quizzes, feed and study list, not for
sign-in or chat. Keep the full description's offline paragraph.

## Full description (about 1,700 characters; Play's maximum is UNVERIFIED, not on the pages read)

```
This is a study app for history. It is not a news app and does not replace a teacher or a textbook.

Pick from topics such as Roman history, the French Revolution, the World Wars and the Space Race, plus a "Think Like..." section of profiles of leaders and thinkers. Add titles to your study list and read them as short lessons of about 400 words, with images and credits.

What you can do:
- Read lessons, with read-aloud from your device.
- Take a 6-question quiz per title and see what you missed.
- Scroll a feed of short facts from your study-list topics, and save or like them.
- Rate titles and get a match score worked out on your phone.
- Ask the chat about the title you are reading. It answers from that title's lessons and says so when they do not cover the question. Answers are written by AI and can be wrong, so check important facts.
- See a fact of the day and what happened on this day.

Offline use: lessons you have opened, quizzes, the feed and your study list work without a connection. Signing in, syncing and chat need the internet.

Accounts: sign in with Google, or with an email and a password. Your study list, ratings, progress, quiz results, saves and settings are backed up to our server so they follow you to a new phone. Chat messages are kept 5 days, then deleted. You can delete your account and its data in the app (Settings, Delete my account) or on our web page. No ads, and we do not sell your data.

History includes war, plague, slavery and mass killings. Lessons describe these events as their sources do.

Lesson text and images come mainly from Wikipedia and Wikimedia Commons under open licences (CC BY-SA and others). Credits are in the app.
```

Check before use: each claim above against the shipped build (read-aloud, fact of the day and On This Day depend on
what is built at launch; "lessons you have opened work offline" depends on the cache behaviour, UNVERIFIED here).

## Category and tags

- Category: **Education** (app type: App, not Game). UNVERIFIED: confirm the category list in Play Console.
- Tags: Play Console offers a fixed tag list per category; the number allowed and the list are UNVERIFIED. Pick
  from tags like history, education, study, quiz, reference if offered. Do not choose tags that are not true.
- Contact details (Console): email (public) TODO, website optional TODO, privacy policy URL
  `https://maximus-api.onrender.com/privacy` (TODO final), see `LAUNCH_CHECKLIST.md`.
- Ads: **No ads** (true per code). In-app purchases: none.
- Target audience: owner decision, see PRIVACY_POLICY "Children". The content-rating page says apps with children in the target audience must follow the Families policy.

## Content rating questionnaire (IARC, filled in the Console under App content)

The Play page says ratings come from the questionnaire answers and that misrepresenting content can lead to
removal or suspension. The exact question list is not on the page I read, so the wording below is UNVERIFIED:
re-read each question in the Console and answer by the facts here. **Answer honestly even where it raises the
rating.**

| Topic the questionnaire asks about | Honest answer for this app | Flag |
|---|---|---|
| Violence | **Yes, depictive of real events.** Lessons cover wars, battles, executions, massacres, the plague | **FLAG:** realistic historical violence in text and some images (Wikimedia photos and paintings may show the dead or weapons; review the shipped images) |
| Genocide-adjacent and mass atrocity | **Declare it.** Topics such as the World Wars may mention the Holocaust and other mass killings; the content is educational text from Wikipedia | **FLAG:** answer as violence involving real people; do not select "no" because it is history |
| Blood and gore | Possible in some historical images. TODO: check the shipped images | **FLAG** |
| Sexual content or nudity | Probably none in text; classical art on Wikimedia can include nudity. TODO: check the shipped images | **FLAG** |
| Profanity | None written by us; quotations in lessons may contain historical slurs. TODO: scan the lesson text | **FLAG** |
| Drugs, alcohol, tobacco | Historical mentions only (for example the opium trade). Answer per the form's wording | |
| Gambling | Financial crashes are discussed; no gambling feature. No | |
| Fear or horror | Disease and war topics are described factually, not as entertainment | |
| Discrimination, hate | Lessons describe racism, slavery and persecution historically. TODO: re-read the form's wording | **FLAG** |
| User interaction | The chat is between one user and an AI. Users cannot message each other and cannot share content with other users. Answer whether it "shares user-generated content" and "interacts" per the form; the chat is the only free-text input. Declare that AI answers can be wrong | **FLAG:** AI-generated text; the server blocks off-topic and unsafe output but this is not a guarantee |
| Shares location, digital purchases, unrestricted web | No location; no purchases; no browser in the app (it opens policy links in the system browser) | |

Expected result: some rating above the lowest because of real historical violence. TODO: record the rating the
Console assigns here, and make sure the target audience declaration is consistent with it.

## Screenshots to capture (phone, 8)

Rules (graphic-assets page, 2026-11-25): 2 to 8 phone screenshots, PNG or JPEG (24-bit, no alpha), each side
between 320 px and 3,840 px, up to 8 MB, longest side at most 2.3 times the shortest. At least four at 1080 px
minimum (9:16 portrait at least 1080 x 1920) is highly recommended for recommendation formats.

Use a **dark and a light** mix, signed in to a test account with real-looking data, no personal email visible.

1. Home: continue studying, study-list progress, fact of the day.
2. Library: poster rows with the study list under the hero.
3. Title detail sheet: brief, match percentage, rate control, "Add to study list".
4. Reader: a lesson with an image and its credit line.
5. Quiz: a question and the feedback after answering.
6. Feed: a card with one fact and "Go deeper".
7. Chat: a question, an answer citing a lesson, and one polite off-topic refusal.
8. Settings: account section showing sign out, Delete my account, privacy policy, and "Chats are kept 5 days".

Take them on an emulator or phone at 1080 x 1920 or higher (see the emulator notes in project memory). Do not use
the sign-in screens with a real email. Check every image's licence and that no real person's data shows.

## Graphic assets

| Asset | Requirement (page above, 2026-11-25) | Status |
|---|---|---|
| App icon | 512 x 512 px, 32-bit PNG with alpha, up to 1,024 KB, no badges or ranking text | TODO: make from the logo (see `docs/LOGO_PROMPT.md`) |
| Feature graphic | 1024 x 500 px, JPEG or 24-bit PNG (no alpha); required to publish | TODO |
| Phone screenshots | as above | TODO |
| Promo video | optional (YouTube URL) | skip |
| Tablet / Wear / TV | not required for a phone app | skip; UNVERIFIED whether Play asks for tablet screenshots for tablet visibility |

Posters and logos made with Claude Design: TODO owner confirms there is no licence problem with using them as
store graphics. Any Wikimedia image used in screenshots must carry its credit somewhere in the listing or app.
