# DECISIONS (S3, 2026-11-22)

Non-obvious choices behind `docs/CONTRACTS.md`. Three lines each: the decision, why, and what we gave up. Owner decisions from DESIGN_SPEC section 12 (v3 onboarding, TOPICS.md catalogue, public repo) are not repeated here. **D34 to D48 (24 to 25 Nov 2026) add accounts, sync, Postgres, hosting and the v4 design; they supersede D24 and the "no accounts" rule. Items marked UNCONFIRMED are defaults awaiting the owner (D35, D37, the 30 days in D39, bundling in D42).** Open items are CONTRACTS section 13.

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

## D24. Chat history and suggestions are not stored or authored (history part superseded by D39, 2026-11-24)
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


## D31. Chat proxy (S14) implementation decisions (2026-11-22)
- **Decision:** (a) 2026-11-22: counters use the CONTRACTS 2.10 `chat_usage` table (new, migration 0002); the global cap is `SUM(count)` for the UTC day, with no second table. (b) 2026-11-22: `.env.example` keeps its pre-existing non-secret values and adds the chat names empty; empty env values fall back to the `config.py` defaults (`env_ignore_empty`). (c) 2026-11-22: history turns that match the injection pre-filter are dropped, not refused; the message itself gets the refusal. (d) 2026-11-22: `chat_usage` rows older than yesterday are purged on the first chat of each UTC day per process, not at startup. (e) 2026-11-22: caps are check-then-count; a race of 1 over the cap is accepted by the owner. (f) 2026-11-22: production must refuse to start with an empty `INSTALL_ID_SALT` (to build in the hosting step); model ids stay env defaults and the owner verifies them in the manual check.
- **Why:** Keeps the schema change to one new table, keeps local and test runs working without secrets, and avoids a second source of truth for the global cap.
- **Gave up:** Exact cap enforcement under concurrent requests (over by at most 1).


## D32. Quiz, feed and settings decisions (S7, S8, S9; 2026-11-23)
- **Decision:** (a) S7: no Quiz button on the title sheet (DESIGN_SPEC 7.10 has none); the quiz is entered from the Quiz tab and the finish celebration. One gentle confetti on a 5/6 or 6/6 result, not under reduced motion and not when a result is reopened; "Review lessons you missed" is hidden on 6/6. (b) S8: On This Day stays off Home until S12; `OnThisDayCard` is built and tested but not placed. The feed may fetch an uncached study-list title and skips it offline (CONTRACTS 7.2). (c) S9: Settings has Voice, Clear my data, About and Credits; "Licences" moved into Credits. The voice list hides network voices, shows at most 3 per English locale, Device default first. Clear my data keeps the content cache, makes a new install id and resets the theme. (d) Where a prompt and the docs disagreed, the docs won; the owner accepted the other conflicts.
- **Why:** Keeps one source of truth (DESIGN_SPEC, FLOW), avoids a result screen the spec does not draw, and keeps the voice picker short.
- **Gave up:** A quiz shortcut on the title sheet, On This Day on Home for now, and network voices.

## D33. Content review tooling (S13; 2026-11-23)
- **Decision:** `ingest.cli` has `merge`, `report`, `review`, `publish` and `people` (CONTRACTS 9.2). Rejected items are logged in `data/rejected/<id>.json` so merge never re-adds them and ids are not reused. `publish` needs a `reviewed` title and gate G1 to G9; `needs_check` items do not block it and are not served (G10). A draft `lesson_id` of null stays an error. Draft files (`data/drafts/*.json`) are gitignored. The person draft format (claims list `sources`, the tool assigns `source_ids`) is defined in CONTRACTS 9.2.
- **Why:** Reviewed content must be the only content served, and rejected questions must stay rejected across re-merges.
- **Gave up:** Restoring a rejected item automatically (edit the log by hand).


## D34. Accounts are required; there is no guest mode (2026-11-24)
- **Decision:** Every user signs in before onboarding. The server stores their data (D36). Confirmed by the owner. Supersedes the v1 rule "no accounts" (CONTRACTS P5, old DESIGN_SPEC 12).
- **Why:** Real users on a Play Store app need their study data to survive a lost phone and to span devices, and chat needs a per-account cap.
- **Gave up:** Instant start without a sign-in screen, and the "nothing personal on the server" privacy story. We now owe a privacy policy, the Data safety form, account deletion and security audits.

