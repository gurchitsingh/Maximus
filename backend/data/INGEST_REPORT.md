# Ingest report (content/topics-ingest)

Date: 2026-11-25. Scope: all 28 topics in `backend/ingest/seed.json`. Every title is `draft`. Nothing was published, reviewed or imported.

## What was done

- Inventory: all 28 topics already have a draft title file in `backend/data/titles/` with lessons and images (S11c ingested them, S11d fixed the split bug and re-ingested). **No topic was without lessons, so no `wiki`/`import` run changed any title file.**
- `python -m ingest.cli report --all`: publish gate (G1 to G10) **PASS for 28 of 28**. Quiz and feed items are 0 everywhere (S13 owns them), so the Quiz tab stays hidden (CONTRACTS 7.1) until 6 questions are reviewed.
- The rejected-image reasons are not stored in the title files, so `wiki --all --no-download --out <scratch dir outside the repo>` was run once to get them plus per-lesson word and image counts. It used the repo User-Agent, one request at a time, 1 s apart. The committed titles were not touched. All 28 gates PASS there too.
- Lesson counts from that fresh run equal the committed files for all 28 titles. Word totals differ slightly because Wikipedia was edited since S11c/S11d; the figures below are from the fresh run, so a real re-ingest now would change some text a little.
- No tooling bug was hit. The tool printed no split warnings and no empty sections. Wikidata was unavailable once (maxlag) for the Renaissance entry, so seed values were used there.

## Per topic

pages = Wikipedia pages fetched; words = total, then min-max per lesson; imgs = images kept in the title file (each PD, CC0, CC BY or CC BY-SA with author and credit); rej = images the tool rejected; no-img = lessons with no image; short = lessons under 250 words.

| topic | pages | lessons | words | min-max | imgs | hero | rej | no-img lessons | short lessons | gate |
|---|---|---|---|---|---|---|---|---|---|---|
| roman-history | 8 | 8 | 3394 | 201-558 | 8 | yes | 4 | 3 (l03, l04, l08) | l04 | PASS |
| french-revolution | 12 | 11 | 5543 | 338-569 | 18 | yes | 4 | 1 (l03) | - | PASS |
| space-history | 12 | 12 | 5462 | 294-579 | 19 | yes | 6 | 1 (l04) | - | PASS |
| ancient-greece | 10 | 11 | 4149 | 200-617 | 11 | yes | 1 | 2 (l06, l08) | l04, l07, l11 | PASS |
| ancient-egypt | 11 | 11 | 4406 | 219-543 | 14 | yes | 5 | 2 (l06, l07) | l02, l05 | PASS |
| ancient-india | 8 | 7 | 2712 | 218-548 | 10 | yes | 4 | 2 (l01, l02) | l02 | PASS |
| vikings | 10 | 6 | 2484 | 219-525 | 13 | yes | 1 | 0 (-) | l05 | PASS |
| mongol-empire | 9 | 8 | 3009 | 226-537 | 8 | yes | 19 | 2 (l01, l03) | l03, l06 | PASS |
| renaissance | 9 | 9 | 3163 | 239-492 | 9 | yes | 3 | 2 (l01, l02) | l03 | PASS |
| ottoman-empire | 10 | 9 | 3002 | 222-560 | 14 | yes | 6 | 2 (l03, l07) | l02, l04, l08 | PASS |
| black-death | 12 | 7 | 2916 | 308-532 | 12 | yes | 2 | 1 (l02) | - | PASS |
| sikh-history | 12 | 9 | 3270 | 299-489 | 20 | yes | 14 | 0 (-) | - | PASS |
| maratha-empire | 10 | 8 | 2850 | 279-446 | 8 | yes | 10 | 2 (l01, l04) | - | PASS |
| rajput-history | 10 | 6 | 2227 | 274-541 | 11 | yes | 7 | 0 (-) | - | PASS |
| indian-independence | 12 | 10 | 4989 | 355-624 | 11 | yes | 4 | 1 (l01) | - | PASS |
| green-revolution | 9 | 6 | 2632 | 303-614 | 9 | yes | 2 | 1 (l05) | - | PASS |
| industrial-revolution | 13 | 9 | 3128 | 204-452 | 15 | yes | 3 | 2 (l02, l09) | l08, l09 | PASS |
| american-revolution | 9 | 10 | 4105 | 143-592 | 9 | yes | 2 | 2 (l02, l03) | l10 | PASS |
| napoleon | 10 | 11 | 4213 | 225-564 | 13 | yes | 9 | 3 (l05, l06, l09) | l03, l09, l11 | PASS |
| russian-revolution | 10 | 10 | 4096 | 151-609 | 13 | yes | 16 | 2 (l02, l08) | l02, l04 | PASS |
| british-empire | 10 | 9 | 3122 | 223-431 | 8 | yes | 10 | 4 (l02, l03, l06, l09) | l06 | PASS |
| american-civil-war | 11 | 12 | 5059 | 213-662 | 18 | yes | 7 | 1 (l07) | l10 | PASS |
| ww1 | 12 | 11 | 5038 | 154-602 | 16 | yes | 3 | 2 (l05, l09) | l05 | PASS |
| ww2 | 12 | 12 | 6480 | 428-661 | 22 | yes | 3 | 1 (l03) | - | PASS |
| cold-war | 11 | 12 | 5491 | 235-604 | 20 | yes | 17 | 3 (l02, l04, l12) | l04 | PASS |
| great-depression | 10 | 10 | 4308 | 245-641 | 13 | yes | 2 | 3 (l07, l08, l10) | l08, l10 | PASS |
| dotcom-bubble | 11 | 6 | 2522 | 318-536 | 6 | yes | 9 | 2 (l03, l05) | - | PASS |
| housing-crisis | 12 | 9 | 3904 | 209-591 | 10 | yes | 3 | 3 (l03, l04, l09) | l06 | PASS |
| **total** | 295 | 259 | 107674 | | 358 | | 176 | | | 28/28 |

