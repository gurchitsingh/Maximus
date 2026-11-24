# FRONTEND (v3): Flutter, Android first

# V3 CHANGES (24 Nov 2026) - read first

These override anything below that conflicts.

- **Auth:** sign in with Google and email and password. Tokens stored in secure storage (flutter_secure_storage). New packages to add to CONTRACTS 8.1: google_sign_in, flutter_secure_storage.
- **Sync layer (offline-first):** the drift database stays the working copy. A sync service pushes and pulls ratings, study list, progress, quiz results, feed state, settings and chat history in the background when online (last-write-wins by updated_at, deletes as tombstones). Add updated_at and a deleted flag to the synced tables via a drift migration.
- **Navigation:** bottom nav is Home, Library, Feed, Settings. The Study screen becomes the first section of Library. The router redirects to Sign in when signed out.
- **New features:** Sign in and Create account screens, onboarding in the new order, Fact of the day card (bundled list of about 100 facts, picked by date), account deletion and sign out in Settings, privacy policy link.
- **Posters:** SVG posters (day and evening versions) bundled as assets or served from the backend; decide in the design-delta job.
- **Already built and kept:** match %, title sheet, reader, quiz, feed, settings, voice sheet, confetti drawn with CustomPainter.

---

## Packages
Riverpod, go_router, dio, drift (SQLite), shared_preferences, cached_network_image, flutter_tts, url_launcher; v3 adds google_sign_in and flutter_secure_storage. Confetti is drawn by hand (CustomPainter), not a package.

## Structure
lib/ app/ (router, theme), features/ (auth, onboarding, home, library, title, reader, chat, quiz, feed, settings), data/ (api client, drift DB, repositories, sync), domain/ (models, recommender).

## Local database (drift)
titles_cache, lessons_cache, study_list, ratings(title_id, value), progress(title_id, lesson_index, done_at), quiz_results(title_id, score, at), feed_state, interests(topic, weight), settings, chat_usage(date, count), chat_messages (v3). Synced tables carry updated_at and a deleted flag.
Content is downloaded per title when added to the study list, so it works offline.

## Match % (on-device recommender)
Score each title 0 to 100:
- interest overlap from onboarding picks (strongest at start)
- similarity to titles you rated up / added / finished (shared category, era and tags)
- negative weight from thumbs down
- small bonus for titles near ones you finished
Plain weighted sum; no ML. Exact weights are in CONTRACTS section 6 (tested against docs/examples/match-cases.json). Check the design's rating deltas (up +4, down -6 within a group) against it before S5.

## Navigation
Bottom nav: Home, Library, Feed, Settings. Inside a title: contextual bottom bar (Lessons, Chat, Quiz).

## Notes
- Posters come with accent colour from the API, so no runtime colour extraction.
- Chat calls the backend only; no keys in the app. Chat needs a signed-in user.
- Android only for V1; keep code platform-neutral.