## D35. Google sign-in ships first, email and password second (2026-11-24) **UNCONFIRMED**
- **Decision:** Default only. S17 builds both sets of endpoints (CONTRACTS 14); S18 may release the Google screen first and the email screens one version later. Accounts link by verified email (14.3).
- **Why:** Google needs no password storage, reset mail or verification flow, so it is the smaller and safer first release. The design's sign-in screen also shows a "Continue with Apple" button: dropped, Android only.
- **Gave up:** Users without a Google account wait one release. **Owner: confirm or change the order.**

## D36. The server stores a fixed list of user data (2026-11-24)
- **Decision:** Ratings, study list, lesson progress, quiz results, feed saves and likes, onboarding picks, settings and chat history. Not stored: quiz "seen" cycle state, cached content, the install id.
- **Why:** That is everything that would hurt to lose, and nothing else. A short list is easy to disclose in the privacy policy and to delete.
- **Gave up:** Cross-device continuity of the quiz question cycle (it restarts per device).

## D37. User data lives in hosted Postgres, default Neon free tier (2026-11-24) **UNCONFIRMED**
- **Decision:** Production uses Postgres (default Neon free); SQLite stays for dev and tests. CONTRACTS 18 lists the pooling, migration and SSL rules; nothing is Neon-specific.
- **Why:** Render's free disk is wiped on redeploy, so SQLite would lose users' data.
- **Gave up:** A single-file database, and Neon's free-tier limits and cold starts. **Owner: confirm the host.** Because nothing is vendor-specific, switching later is a config change.

## D38. Offline-first sync, last write wins, server-assigned cursor (2026-11-24)
- **Decision:** One generic `user_records` table, per-record `updated_at` set on the device and a per-user `seq` set by the server (CONTRACTS 15). Conflicts: newer `updated_at` wins; at equal times a delete wins. Tombstones live 90 days. Push, then pull. "Clear my data" tombstones rows instead of deleting them.
- **Why:** Device clocks can be wrong, so they decide conflicts only; paging uses the server's `seq`, which cannot be wrong. One table and one endpoint pair keep S17 and S18 small.
- **Gave up:** Field-level merges (two devices editing one rating: the later edit wins whole), and exact conflict ordering when a phone's clock is far off. Acceptable for a study app.

## D39. Chat history is stored per account (2026-11-24) (retention changed to 5 days by D46)
- **Decision:** The server saves both turns of every successful chat, builds the model's context from the stored history (the request no longer sends `history` or `install_id`), and hard-deletes rows older than `CHAT_RETENTION_DAYS` (30 when written, now 5: D46). The user can delete one title's chat or all chats. Supersedes D24 and the "log failures, not conversations" rule.
- **Why:** The owner wants chat history saved to the account; server-built context removes a client-controlled input (injection surface) and saves bandwidth.
- **Gave up:** A "we store no conversations" privacy claim, and some server storage. Chat text is now personal data, so it is disclosed, deletable and in the security audits. The retention length is settled in D46.

## D40. The study list lives inside Library; four tabs (2026-11-24)
- **Decision:** Bottom nav is Home, Library, Feed, Settings. "Your study list" is the first section under the Library hero; an empty list shows a picture and a link to browse. The `/study` route redirects to `/library`.
- **Why:** It is how the Claude Design export draws it, and it saves a tab.
- **Gave up:** A dedicated Study screen and its quick access. The app's `study` feature folder merges into `library`.

## D41. Fact of the day is a bundled, date-picked list (2026-11-24)
- **Decision:** About 100 hand-written facts of at most 25 words in `assets/facts/facts.json`, picked by device-local date, no endpoint and no backend table (CONTRACTS 20). Each fact names a `title_id` for its thumbnail and tap target.
- **Why:** It must work offline, cost nothing to run and never show an AI-drafted fact. A bundled file needs no server work.
- **Gave up:** Changing facts without an app release (new facts arrive with updates; the list only grows at the end).

## D42. 79 flat SVG posters, bundled, day and evening (2026-11-24) **UNCONFIRMED (bundling)**
- **Decision:** One style, drawn in Claude Design: 28 topics and 51 people. Light theme shows day, dark shows evening. Three modes per title: `pair` (two drawings), `wash` (one drawing plus a theme overlay), `single` (CONTRACTS 21). Bundled in the app with `flutter_svg`; a manifest lists each title's mode.
- **Why:** Matches the v4 design, works offline, and replaces the per-title image dependency for posters. 19 of the 28 topic posters exist; 9 are missing and the 51 people posters are not started.
- **Gave up:** Updating art without an app release, and some app size (small, flat SVG). The design also drew 11 topics that are not in TOPICS.md (Mughal, Maya, Aztec, Inca, Byzantine, Persia, Samurai, Mali, Crusades, Ming, Zulu); they stay in the export, unused until the owner adds those topics.

