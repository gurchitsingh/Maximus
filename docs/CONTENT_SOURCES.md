# v2 CHANGES (21 Nov 2026) - read first

These override anything below that conflicts.
- Scope is 20 titles, one per topic, each one big Wikipedia article (or a few pages) split into ~400-word lessons. The earlier "collections of many cards" model is dropped.
- Images are hand-picked per title from Wikimedia Commons (title art, lesson images, feed cards), copied to our storage with credit.
- Feed facts: first draft by an LLM from the stored lesson text, then human-checked. Max 280 characters.
- Quiz: hand-written bank of ~50 per title, 6 random per attempt.
- Chatbot grounding source = the stored lessons of the open title only.
- Free LLM keys: OpenRouter free models, Google Gemini free tier. Terms and limits change; re-check before launch.
- V2 perspective mode needs curated per-class source text (Wikipedia alone is not enough). Candidate sources to evaluate later: Wikipedia social-history articles, Wikisource primary documents, Project Gutenberg (public domain), open textbooks (OpenStax, CC BY).
- People (Think Like... section): 40 leaders and 11 thinkers per TOPICS.md. Biographical facts from Wikipedia and cited reference works; Sikh history titles checked against Sikh history sources. Traits, 'odds beaten' and 'use it today' are interpretation, written by hand or AI-drafted and reviewed; each claim cites a source. Legendary figures (Romulus) are labelled as legend.
- Wikipedia text is CC BY-SA 4.0: show attribution and link on every lesson and in Settings > Credits.

---

# Maximus — Content Sources

Derived from `APP_DETAILS.md`. Defines where each card comes from, which fields each source can really provide, the licence obligations, and the rules that turn raw API data into a card without AI.

Research date: 21 Nov 2026. Items marked **(verify)** come from general knowledge or a single secondary source and must be checked against the official docs when the backend is built.

## 1. Findings that change the plan

1. **Wikipedia is the right backbone, but it must be fetched by us on a schedule, not per user.** Wikimedia now rate-limits API traffic by how well it is identified; clients should send a policy-compliant User-Agent and keep concurrent requests to 3 or fewer. The backend ingests cards into its own database; the app never talks to Wikipedia.
2. **Wikipedia text is CC BY-SA 4.0 (verify).** Every card showing Wikipedia text needs a credit, a licence link and a link to the source page. Trimming counts as a modification and should be stated.
3. **Open Trivia DB does not fit the card model.** It serves quiz questions with answers, not facts, and allows one request per IP every five seconds. **Decided: dropped.** Quizzes use our own hand-written question bank (section 11a).
4. **Free news APIs cannot be used in production.** NewsAPI's free plan is for development only, and GNews's free plan is non-commercial with a 12-hour delay. **Decided: current affairs and tech news are both left out of v1.**
5. **Wikipedia gives no structured era or place label.** The card's label line (for example "31 BCE · Actium, Greece") will come from **Wikidata** where it has the data, and be omitted when it does not.
6. **Image rights are per file.** Each image's licence must be read from Wikimedia Commons and only allowed licences accepted. Anything else means the card falls back to the typographic card.
7. **Avoid `api.wikimedia.org`.** Its "Core API" is scheduled for gradual deprecation from July 2026. Use each wiki's own domain.

## 2. Sources at a glance

| Source | Used for | Key? | Text/data licence | Verdict |
|---|---|---|---|---|
| Wikipedia REST API (`/api/rest_v1/`) | Summaries, lead image, On This Day, featured feed | No | CC BY-SA 4.0 (verify) | **Use** |
| Wikipedia Action API (`/w/api.php`) | Full article text by section, category members | No | CC BY-SA 4.0 (verify) | **Use** |
| Wikidata | Era and place labels | No | CC0 (verify) | **Use** |
| Wikimedia Commons (Action API, `imageinfo` + `extmetadata`) | Image licence, author, credit | No | Per file | **Use** |
| Europeana Search API | Extra archival images | Free key | Metadata CC0; media per item | **Use, phase 2** |
| Hacker News API | Tech news headlines | No | n/a (links out) | **Post-v1** |
| Open Trivia DB | Trivia | No | CC BY-SA 4.0 | **Dropped** (own question bank instead) |
| NewsAPI.org / GNews | News | Yes | Dev / non-commercial only on free plans | **Do not use** |
| REST Countries | Country data | See note | Open source | **Skip for v1** (Geography comes from Wikipedia) |

Note on REST Countries: it appears to have moved to a new versioned API with an API key; confirm before depending on it (verify).

