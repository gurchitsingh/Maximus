# DOC_CONFLICTS (25 Nov 2026)

Places where a doc and the code (or two docs) disagree and the right answer is the owner's call. Nothing here was changed in the docs. Each entry: what the doc says, what the code does, where.

| # | Doc statement | Code reality | Where |
|---|---|---|---|
| 1 | Settings has Profile (name, email), Taste, "Delete all chats" and "Chats are kept 5 days" (CONTRACTS 16, 19; FLOW 9; DESIGN_SPEC 15.1) | Settings has Theme, Text size, Voice speed, Voice, Clear my data, About, Credits, and an Account section (Email, Sync now, Sign out, Delete my account, Privacy policy, Delete account on the web). No Profile, Taste or "Delete all chats" row. The retention note appears inside the chat screen; "Delete this chat" exists there | `app/lib/features/settings/settings_screen.dart:36-111`, `account_section.dart:54-74`, `chat_screen.dart:182,234` |
| 2 | First API call allows a 60 s connect timeout and shows a "Waking the server..." state (CONTRACTS 18, D44) | Connect timeout 8 s, receive 20 s, and no "Waking" state anywhere in the app | `app/lib/data/api/api_client.dart:49-50` |
| 3 | Onboarding includes text size (FLOW 2 step 1, FLOW header) versus text size only in Settings (DESIGN_SPEC 12 item 3, 15.1) | Onboarding is not built, so the code cannot settle it | `app/lib/app/router.dart:90-92` |
| 4 | Google sign-in ships first and email and password one version later, "unconfirmed" (D35, CONTRACTS 14.3) | The app ships both on the Welcome and Sign in screens at once | `app/lib/features/auth/sign_in_screen.dart` |
| 5 | Chip templates end with "Tell me about {current lesson heading}" for every kind; people chips are "What is {name} known for?", "What odds did they beat?" or "What were their big ideas?" (CONTRACTS 4.2) | The third chip is "Why does it still matter today?" (topics), "What can I learn from {name}?" (leaders) or "How can I use these ideas today?" (thinkers); none uses the lesson heading | `app/lib/features/chat/chat_suggestions.dart:8-24` |
| 6 | Chat drift cache `chat_messages` (CONTRACTS 16, original text) | None; session memory only (D56). CONTRACTS 16 now carries a note, but the owner asked in D56 for no new tables, so say if the cache should come back | `app/lib/features/chat/chat_controller.dart:1-4` |
| 7 | `GET /v1/me/chat` page `limit` default 50 (CONTRACTS 16) and the app asks for 100 | A chat past 100 messages shows only the newest 100 (D56 accepts this) | `app/lib/features/chat/chat_api.dart:33-36` |
| 8 | The `Fact of the day` list has 90 to 100 entries before launch (CONTRACTS 20, APP_DETAILS) | 12 facts in `facts.json` | `app/assets/facts/facts.json` |
