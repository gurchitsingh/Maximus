# FUTURE_FEATURES.md (Maximus, working title)

Status: ideas only. NOT in V1. Do not build before V1 (library, study list, match %, reader, quiz, feed, chatbot) is running and tested. Order below is the planned order.

Last updated: 2026-11-22

---

## 1. Perspective mode (V2)

### One-line idea
Pick a country and a time period, then pick a social class "lens", and see the same period through that group's eyes: what their days were like, what hurt them, what they wanted, what they feared.

### Why it matters
History books mostly tell the story of rulers and wars. Perspective mode shows that the same event felt completely different to a king, a merchant and a peasant. It teaches empathy and causes (why revolutions happen), and nothing like it exists in the competing apps. It also pairs naturally with the library: every topic title can open into perspectives.

### User flow
1. Open a topic title (e.g. French Revolution) and tap **Perspectives**. Or start from the Home "Perspectives" row.
2. **Choose country** (only those with content, shown as poster tiles).
3. **Choose period** (a slider or chips, e.g. 1770s, 1789, 1793 to 1794).
4. **Choose lens** (v1 of this feature has three):
   - **Authorities / rulers** (crown, nobility, clergy, officials, army command)
   - **Middle and working class** (merchants, artisans, clerks, urban workers, small landholders)
   - **Poor people** (peasants, labourers, the landless, the destitute)
5. Read the perspective card stack for that lens (see content below).
6. Tap **Switch lens** to see the same moment from another class. A **Compare** view puts the three lenses side by side on the same event.
7. Short quiz at the end ("whose problem was this?") and "Ask about this" chat grounded in the perspective text.

### What each perspective contains
- **Snapshot:** who they were, how many, where they lived (one paragraph).
- **A day in their life:** food, work, money, housing, safety, rights.
- **Their problems:** 4 to 6 concrete problems, each with cause and effect (taxes, bread prices, debt, forced service, fear of enemy attack, losing power, etc.).
- **What they wanted and what they feared.**
- **The event as they saw it:** how the key event (war, tax, famine, reform, coup) looked from this class.
- **What they could actually do:** options available to this class (petition, riot, flee, bribe, enlist, obey). This feeds the leader game later.
- **Voices:** 1 to 2 short primary-source lines, public domain only, with citation.
- **Sources:** books or articles used, with a confidence note.

### Content rules (non-negotiable)
- Every perspective is labelled **"An interpretation based on sources"**, never presented as the single truth.
- Each factual claim has a source. Interpretive claims need 2 reliable sources.
- No modern political framing. Describe grievances and motives, do not judge groups.
- No invented quotes. Use real, short, public-domain quotes only.
- Written and reviewed by us (AI-drafted, human-checked), not generated live.
- Keep neutral on contested topics, say where historians disagree.

### Data model sketch
```
perspective: id, title_id, country, region, period_start, period_end,
  lens (authority|middle|poor), snapshot, daily_life[], problems[{text, cause, effect, sources}],
  wants[], fears[], event_view[{event_id, text}], options[], voices[{text, source}],
  sources[], status (draft|reviewed|published), content_version
event: id, title_id, name, date, summary    (shared across lenses so Compare can line them up)
```
Delivered through the same `/v1` API as titles (new endpoint family), cached on device, works offline after first open.

### Content scope
- Launch of the feature: **4 to 6 country/period sets** x 3 lenses = 12 to 18 perspectives, roughly 700 to 1,000 words each.
- Good first sets: France 1780s (Revolution), Russia 1900s to 1917, India 1850s (1857), Rome late Republic, Britain Industrial Revolution, Mughal-era or Maratha-era India.
- Authoring pipeline: Perplexity gathers cited sources, Gemini drafts, Claude and the owner review.

### Risks and open questions
- **Accuracy and bias:** the biggest risk. Mitigation: sources per claim, "interpretation" label, owner review, a visible "Sources" button.
- **Sensitivity:** some periods are politically charged in India and elsewhere. Pick periods with care, show historians' disagreement.
- **Content volume:** about as much writing as 10 to 12 library titles. This is why it is V2.
- **Open:** which class lens names to use in the UI; whether to allow more lenses later (women, soldiers, enslaved people, religious minorities); whether Compare is a v1 or v2 feature of the mode.

### Dependencies
Needs the V1 library, reader, quiz engine and chatbot grounding. Reuses the title sheet and reader components. Needs the content pipeline from V1 (import format, review states).

### Rough size
Engine and screens: small to medium (about 4 to 6 Claude Code sessions). Content: the real cost (weeks of reviewed writing).

---

## 2. Think Like a Leader game (V2, after perspective mode or alongside it)

