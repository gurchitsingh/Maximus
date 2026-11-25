# FRONTEND (v3): Flutter, Android first

# V3 CHANGES (24 Nov 2026) - read first

These override anything below that conflicts.

- **Auth:** sign in with Google and email and password. The refresh token and user fields are in secure storage (flutter_secure_storage); the access token is memory only. Packages added: google_sign_in, flutter_secure_storage.
- **Sync layer (offline-first):** the drift database stays the working copy. A sync service pushes and pulls ratings, study list, progress, quiz results, feed state, settings and onboarding picks in the background when online (last-write-wins by updated_at in milliseconds, deletes as tombstones). Chat history is not synced: it is read from its own endpoint (D56). The synced tables carry updated_at, deleted and dirty; drift schemaVersion is 2.
- **Navigation:** bottom nav is Home, Library, Feed, Settings. The Study screen becomes the first section of Library. The router redirects to Sign in when signed out.
- **Built:** Welcome, Sign in and Create account screens (email, password, confirm password; no verify-email screen or route, D48), Fact of the day card (bundled list picked by date; 12 facts so far), account deletion and sign out in Settings, privacy policy link. **Not built:** onboarding (the router has no onboarding routes yet).
- **Posters:** SVG posters are bundled as assets (`assets/posters`, `flutter_svg`) with a `manifest.json` of `{mode, bg, tint, lettering, lines}` per title; modes are pair, wash and single (CONTRACTS 21, D47). All draw through `PosterImage(titleId, crop, fallback)` (D55). 19 of 28 topics have art.
- **Already built and kept:** match %, title sheet, reader, quiz, feed, settings, voice sheet, confetti drawn with CustomPainter.

---

## Packages
Riverpod, go_router, dio, drift (SQLite), cached_network_image (with flutter_cache_manager), flutter_tts, url_launcher, flutter_svg, google_sign_in, flutter_secure_storage, connectivity_plus. There is no shared_preferences: settings live in drift. Confetti is drawn by hand (CustomPainter), not a package.

## Structure
lib/ app/ (router, shell), core/ (theme, widgets, util, gallery), features/ (auth, chat, credits, factday, feed, home, library, on_this_day, quiz, reader, settings, shared, title_sheet, topic; onboarding not built), data/ (api, db, models, repositories, sync, dev), domain/ (match, quiz, feed, markdown_lite).

## Local database (drift)
cached_docs, cached_titles, settings, interests, study_list, ratings, lesson_progress, quiz_results, quiz_seen, feed_state, sync_state (CONTRACTS 5.1, 15.5). Synced tables carry updated_at (UTC ms), deleted and dirty. There is no chat_usage or chat_messages table: caps live on the server and chat history is session memory (D56).
A title's content is cached whole the first time it is opened, so it works offline afterwards.

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
- Poster colours (`bg`, `tint`, lettering, lines) come from the API and are copied into the poster manifest, so no runtime colour extraction.
- Chat calls the backend only; no keys in the app. Chat needs a signed-in user. The default API base URL is `http://10.0.2.2:8000` (debug); a release build needs `--dart-define=API_BASE_URL=https://...`.
- Android only for V1; keep code platform-neutral.