## D43. The people section keeps the name "Think Like..." (2026-11-24)
- **Decision:** `people_row_label` stays "Think Like...". It is still a server string (CONTRACTS 3.2), so renaming needs no app release.
- **Why:** The owner chose it.
- **Gave up:** Nothing; the "section name" question left open in CONTRACTS 13 is closed.

## D44. The API runs on Render's free tier (2026-11-24)
- **Decision:** FastAPI on Render free, Postgres elsewhere (D37). Production refuses to start with an empty `JWT_SECRET` or `INSTALL_ID_SALT`. The app allows a long first-request timeout and shows a "Waking the server..." state (CONTRACTS 18).
- **Why:** Free, and enough for launch traffic.
- **Gave up:** Instant first requests (about 15 minutes idle puts it to sleep) and a persistent disk. **Open:** `backend/media/` images cannot live on that disk; the owner must pick object storage (or bundle more art) before the deploy session S22 (CONTRACTS 18, Q9).

## D45. Google sign-in removes an unverified password (2026-11-25)
- **Decision:** If an account has a password and Google reports the same address as verified, the first Google sign-in links the Google identity and removes the password (CONTRACTS 14.3). Since D48 no password account is ever verified, so this applies to every password account.
- **Why:** Without this, someone could sign up with an address that is not theirs and keep a working password; when the real owner later signed in with Google the accounts would be linked and the attacker could still sign in. Only the real owner can prove the address through Google.
- **Gave up:** A person who signed up by email, never verified it, and later uses Google with that address must use "Forgot password" to set a new password before email sign-in works again.

## D46. Chat history is kept 5 days, rolling per message (2026-11-25)
- **Decision:** `CHAT_RETENTION_DAYS` defaults to **5**, replacing the 30 days of D39. Expiry is rolling per message: each message is hard-deleted 5 days after its own `created_at`, so a long chat loses its oldest messages first instead of the whole chat expiring together. The daily purge and the lazy check on the first chat of each UTC day both apply it. The env var still overrides the default.
- **Why:** The owner confirmed a shorter window: less personal text held on the server, a smaller privacy-policy and breach surface, and enough history for the chat to feel continuous within a study week.
- **Gave up:** Chat older than 5 days is gone (no archive), and a returning user sees only recent turns. Backups made before a purge can still hold older messages until their own 28-day deletion (DEPLOY.md section 9).

## D47. The poster manifest holds objects, and the catalogue wins (2026-11-25)
- **Decision:** `app/assets/posters/manifest.json` maps each title id to an object `{mode, bg, tint, lettering, lines}`, not a bare mode string. `bg`, `tint`, `lettering` and `lines` are copied from `backend/data/titles`. Where the prototype differs, the catalogue wins.
- **Why:** The poster fallback tile and the lettering need bg, tint and lines even when the file is missing, and the app should not need the catalogue loaded to draw a poster.
- **Gave up:** Values live in two places (catalogue and manifest) and can drift; a future check should compare them.