## 3. Wikipedia

### 3.1 Calls
| Purpose | Call |
|---|---|
| Card summary | `GET https://en.wikipedia.org/api/rest_v1/page/summary/{title}` returns title, plain-text extract, thumbnail, original image, page URL, description, Wikidata id (verify field names) |
| Full article by section | `GET https://en.wikipedia.org/w/api.php?action=query&prop=extracts&explaintext=1&exsectionformat=wiki&titles={title}&format=json` returns plain text with `== Heading ==` markers (verify) |
| Daily history | `GET .../api/rest_v1/feed/onthisday/{type}/{MM}/{DD}`; types: `selected`, `events`, `births`, `deaths`, `holidays`, `all` |
| In the news | `GET .../api/rest_v1/feed/featured/{YYYY}/{MM}/{DD}` (verify it includes a `news` section) |
| Category expansion | Action API `list=categorymembers` |

### 3.2 Etiquette
- Send a descriptive `User-Agent` with a contact URL or email.
- At most 3 concurrent requests; space requests out.
- Cache everything. Refresh on a schedule (see 7).

### 3.3 Licence line on every Wikipedia-derived card
"Text from Wikipedia, CC BY-SA 4.0. Shortened." plus the page URL. The Go Deep reader repeats it at the end.

## 4. Images

### 4.1 Where images come from
1. The summary's `originalimage` / `thumbnail` (the article's lead image, hosted on Commons or Wikipedia).
2. Phase 2: Europeana for topics with weak Wikipedia images (`reusability=open`, then check the rights URI).

### 4.2 Licence check (Commons)
Call `action=query&prop=imageinfo&iiprop=extmetadata|url|size&titles=File:...` and read:
- `LicenseShortName` / `UsageTerms` for the licence
- `Artist` (may contain HTML; strip it) and `Credit`
- `Attribution` if present (it replaces Artist + Credit)

Note: for multi-licensed files these values can be unreliable.

**Accept:** public domain, CC0, CC BY, CC BY-SA. **Reject:** everything else, and anything with an unclear licence.

### 4.3 Credit line
`{Artist, plain text} · {LicenceShortName} · Wikimedia Commons`, linking to the file page.

### 4.4 Image selection rules
- Prefer images wider than 800 px.
- Accept portrait, landscape and tall maps; store width and height so the app can lay out before loading.
- No usable image means the card is a **typographic card** (title and fact only). Never a grey placeholder.
- Weak images (logos, flags, signatures, modern snapshots on history topics) can be filtered by a block list on file-name words and by file type (SVG logos).

## 5. Era and place labels (Wikidata)

The summary response includes the page's Wikidata id (verify). From Wikidata read, in this order:
- **Era:** point in time (P585), start time (P580), inception (P571), date of birth/death for people.
- **Place:** location (P276), country (P17), place of birth for people.

Format "31 BCE · Actium, Greece". If either part is missing, show the other; if both are missing, omit the label line. Do not guess.

## 6. Card building rules (no AI)

### 6.1 Eligibility gate
A page becomes a card only if all hold:
- Not a disambiguation page.
- Extract of at least 80 characters.
- Article length above a minimum (to skip stubs).
- Has an allowed image, or is allowed as a typographic card (limit these to a small share).
- Title is not on the block list.

### 6.2 Fact trimming
1. Take the plain-text extract.
2. Remove parenthetical text (pronunciations, alternate names, date ranges); dates go to the label instead.
3. Split into sentences, protecting abbreviations ("St.", "c.", "Dr.").
4. Keep the first sentence; add the second only if the total stays under about 220 characters.
5. Never cut mid-sentence. If the first sentence alone is too long, keep it whole and mark the card as long.

### 6.3 Go Deep content
- Split the full extract at `== Heading ==` markers into sections.
- Drop "See also", "References", "Notes", "Further reading", "External links", "Bibliography".
- Cap total length (proposal: about 1,800 words), ending with "Read the full article on Wikipedia".
- Keep each section as paragraphs; the app splits into sentences for text-to-speech.

## 7. Topic seeds and collections

Without AI, topics are defined by **curated lists** kept in the repository.

- **Interest sub-options:** each is a list of Wikipedia page titles (30 to 100 at the start), optionally extended by a Wikipedia category crawl, then passed through the eligibility gate.
- **Collections:** hand-picked ordered lists ("The Roman World", "The Hundred Years' War"), each with a title, one-line description and cover image chosen from its cards.
- **Daily items:** Wikipedia On This Day (`selected`) feeds the GK category.
- **Current affairs:** not in v1.
- **Tech news:** post-v1 (see 8).
- **Storage rule:** everything is stored in our database unless it changes within days. Only On This Day is live (daily, cached). Initial load is a bulk import; the weekly job refreshes changed pages.

