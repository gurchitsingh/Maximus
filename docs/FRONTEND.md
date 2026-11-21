# FRONTEND (v2): Flutter, Android first

## Packages (proposed)
Riverpod, go_router, dio, drift (SQLite), shared_preferences, cached_network_image, flutter_tts, flutter_animate (or built-in animations), confetti.

## Structure
lib/ app/ (router, theme), features/ (onboarding, home, library, title, study, reader, chat, quiz, feed, settings), data/ (api client, drift DB, repositories), domain/ (models, recommender).

## Local database (drift)
titles_cache, lessons_cache, study_list, ratings(title_id, value), progress(title_id, lesson_index, done_at), quiz_results(title_id, score, at), interests(topic, weight), chat_usage(date, count).
Content is downloaded per title when added to the study list, so Study works offline.

## Match % (on-device recommender)
Score each title 0 to 100:
- interest overlap from onboarding picks (strongest at start)
- similarity to titles you rated up / added / finished (shared category, era and tags)
- negative weight from thumbs down
- small bonus for titles near ones you finished
Show as a rounded percentage. Plain weighted sum; no ML needed. Tag every title with category, era, region, themes.

## Navigation
Bottom nav: Home, Library, Feed, Study. Inside a title: contextual bottom bar (Lessons, Chat, Quiz).

## Notes
- Posters come with accent colour from the API, so no runtime colour extraction.
- Chat calls the backend only; no keys in the app.
- Android only for V1; keep code platform-neutral.