## D48. No email verification; sign-up signs the user in (2026-11-25)
- **Decision:** Verify-email and resend-verification are removed (routes, web page, mail, `verify` token purpose, resend limiter). Create account asks email, password and confirm password (the match is checked in the app); a valid email and a passing password create the account and return tokens at once. Sign in takes email and password; every wrong credential gives "Wrong email or password". `users.email_verified` stays in the table but is unused and no longer in the `User` JSON. Kept: Google sign-in, forgot and reset password (needs an email provider such as Resend in production), Argon2, rate limits. Supersedes the verification parts of CONTRACTS 14.1 and refines D45.
- **Why:** The owner wants a simpler sign-up with no mail step.
- **Gave up:** Proof that an email belongs to its owner. Anyone can register with someone else's address. Mitigations: a Google ID token with a verified email matching a password account takes the account and drops the password (D45); rate limits stay; nothing sensitive is sent to an address, and reset and deletion links go only to the address on file.
## D49. Sync times are stored in milliseconds; edits never go back in time (2026-11-25)
- **Decision:** The drift `updated_at` sync column is an integer of UTC milliseconds (drift's own DateTime storage is whole seconds); v1's `feed_state.updated_at` was converted. A local edit is stamped `max(now, previous stamp + 1 ms)`.
- **Why:** The server compares milliseconds. With seconds, a second edit in the same second as a sync could tie with the first and be reverted by the server's copy. The +1 ms rule means a phone whose clock moved backwards still lets the user's latest tap win on that row.
- **Gave up:** Nothing visible. The other time columns stay in seconds.

## D50. Migrated settings fill an empty account but never overwrite it (2026-11-25)
- **Decision:** In the v1 to v2 migration, settings rows (which have no time column) get `updated_at` = the epoch; only values that differ from the default are dirty. Seeded defaults are always clean and stamped at the epoch. Every other migrated row follows CONTRACTS 15.5 (its own time column, dirty).
- **Why:** A phone that used the app before accounts must not push "theme: dark" over the theme the user chose on another device, but a value it set itself should reach an account that has none.
- **Gave up:** A pre-account setting loses to any value the account already has, even an older one.

## D51. Sign-out pushes first; offline it warns with a count; a different account wipes first (2026-11-25)
- **Decision:** Sign out pushes unsynced rows before the wipe. If some are still unsynced (offline), the confirm says "N changes not synced yet will be lost" and the button reads "Sign out anyway". `sync_state.user_id` records whose data is on the phone; if a different account signs in (possible after a refused refresh, which keeps data per 14.5), the phone's user tables are wiped before the first push.
- **Why:** Never lose data silently, and never upload one person's study data into another person's account.
- **Gave up:** In the refused-refresh case, unsynced changes of the previous account are lost when someone else signs in.

## D52. A fresh device decides onboarding after the first pull; picks count as done (2026-11-25)
- **Decision:** Until the first sync on this device succeeds, the router treats onboarding as done (the user waits on Home, not in onboarding). After that pull, if the account has any onboarding picks but `onboarding_done` is not `true`, the app sets it to `true` (and syncs it). Offline first sign-in: the pull fails, so onboarding is decided from local data.
- **Why:** CONTRACTS 14.5 decides by the pulled setting; the S15 prompt also asks to skip onboarding when picks exist. Doing both covers accounts whose setting never synced.
- **Gave up:** A brief Home view before onboarding on a brand-new account (onboarding is not built yet, S5).

## D53. Sync triggers and backoff (2026-11-25)
- **Decision:** One run at a time; a trigger during a run makes one more run after it. Triggers: sign-in and app start, app resume, network regained (`connectivity_plus`), 5 s after the last local write (only if something is dirty), every 15 minutes, and "Sync now" in Settings. Failures back off 30 s, 2 min, then 10 min as the cap; sign-in, app start, network regained and "Sync now" skip the wait. A 401 after the client's one refresh is not retried. Rejected records (`invalid_data` and so on) stop being sent.
- **Why:** CONTRACTS 15.5 plus the S15 prompt (resume and manual). Debounce plus single-flight keeps under the server's 60 pushes per minute.
- **Gave up:** Instant sync of every tap.

## D54. Create account asks confirm password in the app; sign-in errors are one sentence (2026-11-25)
- **Decision:** Create account has email, password and confirm password (no name field). The password rule is the server's: 10 to 128 characters, ticked off as the user types. The button is disabled until the email looks valid, the rule passes and the two passwords match; "Passwords don't match" shows once the confirm field loses focus or both fields are filled. Sign in takes the email only (the backend has no username sign-in) and shows "Wrong email or password" for every rejected attempt (4xx). Offline, rate limits and server faults keep their own copy, so the user is not told a wrong password when the network is the problem. `SignedIn.showVerify`, `AuthUser.emailVerified`, `resendVerification` and the Settings banner are gone; the router has no verify route.
- **Why:** D48 removed email verification; the screens had to follow, and a single error sentence stops sign-in from revealing which emails have accounts.
- **Gave up:** Display name at sign-up (it can be added later; the field is optional on the server) and a more specific error for a mistyped email.
## D55. One entry point for poster art; bundled posters win only where a slot opts in (2026-11-25)
- **Decision:** `PosterImage(titleId, crop, fallback)` draws `BundledPosterArt` when the manifest has the title (dark theme evening, light theme day, per mode) and the slot's previous art otherwise. It fills its box like `BoxFit.cover`. Crops: poster 0 0 200 300 (poster cards), banner 0 50 200 100 (Library hero, title sheet), square 20 40 160 160 (Fact of the day, Home study rows). `PosterData.titleId`, `ArtData.titleId` and `ArtData.crop` carry it; `titleArt(..., crop:)` opts a slot in. Reader, quiz, feed, resume card and Library study rows pass no crop and are unchanged.
- **Why:** The reader and feed show content photos with credits, and other sessions own them; opt-in keeps this change to the slots named in the S-prompt. The feed card and Home quiz scores have no title art slot to swap.
- **Gave up:** Bundled art in the resume card and Library study rows until someone asks for it. D54 is taken by S26 (app/auth-simple), so this is D55.
## D56. Chat is session memory only, with one card per failure (2026-11-25)
- **Decision:** The chat screen keeps the last loaded history per title in provider memory for the session and refreshes it from `GET /v1/me/chat/{title_id}` on every open; no drift table. Every refusal from the server is a card with a picture and one action (offline, signed out, daily cap, providers down, rate limit, other). A failed question is not left as a bubble: its text returns to the composer and "Try again" resends it. The 5 days live in one constant (`chatRetentionDays`).
- **Why:** The server is the source of truth (CONTRACTS 16, D39, D46), and sync would add a table that can disagree with it. A bubble the server never stored would vanish on the next history load.
- **Gave up:** CONTRACTS 16 says drift `chat_messages` is a read-through cache, so history is not readable offline (the composer is off then anyway). The owner asked for no new tables. History loads one page of 100, so a chat past 100 messages shows its newest 100.
## D57. Security fixes: client IP from the last proxy hop, revocation kills access tokens, per-IP and mail caps (2026-11-25)
- **Decision:** From docs/SECURITY_AUDIT.md. H1: uvicorn runs with `--no-proxy-headers` and the app takes the client IP `TRUSTED_PROXY_HOPS` entries from the right of `X-Forwarded-For` (Render: 1, unverified against Render's docs, which do not describe the header). M2: `users.tokens_valid_after` (Alembic 0004) is set by every "revoke all sessions" (password reset, Google link, refresh-token reuse); an access token with an earlier `iat` gets `401 unauthorized`. M1: 40 chat replies and 5 email sign-ups per client IP per rolling 24 h. M3: reset and deletion requests share 5 per address per 24 h, and at most 80 mails a day go out in all (past it they are dropped with a warning). L3, L4, L6 (history filter), L7 as the audit proposes. All new limits are in memory, answer with existing codes (`rate_limited`), and are env settings.
- **Why:** The audit's smallest fixes. The documented limits in CONTRACTS 14.4 and 17 (3 per hour per email, 5 sign-in failures per 15 minutes per email) are unchanged; the new ones sit on top. CONTRACTS 14.4 and 16 should list the new per-IP and mail caps, and 18 the new `users` column.
- **Gave up:** People sharing one public IP (a campus, mobile carrier NAT) share 40 chats and 5 sign-ups a day. In-memory counts reset when the free instance sleeps. A token issued in the same second as a revocation survives (`iat` is whole seconds). Not done, because each changes a contract or needs an owner decision: M4 (Google auto-link only for Gmail or Workspace), L5 (sign-in lockout keyed by email and IP), L1 (`auth_time` for deletion), L8 (drop `details.method`). Outside `backend/`: the purge workflow half of L6, L9 to L12.

## D59. Sign-in lockout is per email and client IP, with a looser per-email cap (2026-11-27)
- **Decision:** From SECURITY_AUDIT L5. The 5 failures per 15 minutes lock now counts per email and client IP (H1's `client_ip`), so 5 wrong passwords from one IP no longer lock the owner out everywhere. A second counter allows 50 failures per rolling hour per email from all IPs together. Both count only wrong email or password, both answer `429 rate_limited` with `scope: "account"`, and when both are full `Retry-After` is the longer wait. The 50 is a constant in `limits.py`, not an env setting.
- **Why:** The audit's smallest fix. A constant because the cap is a security floor, not tuning, and a new env setting would also need `.env.example` and `backend/README.md`.
- **Gave up:** Someone spreading 50 guesses an hour over many IPs can still lock an address out of password sign-in for up to an hour (a password reset does not clear it; Google sign-in is unaffected). People behind one shared IP share the 5-failure count for an address. Counts are in memory and reset when the instance sleeps.
