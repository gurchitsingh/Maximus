# FRONTEND (v2): Flutter, Android first

## Packages (proposed)
Riverpod, go_router, dio, drift (SQLite), cached_network_image, flutter_tts, json_serializable, flutter_animate (or built-in animations), confetti. No shared_preferences: settings live in drift (CONTRACTS.md 8.1).

## Structure
lib/ app/ (app, router), core/ (theme and design tokens, shared widgets, widget gallery), features/ (splash, onboarding, home, library, title_sheet, study, reader, chat, quiz, feed, settings, credits), data/ (api client, drift DB, models, repositories), domain/ (match %, quiz picker, feed ranker, markdown parser). Full tree and routes: CONTRACTS.md section 8.

## Local database (drift)
settings (incl. install_id), interests, study_list, ratings, lesson_progress, quiz_results, quiz_seen, feed_state, cached_docs (catalogue, credits, On This Day), cached_titles. Columns and "Clear my data": CONTRACTS.md section 5. No chat_usage table: the server owns the chat caps and returns remaining_today.
A title is cached whole the first time it is opened (study-list titles are also refreshed in the background), so every opened title works offline.

## Match % (on-device recommender)
Exact formula, weights and test vectors: CONTRACTS.md section 6 and docs/examples/match-cases.json. In short:
- signals: onboarding topic and leader picks, ratings (thumbs down is negative), study list, lessons read, feed likes/saves/dislikes
- each signal spreads to other titles by tag similarity (Jaccard over group, era, region and themes)
- squashed to 40 to 99%; no badges at all before the first signal
Plain weighted sum; no ML needed.

## Navigation
Bottom nav: Home, Library, Feed, Study. Inside a title: contextual bottom bar (Lessons, Chat, Quiz).

## Notes
- Posters come with their bg and tint colours and lettering kind from the API, so no runtime colour extraction.
- Chat calls the backend only; no keys in the app.
- Android only for V1; keep code platform-neutral.