## Rejected images by reason (all topics)

| reason | count |
|---|---|
| blocked file name (logo, flag, icon, ...) | 83 |
| no English caption or description written by a person | 45 |
| too small | 27 |
| not a still image | 8 |
| CC licence but no author to credit | 5 |
| licence not allowed or unclear (No restrictions) | 3 |
| not on Wikimedia Commons | 3 |
| licence not allowed or unclear (GODL-India) | 1 |
| trademarked | 1 |

Licence-related rejections (licence not allowed or unclear, or a CC licence with no author to credit) total 8 across all topics. Most rejections are the file-name blocklist (flags, logos, icons) and images with no human-written caption.

Most rejections: mongol-empire 19, cold-war 17, russian-revolution 16, sikh-history 14, maratha-empire 10, british-empire 10.

## Kept images by licence

| topic | PD | CC0 | CC BY | CC BY-SA |
|---|---|---|---|---|
| roman-history | 0 | 0 | 0 | 8 |
| french-revolution | 16 | 0 | 0 | 2 |
| space-history | 14 | 1 | 0 | 4 |
| ancient-greece | 4 | 1 | 2 | 4 |
| ancient-egypt | 2 | 0 | 1 | 11 |
| ancient-india | 1 | 0 | 1 | 8 |
| vikings | 4 | 0 | 3 | 6 |
| mongol-empire | 4 | 0 | 2 | 2 |
| renaissance | 7 | 0 | 0 | 2 |
| ottoman-empire | 9 | 2 | 0 | 3 |
| black-death | 10 | 0 | 0 | 2 |
| sikh-history | 10 | 1 | 0 | 9 |
| maratha-empire | 8 | 0 | 0 | 0 |
| rajput-history | 6 | 0 | 1 | 4 |
| indian-independence | 6 | 1 | 0 | 4 |
| green-revolution | 4 | 0 | 3 | 2 |
| industrial-revolution | 9 | 0 | 1 | 5 |
| american-revolution | 8 | 0 | 0 | 1 |
| napoleon | 8 | 0 | 0 | 5 |
| russian-revolution | 13 | 0 | 0 | 0 |
| british-empire | 4 | 0 | 0 | 4 |
| american-civil-war | 16 | 1 | 1 | 0 |
| ww1 | 10 | 0 | 0 | 6 |
| ww2 | 15 | 1 | 0 | 6 |
| cold-war | 15 | 0 | 0 | 5 |
| great-depression | 10 | 2 | 0 | 1 |
| dotcom-bubble | 1 | 1 | 1 | 3 |
| housing-crisis | 2 | 4 | 1 | 3 |

## Seed vs Wikidata differences (tool warnings; the seed value was kept)