### One-line idea
A decision game: the user plays a ruler or leader in a historical crisis, makes choices (multiple choice or typed), sees the consequences, gets follow-up crises, and at the end is rated as a leader with a case study of what the real leader did.

### Why it matters
It turns the "Think Like..." section from reading into doing, and it is the most replayable, shareable part of the app. It teaches strategy, trade-offs and consequences, and it makes the library's leaders memorable.

### Example turn (from the owner's idea)
- **Situation:** The Senate is unhappy with your government. An enemy is looking to take control. You discover a traitor in your own family.
- **Choice:** Execute them / Exile them / Keep them close and watch / Something else (typed).
- **Consequence:** If you execute the traitor, their family turns against you.
- **Follow-up:** The traitor's family joins the enemy powers and starts provoking your people to dethrone you. New choices.

### Game loop
1. Pick a scenario (setting, role, year) from the Think Like row or a Games tab.
2. A scenario runs **6 to 8 turns**. Each turn: situation card, then 3 to 4 choices or "write your own".
3. Each choice changes **hidden meters** (below) and triggers a **consequence card**, then the next situation (which depends on the meters and previous choices).
4. At the end: **Your result** with a leader style and rating, a breakdown of the meters, and a **case study**: "What the real leader did and what happened", linked to the matching Think Like title.
5. Replay to try other choices; compare outcomes.

### Hidden meters (the engine, simple on purpose)
People's trust, Army loyalty, Treasury, Stability, Legacy (long-term outcome). Choices add or subtract values. The next situation is chosen by meter thresholds plus flags (e.g. "traitor_executed"). This avoids an exploding branching tree: a few choices shape the whole run.

### Rating
- Scored on **outcomes inside the scenario**, not on moral approval. Show trade-offs ("effective but costly").
- Output: score out of 100, a **leader style** label (e.g. Strategist, Reformer, Conqueror, Diplomat, Tyrant-in-the-making) and 3 lines of "what you did well / what cost you".
- Case study compares the player's path to the real leader's decisions, with sources.
- Be honest in the UI: "This is a simplified simulation, not a verdict."

### Typed answers
The user may write their own answer. An LLM only **maps it to the nearest authored choice** (a cheap classification), and then the **authored consequence** plays. If it cannot map, ask the user to rephrase or choose. This avoids relying on a free LLM to invent history and keeps results testable. (A fully LLM-written outcome is rejected: inconsistent, expensive, can invent history.)

### Data model sketch
```
scenario: id, title_id (leader), setting, year, role, intro, meters_init{}, status, sources[]
node: id, scenario_id, type (situation|consequence|end), text, choices[{id, text, effects{meter:delta}, sets_flags[], next_node (or rules)}]
ending: id, scenario_id, conditions, style_label, text, case_study_ref
```
Plays happen on device. Results are stored locally (no accounts). Reuses the app's JSON content pipeline.

### Content scope
- Launch of the feature: **8 to 10 scenarios**, 6 to 8 turns each, about 1,500 to 2,500 words each, including endings and case studies.
- Good first scenarios: Julius Caesar (Senate vs army, 44 BC), Ashoka after Kalinga, Shivaji vs Mughal power, Elizabeth I (Armada), Genghis Khan (unifying tribes), Napoleon (1812 Russia), Chandragupta Maurya (Nanda overthrow), Rani Lakshmibai (1857).
- Authoring: Gemini drafts branches from the Think Like title text, Claude and the owner review for accuracy and balance. Label scenarios "inspired by history".

### Risks and open questions
- **Content cost:** biggest cost, about as much as 5 to 6 titles.
- **Historical accuracy:** some scenarios fictionalise (invented traitor inside a real setting). Mark fiction clearly; keep real facts separate in the case study.
- **Scoring fairness:** avoid a single "right answer"; keep trade-off language.
- **Violence and sensitive topics:** keep text factual and non-graphic; age-appropriate.
- **Typed answers:** moderation and cost caps if an LLM is used; per-device daily limit like the chatbot.
- **Open:** score name and rating bands; whether to add share cards ("I ruled like Ashoka: 78/100"); whether to add a daily scenario; leaderboard (needs accounts, so out of scope).

### Dependencies
Needs the Think Like titles (people text and sources), the content pipeline, and optionally the chatbot's provider setup for typed-answer mapping. Perspective mode can supply the "what options this class had" content.

### Rough size
Engine and screens: small (about 3 to 5 Claude Code sessions). Content: the real cost.

---

## Reserved in V1 (cheap)
When S3 locks the contracts, add a placeholder in CONTRACTS.md for `perspective`, `scenario`, `node` and `ending` so the API and storage can grow without rework. No code or screens in V1.

## Other ideas parked here
(add new ideas below as they come)
