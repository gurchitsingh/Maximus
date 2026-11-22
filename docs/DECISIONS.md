# DECISIONS (S3, 2026-11-22)

Non-obvious choices behind `docs/CONTRACTS.md`. Three lines each: the decision, why, and what we gave up. Owner decisions from DESIGN_SPEC section 12 (no accounts, v3 onboarding, TOPICS.md catalogue, public repo) are not repeated here. Open items are CONTRACTS section 13.

## D1. Chat replies are whole, not streamed
- **Decision:** `POST /v1/titles/{id}/chat` returns one JSON reply after the server has the complete answer.
- **Why:** The server must check the full answer before anyone sees it (canary leak, links, valid lesson numbers, length) and fail closed to the fixed refusal. Falling back from OpenRouter to Gemini mid-answer is clean only when nothing has been shown yet. Caps and resting stay plain HTTP errors.
- **Gave up:** Words appearing as they are written. The UI shows typing dots instead; answers are 1 to 4 sentences, so the wait is short.

## D2. `OWN` licence type for our own art
- **Decision:** The image licence enum is `PD | CC0 | CC BY | CC BY-SA | OWN`. `OWN` marks posters and portraits made for the app (AI-assisted), with credit line "Illustration made for Maximus" and no external source page.
- **Why:** Most of the 79 titles need poster art that Commons cannot supply in one style (DESIGN_SPEC 10.2). Every image, including ours, must flow through the same credit pipeline so the Credits screen is generated, not hand-kept.
- **Gave up:** A clean public licence for that art. The copyright status of AI-assisted images is unsettled, so we claim no CC licence for now (CONTRACTS Q7).

## D3. Sample sizes: 6 lessons and 10 questions for Roman history
- **Decision:** The Roman history sample has 6 lessons of about 400 words, 10 quiz questions and 8 feed facts. Shivaji and Chanakya have 1 lesson, 2 facts and every person field filled. All text is marked SAMPLE, status `draft`.
- **Why:** S3_PROMPT.md asked for 2 lessons and 3 questions, but the quiz needs 6 questions per attempt and a bank larger than 6 to test "no repeats until exhausted"; 6 lessons exercise the reader's segment bar, the lessons list, inline images and real reading-minute maths.
- **Gave up:** A tiny sample. The Roman file is about 400 lines, and its text is placeholder prose that must never be published (gate G9 blocks any `SAMPLE` text).

## D4. The whole quiz bank ships inside the title
- **Decision:** The title payload carries every served question with its answer; the device picks 6 per attempt.
- **Why:** The quiz must work offline after the first open, grading is on the device anyway (BRIEF), and "no repeats until the bank is exhausted" needs device memory, not server state.
- **Gave up:** Hiding answers from a determined user. This is a study app with no leaderboard, so it does not matter.

## D5. One title payload, no lesson or quiz endpoints
- **Decision:** `GET /v1/titles/{id}` returns the title with lessons, images, quiz, facts, person and sources. The catalogue item is the same object without the detail fields.
- **Why:** One request makes a title fully offline; one shape serves the DB import, the API and the device cache; it is about 100 KB per title.
- **Gave up:** Lazy loading of single lessons. Opening a title the first time costs one larger download.

## D6. Child ids are `<title_id>.<letter><nn>`
- **Decision:** Lessons `.l01`, quiz `.q001`, facts `.f001`, images `.i01`, sources `.s01`, all prefixed by the title slug and stable once published.
- **Why:** Device progress, quiz seen-state and feed reactions are keyed by them and must survive content updates; ids read well in logs and review notes; a prefix makes cross-title mix-ups visible to the validator.
- **Gave up:** Renaming freely. Reordering lessons keeps old ids, so `index` and the id number can drift apart.

## D7. One `sources[]` list per title; ≥2 sources per interpretive claim to publish
- **Decision:** Each title has one source list. `role: text` sources (with a licence) are where lesson text comes from; `role: citation` sources (with a confidence) back claims. Lessons and person claims point to them by id. Publishing needs every person claim to cite ≥2 distinct citation sources, not all low-confidence.
- **Why:** One list feeds per-lesson attribution, the Credits screen and the review report. Traits, "odds beaten" and "use it today" are interpretation (TOPICS.md), so they need more than one source.
- **Gave up:** Per-sentence citations inside lesson text, and fast publishing of people titles.

## D8. Caps, resting and rate limits are errors, in one error shape
- **Decision:** `429 chat_daily_cap`, `503 chat_resting`, `429 rate_limited`, all with the body `{error: {code, message, retry_after_s, details}}` and a `Retry-After` header.
- **Why:** A 200 means the server answered. The app maps `code` to its own copy and timers, and one handler covers every endpoint.
- **Gave up:** Showing the server's message text to users. Copy lives in the app.