### Refresh schedule (proposal)
| Job | Frequency |
|---|---|
| Seed lists to cards (new or changed pages) | Weekly |
| On This Day | Daily |
| Image licence re-check | Monthly |

### Size estimate
About 3,000 launch cards at roughly 3 requests per card (summary, image licence, Wikidata) is about 9,000 requests, which is under an hour at 3 requests per second.

## 8. Tech news cards (Hacker News)

Hacker News returns story titles and links to other sites, not article text or images. So these cards are different:
- **Content:** headline, source domain, link out. No image, no Go Deep, no fact line.
- **Design implication:** these need a card variant in `DESIGN.md` (compact headline card). This is an open decision.
- Do not copy third-party article text.

## 9. Field mapping to the card shape

| Card field | Source |
|---|---|
| `id`, `topic` | Our seed list |
| `title` | Summary title |
| `fact` | Trimmed summary extract (6.2) |
| `eraLabel`, `placeLabel` | Wikidata (5) |
| `imageUrl`, `width`, `height` | Summary image |
| `imageCredit`, `imageLicence` | Commons `extmetadata` (4.2, 4.3) |
| `imageKind` | Derived from Commons categories or a manual tag on the seed (verify practicality) |
| `sourceName`, `sourceUrl` | "Wikipedia" and the page URL |
| `textLicence` | Constant "CC BY-SA 4.0" (verify) |
| `deep_content` | Sections from the full extract (6.3) |

`imageCredit`, `imageLicence`, `eraLabel`, `placeLabel`, `width`, `height` and `textLicence` are additions to the draft shape in `APP_DETAILS.md`.

## 10. Risks

| Risk | Mitigation |
|---|---|
| Wikimedia rate limits tighten | Ingest on a schedule, cache, identify the client, keep a swappable fetch layer |
| REST API endpoints are being migrated (RESTBase sunset in progress) | Isolate calls behind one module; fall back to the Action API |
| Lead images are not archival | Filter rules plus typographic cards; add Europeana in phase 2 |
| Era/place labels often missing | Labels are optional in the design |
| Plain Wikipedia text is dull | Selection quality and layout carry the hook; curated seeds only include strong pages |
| Licence mistakes | Allow-list only; show credits on every card; monthly re-check |

## 11. Decisions made

| # | Decision | Answer |
|---|---|---|
| 1 | Open Trivia DB | Not used. Quiz questions come from our own hand-written bank (see 11a) |
| 2 | Current affairs | Left out of v1 (no free news API allows production use) |
| 3 | Tech news | Out of v1 (section 8 kept for later) |
| 4 | REST Countries | Skipped (my call, not yet confirmed by the user) |
| 5 | Go Deep cap | About 1,800 words (my call, not yet confirmed by the user) |

### 11a. Quiz question bank (new)

- Each collection ("lecture") has its own bank of about 50 multiple-choice questions, written by hand and stored in the repo as YAML next to the collection list.
- A quiz attempt picks 6 questions at random from that collection's bank.
- Not AI-generated and not from Open Trivia DB. Writing about 50 per collection is manual work for us.
- Each question stores a Wikipedia page title it comes from, so every answer can show a source link.

## 12. Sources reviewed

- Wikimedia API Portal deprecation notice (Core API deprecation from July 2026): https://wikitech.wikimedia.org/wiki/API_Portal/Deprecation
- Wikimedia APIs changelog (rate-limit enforcement, REST changes): https://www.mediawiki.org/wiki/API:REST_API/Changelog
- Wikimedia APIs access policy and rate limits: https://www.mediawiki.org/wiki/Wikimedia_APIs/Access_policy
- Commons `extmetadata` (CommonsMetadata extension): https://www.mediawiki.org/wiki/Extension:CommonsMetadata/en
- Commons credit-line rules: https://commons.wikimedia.org/wiki/Commons:Credit_line/en
- Europeana APIs and terms of use: https://www.europeana.eu/pl/apis and https://europeana.eu/en/rights/terms-of-use
- Open Trivia DB configuration and limits: https://opentdb.com/api_config.php
- NewsAPI pricing: https://newsapi.org/pricing
- Comparison of free news API terms: https://dev.to/hassann/top-10-free-news-apis-for-developers-5fg8
- REST Countries changelog: https://restcountries.com/changelog
