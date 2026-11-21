# Maximus — Inspiration Analysis (Paladin)

Source: 26 screenshots of **Paladin** (a history learning app made by the Deepstash team), taken 21 Nov 2026.
Purpose: decide what Maximus borrows, what it avoids, and what is missing from the references.

## 1. Key finding

Paladin is a **gamified history course** (stories, chapters, quizzes, lives), not a feed. Maximus is a **card feed with depth on demand**. They share a subject, not a structure.

- Only one Paladin pattern maps directly to Maximus: the **story reader**, which is a model for "Go Deep".
- **There is no feed reference in this folder.** The main Maximus screen (the card scroll) has no inspiration yet.

## 2. What the screenshots show

### Home ("Stories" tab)
- Header: title, streak counter (flame), hearts counter, search icon.
- Promo banner at the top ("GTA VI week").
- **Paths** carousel: large coloured cards (Hundred Years' War 9 stories / 36 chapters, WWI 7/27, Seven Wonders 7/7, Early Roman Empire with a progress bar and Continue).
- **Dive Right Back In:** current character (Augustus), chapter pills I–VII ending in crossed swords, current chapter card.
- Rows of portrait cards: Most Popular, Disasters & Catastrophes, The Price of Progress, Icons of the 20th Century, each with "View Collection".
- Large hero blocks: "Trending Right Now" (Benjamin Franklin), "Early Access" (Great Gold Robbery, Pro-locked), "Must Watch / Video Stories".
- Upsell blocks: "What you're missing" (Unlimited Hearts), "The great power of Pro".
- A **Black Friday sale banner with a countdown is pinned over the bottom of every screen**.
- Bottom nav: Home, Highlights, Battle, Profile, plus an Apps button.

### Collections
- List view: square thumbnail, title, year (orange), region (orange caps), one-line hook. This is the cleanest screen in the set.
- "All Collections": stacked horizontal rows (The Roman World, The Hundred Years' War).

### Path detail
- Large coin/emblem image, title, tag, date range (27 BCE – 2nd century CE), progress bar, expandable description with MORE, counters (Chapters 1 of 54, Stories 0 of 11).
- **Story map:** a Duolingo-style winding path of isometric towers (chapters) and target icons (quizzes) with locked states and a bottom sheet (Quiz title + Locked / Continue).
- Character card: "Augustus — The First Citizen", a teaser line, "View character".

### Story reader (closest to "Go Deep")
- Full-bleed illustration on top, cream bottom sheet below.
- Short title ("The Master Plan"), two short paragraphs, bold keywords, a hook question at the end.
- Controls: segmented progress bar, back, settings, close, big Continue button, pause button (suggests audio narration), a "Deep Dive" badge.

### Quiz
- "Quiz Time" splash, true/false on an ornate navy card with laurel motif, multiple choice, instant feedback sheets (NOT REALLY! / AWESOME! / WONDERFUL!), lives, exit-confirm dialog.
- After a right answer, a fact card reveals the explanation.

## 3. What works (worth borrowing)

1. **Reader pattern:** image on top, short text blocks below, one tap to advance. Good model for Go Deep.
2. **Short-text discipline:** two or three sentences per screen, a bold keyword, and a closing question.
3. **Collection list row:** thumbnail, title, year, place, one-line hook. Reusable for topic lists and search results.
4. **Clear colour logic for state:** green correct, red wrong, orange for the active item.
5. **Hierarchy of curated sets** (collection → item) is a good idea for a later "series" feature.

## 4. Why it fails the museum/archive vibe

1. **AI-generated imagery:** uncanny faces, plastic skin, generic costumes. It reads as AI at a glance.
2. **No visual consistency:** painterly portraits, flat vector, 3D toy figures and a clay coin all appear in one app.
3. **Baked-in cartoon titles:** white serif text with a dark outline pasted over the artwork. It looks like a thumbnail, not a museum plate.
4. **Paper-cut wave shapes and saturated purple/orange gradients:** a game and kids' app mood, not scholarly.
5. **Duolingo mechanics:** hearts, streaks, lives, locked chapters, "Battle" tab. These push you to keep playing, which is the opposite of what Maximus is for.
6. **Monetisation clutter:** sale banner with countdown, Pro locks, upsell blocks. It breaks calm and focus.
7. **Round, friendly sans-serif plus emoji-like icons:** no sense of age, paper or archive.
8. **Mixed registers:** a GTA VI promo sitting above Roman history.

## 5. Implications for Maximus

| Decision | Direction |
|---|---|
| Imagery | Real archival material: paintings, engravings, maps, manuscripts, period photographs (Wikimedia Commons). This alone gives the museum feel, and it is consistent by nature of the source. |
| Image treatment | One treatment across all cards. Caption and credit under the image like a museum label. No text baked into images. |
| Text | Plain-text hierarchy: small label (era or place), title, fact. Date and place in a quiet accent colour, as in Paladin's list rows. |
| Colour | One brand colour on a warm paper-toned neutral. No gradients. |
| Go Deep | Reader modelled on Paladin's story reader, but built from Wikipedia text split into short sections. |
| Gamification | None in v1: no hearts, streaks, lives or battle. |
| Quizzes | Out of scope for v1. Possible later as an optional "test yourself" at the end of a Go Deep. |
| Monetisation UI | None. |

## 6. Constraint to be aware of

Paladin's content is **written and illustrated by its own team**: short, hooky text and bespoke art. Maximus pulls from public APIs, so:
- Card text will be plainer than Paladin's. Hook quality has to come from **selection and layout**, not from rewriting.
- The reader's "hook question" pattern cannot be copied directly unless we write those lines ourselves or use trivia sources that already contain questions.

## 7. Museum and archive references

Reviewed from published descriptions and articles, **not from screenshots**. Typography and colour of these products are not described in the sources I could read, so those are not claimed here. Send screenshots if you want a visual review.

### Public Domain Review / Public Domain Image Archive
- **Image-first:** 10,000+ curated out-of-copyright images presented as standalone objects, separated from the essays they came from.
- **Three ways in:** a catalogue view (search and browse by theme, style, date), an **infinite view** that scrolls continuously and wraps around, and a **shuffle view** that shows random images at the press of a button.
- **Filters:** era, theme, style, colour, artist, century, tag. Built on detailed metadata.
- **Captions and rights:** each image carries a short source caption (title, date, creator) and a rights statement for both the original and the digital copy.
- **Take for Maximus:** metadata-rich, caption-first presentation; the idea that the image is the object; the infinite and shuffle views as models for an endless, calm feed.

### Rijksmuseum Collection Online
- **Image-first by design:** very large images; full-screen details of artworks double as navigation.
- **Minimal interface:** simple for casual visitors, deeper tools for professionals, which keeps the casual path uncluttered.
- **Stories layer:** the artworks are connected to stories behind them, which parallels our card → Go Deep step.
- **Personal collections** ("Gallery of Honour") exist, so saving favourites is an established pattern.
- **Scale:** 800,000+ high-resolution works.
- **Take for Maximus:** let the image carry the screen, keep chrome minimal, put the story one tap behind the image.

### Not reviewed
- **Google Arts & Culture:** I did not review it; it needs your screenshots.
- **Europeana:** a content source, not a design reference (free API, public-domain filter, CC0 metadata).

## 8. Decisions made (21 Nov 2026)

- **Feed base:** adapt Paladin's list row and reader pattern, with no separate feed reference.
- **Audio:** text-to-speech on Go Deep is in v1.
- **Collections:** browsable collections are in v1 alongside the feed.
- **Museum references reviewed:** Public Domain Review and Rijksmuseum.

## 9. Still open

1. Do you want a visual review of the Public Domain Image Archive or Rijksmuseum from screenshots? Their typography and colour are unconfirmed.
2. Is saving favourites (a personal collection, like Rijksmuseum's) in v1?