## D9. `/v1/feed` is plain; personal weighting happens on the device
- **Decision:** The server takes `title_ids`, `limit` and `seed` and returns a round-robin of shuffled facts. The device reads cached titles' facts locally and uses the endpoint only for "try this" cards from uncached titles, weighting everything by match %.
- **Why:** Match % lives only on the phone (no accounts), so the server cannot weight. A seeded, deterministic endpoint is trivial to test.
- **Gave up:** Server-side tuning of the feed mix without an app update.

## D10. Fonts are credited from a bundled file, not from the API
- **Decision:** `app/assets/credits/fonts.json` (schema `credits.schema.json#/$defs/font_list`) lists the four OFL fonts; `/v1/credits` covers content only.
- **Why:** Fonts ship inside the app, so their credits must work offline and on first launch; they change only with an app release.
- **Gave up:** One endpoint holding every credit.

## D11. A fixed list of 17 themes; match tags are group + era + region + themes
- **Decision:** `themes` comes from a closed enum (war, politics, empire, religion, ideas, economy, science-tech, revolution, culture, exploration, leadership, strategy, law, independence, disease, trade, society), 1 to 6 per title.
- **Why:** Free-text tags drift ("wars" vs "war") and break similarity; 17 values cover the 79 titles; the schema rejects typos.
- **Gave up:** Fine-grained tags (for example "navy", "trade routes"). Adding a theme needs a schema change.

## D12. Match % = Jaccard-weighted signals squashed into 40 to 99
- **Decision:** `raw = Σ w(s) × Jaccard(tags(t), tags(s))`, `pct = clamp(round(50 + 49 × raw / (4 + |raw|)), 40, 99)`, with fixed signal weights. No signals at all means no badges (rank order).
- **Why:** It needs no ML, no per-user normalisation and no maximum, explains itself ("because you liked X"), and costs under 1 ms for 80 titles. Reference code and test vectors (`docs/examples/match-cases.json`) make the Dart port checkable.
- **Gave up:** Learning from behaviour beyond the listed signals, and numbers that look as confident as the prototype's 94% on day one (they start near 55 to 76).

## D13. Samples are drafts; production serves only published titles and reviewed items
- **Decision:** All samples are `status: draft`. `SERVE_DRAFTS=true` (dev only) serves everything; otherwise only `published` titles and, inside them, only `reviewed` questions and facts are served.
- **Why:** Placeholder text can never leak to users, and a title can be published while part of its quiz bank is still being checked.
- **Gave up:** Counts in a title file (`quiz_count`) can differ from what is served; the server computes them.

## D14. Reading minutes = max(1, ceil(words / 200))
- **Decision:** Per lesson, words counted without image lines and markup; the title total is the sum.
- **Why:** One rule shared by the importer, the validator and the UI. 200 words a minute is a gentle pace for study reading.
- **Gave up:** The design's placeholder figures ("8 lessons · 48 min"); real titles will show lower totals.

## D15. Feed facts are at most 40 words and 280 characters
- **Decision:** Both limits, enforced by the schema pattern and length.
- **Why:** 40 words is the Gemini brief and fits the 9:16 card; 280 characters is the old BACKEND rule. Both together stop long-word facts overflowing.
- **Gave up:** Two-sentence facts with context.

## D16. ETag = hash of the canonical body; no pagination
- **Decision:** Every cacheable GET has `ETag` = the first 16 hex characters of sha256 over the canonical JSON body (without `generated_at`), and `If-None-Match` returns 304. No pagination anywhere.
- **Why:** It is correct by construction (any served change changes the tag) and needs no bookkeeping. 80 titles fit in one catalogue response.
- **Gave up:** Range or partial sync. Revisit only beyond a few hundred titles.

## D17. Person fields are one JSON column
- **Decision:** `titles.person` holds the whole person object; there is no `people` table.
- **Why:** It is always read and written whole, nothing queries inside it, and it matches the payload exactly.
- **Gave up:** SQL queries over traits or odds (not needed in V1).

## D18. "Clear my data" keeps the content cache and makes a new install id
- **Decision:** It deletes every personal table and setting, re-seeds defaults with a fresh install id, and keeps `cached_titles` and `cached_docs`.
- **Why:** The design promises "Topics, scores, settings" are cleared; cached content is not personal and keeps the app usable offline after a reset. A new install id unlinks old chat usage.
- **Gave up:** Resetting also resets that install's daily chat count (the per-IP burst limit and the global cap still apply).

## D19. Chat usage is stored as salted hashes, with a global daily cap
- **Decision:** `chat_usage(day, sha256(salt + install_id), count)`, kept 2 days; `CHAT_DAILY_CAP` per install (20) and `CHAT_GLOBAL_DAILY_CAP` server-wide (200).
- **Why:** No personal data on the server; free LLM tiers have account-wide daily limits that one heavy user could exhaust.
- **Gave up:** Usage analytics per user.