- ancient-greece: period_start: seed -800, Wikidata Q134178 says -3300 (seed kept; check it)
- ancient-greece: period_end: seed -146, Wikidata Q134178 says -1100 (seed kept; check it)
- ancient-india: period_end: seed 550, Wikidata Q62943 says -185 (seed kept; check it)
- renaissance: Wikidata Q4692 unavailable (https://www.wikidata.org/w/api.php: server lag (maxlag) after 4 tries); seed values only
- black-death: period_start: seed 1347, Wikidata Q42005 says 1346 (seed kept; check it)
- indian-independence: period_start: seed 1857, Wikidata Q12444025 says 1757 (seed kept; check it)
- green-revolution: period_start: seed 1960, Wikidata Q522837 says 1943 (seed kept; check it)
- industrial-revolution: period_end: seed 1840, Wikidata Q2269 says 1820 (seed kept; check it)
- napoleon: period_start: seed 1799, Wikidata Q517 says 1769 (seed kept; check it)
- napoleon: period_end: seed 1815, Wikidata Q517 says 1821 (seed kept; check it)
- russian-revolution: period_end: seed 1923, Wikidata Q184928 says 1907 (seed kept; check it)
- british-empire: period_start: seed 1600, Wikidata Q8680 says 1583 (seed kept; check it)
- cold-war: period_start: seed 1947, Wikidata Q8683 says 1945 (seed kept; check it)

Many are expected (the Wikidata item spans a wider period than our framing). A human should confirm the period fields for the ones above.

## Needs a human

No gate fails. These are quality judgements; no content was edited by hand.

**1. Fewest lessons (6):** `vikings` (10 pages), `rajput-history` (10 pages), `green-revolution` (9 pages), `dotcom-bubble` (11 pages). Short pages are merged by design (lessons under 200 words are combined). Check they read coherently and nothing important was folded away.

**2. Few images for the lesson count (3 or more lessons without an image, or fewer images than lessons):**
- `roman-history`: 8 images, 8 lessons, 3 lessons without an image (l03, l04, l08)
- `american-revolution`: 9 images, 10 lessons, 2 lessons without an image (l02, l03)
- `napoleon`: 13 images, 11 lessons, 3 lessons without an image (l05, l06, l09)
- `british-empire`: 8 images, 9 lessons, 4 lessons without an image (l02, l03, l06, l09)
- `cold-war`: 20 images, 12 lessons, 3 lessons without an image (l02, l04, l12)
- `great-depression`: 13 images, 10 lessons, 3 lessons without an image (l07, l08, l10)
- `housing-crisis`: 10 images, 9 lessons, 3 lessons without an image (l03, l04, l09)

Every title has a hero image. `dotcom-bubble` has the thinnest set (6 images, 9 rejected); modern topics have fewer public-domain images by nature.

**3. Short lessons (under 250 words), possible stub-like or odd splits:** `roman-history` l04; `ancient-greece` l04, l07, l11; `ancient-egypt` l02, l05; `ancient-india` l02; `vikings` l05; `mongol-empire` l03, l06; `renaissance` l03; `ottoman-empire` l02, l04, l08; `industrial-revolution` l08, l09; `american-revolution` l10; `napoleon` l03, l09, l11; `russian-revolution` l02, l04; `british-empire` l06; `american-civil-war` l10; `ww1` l05; `cold-war` l04; `great-depression` l08, l10; `housing-crisis` l06. Shortest: `american-revolution` l10, `russian-revolution` l02 and `ww1` l05 (about 150 words each).

**4. Long lessons (over 600 words):** `american-civil-war` (max 662), `ww2` (661), `great-depression` (641), `indian-independence` (624), `ancient-greece` (617), `green-revolution` (614), `russian-revolution` (609). Longer than the roughly 400-word target.

**5. Wrong-article risk:** none found by the tool. Spot check the pages swapped in S11c (Second Anglo-Sikh War, Third Anglo-Maratha War, German spring offensive, replacing disambiguation pages) and the S11d additions (Siege of Caffa, Persecution of Jews during the Black Death, Danse macabre, Spinning mule, Bessemer process, Cotton mill, Great Exhibition).

**6. Titles stay drafts.** Next human steps: read each whole title and run `review --title-reviewed`; merge quiz and feed drafts (S13).

## Proposed seed.json changes (not applied)

Suggestions only; `seed.json` was not edited. Check that each page title exists and is not a disambiguation page before adding.

- 6-lesson titles (`vikings`, `rajput-history`, `green-revolution`, `dotcom-bubble`): if 8 or more lessons are wanted, add one or two on-topic pages to each seed entry (for example a Mewar or Battle of Haldighati page for rajput-history, Norman Borlaug for green-revolution). The reviewer picks the pages.
- Titles with several image-less lessons (`british-empire`, `roman-history`, `napoleon`, `cold-war`, `great-depression`, `housing-crisis`): optional, name Commons files for those lessons in the seed. Lessons without images render as text.
- Long lessons (`american-civil-war`, `ww2`): optionally set `max_words` around 450 on the longest pages. S11d removed the old caps because of the split bug, so this is now a style choice.