## D20. Chat refusals are server-built and the output check fails closed
- **Decision:** The model answers `OUT_OF_SCOPE` or ends with `LESSONS: n`; anything malformed, leaking the canary or containing links becomes the fixed reply "I only know about {name}."
- **Why:** Free models obey "stay on topic" poorly (APP_DETAILS 8); a fixed sentence cannot be manipulated, and failing closed never shows unchecked text.
- **Gave up:** Some valid answers that the model formats badly will show as refusals.

## D21. The app parses its own markdown subset
- **Decision:** Lesson bodies use exactly: paragraphs, `##` sub-heads, `-` bullets, `>` quotes, `![](image_id)` lines, `*italic*`, `**bold**`. A small in-app parser renders them; the validator rejects anything else.
- **Why:** Full control over reader typography and text size, no package dependency, and read-aloud can strip the same constructs.
- **Gave up:** Links, tables and numbered lists inside lessons.

## D22. Device settings live in drift, not shared_preferences
- **Decision:** One drift `settings` key-value table holds theme, text size, voice and the install id.
- **Why:** One store, one migration path, and "Clear my data" is a single transaction.
- **Gave up:** Synchronous reads at startup; the theme loads with the database (fast enough behind the 1.5 s splash).

## D23. Example payloads are generated from the samples and cross-checked
- **Decision:** `docs/examples/catalogue.json`, `feed.json` and `credits.json` are exactly what the contract rules build from the 3 samples; `tools/validate_samples.py` rebuilds and compares them.
- **Why:** S10 can compare its responses to the examples (ignoring `generated_at`), and S5 to S9 get fake data that is guaranteed to agree with the samples.
- **Gave up:** Hand-editing those three files. Change a sample, then regenerate them with the validator's builder functions.

## D24. Chat history and suggestions are not stored or authored
- **Decision:** Chat messages live in memory and clear when the title closes; suggestion chips come from on-device templates.
- **Why:** Less personal data on the phone, no new schema field, and no extra content to write for 79 titles.
- **Gave up:** Resuming a conversation later, and hand-picked questions per title (CONTRACTS Q6).

## D25. Daily caps reset at 00:00 UTC
- **Decision:** Chat caps and `retry_after_s` use the server's UTC day.
- **Why:** One clock, no device time-zone input, simple tests.
- **Gave up:** "Back tomorrow" matching local midnight (India resets at 05:30 local).

## D26. Line endings are normalised by `.gitattributes` (`* text=auto`)
- **Decision:** Git stores text files with LF and checks them out per platform; binaries are auto-detected.
- **Why:** On Windows with `core.autocrlf=true`, files written by different tools showed whole-file CRLF diffs.
- **Gave up:** Nothing. The index was already LF, so renormalising changed no content.

## D27. Downscaled Commons images say "resized" in the credit line
- **Decision:** The ingest stores Commons thumbnails 1600 px wide (SVG rendered to PNG). Such images get `modified: true` and the credit suffix `· resized`; `· cropped` stays for crops.
- **Why:** CONTRACTS 2.3 counts resizing as a modification, and "cropped" would be untrue for a plain resize.
- **Gave up:** Storing originals (often 5 to 30 MB, too heavy for phones).

## D28. Lessons come from curated page leads, not whole articles
- **Decision:** `ingest/seed.json` lists, per title, a chronological series of Wikipedia pages; each entry becomes one lesson from the page lead plus, optionally, one section shortened to whole sentences (`max_words`). Leaving `sections` out still splits a whole article on its section boundaries.
- **Why:** Leads are Wikipedia's own summaries (about 150 to 550 words), so lessons land near 400 words, read in order and need little trimming. Whole articles (Ancient Rome is about 15,000 words) would make 30+ lessons.
- **Gave up:** Covering every detail of each article; titles are shortened adaptations (the attribution says "Shortened").

## D29. Seed beats Wikidata; Wikidata never blocks a run
- **Decision:** Period, subtitle, brief and hero come from the seed when given, else Wikidata (P580/P571/P569, P582/P576/P570, P18), else the article. Differences between seed and Wikidata are printed as warnings. A Wikidata failure (it often answers `maxlag`) becomes a warning.
- **Why:** Editorial values are checked by a person; Wikidata only fills gaps and flags disagreements.
- **Gave up:** Fully automatic periods.

## D30. Re-ingesting a title keeps what other tools own
- **Decision:** `ingest.cli wiki` rewrites lessons, images and `role: text` sources, keeps `quiz`, `feed_facts`, `person`, `role: citation` sources and the poster image, and reuses source ids by URL and image ids by Commons page. It refuses to overwrite a `reviewed` or `published` file without `--force`. Media file names carry a hash of the source URL.
- **Why:** S13 merges quiz/feed into the same file; ids must stay stable (P1); a changed picture must never hide behind an old file name or app cache entry.
- **Gave up:** Nothing in V1.

