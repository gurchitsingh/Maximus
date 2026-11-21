# DESIGN (v2): visual direction

## Feel
Streaming-app energy applied to learning. Cinematic posters, big type, motion, playful rewards. If a screen looks like a newspaper, a textbook or a museum website, it is wrong.

## Kept from round 1
The warm bronze/gold accent. Everything else changes.

## Colour
- Dark-first. Near-black warm background (#0F0D0A to #17130E), cards slightly lighter.
- Accent: bronze/gold (round-1 bronze, lifted for dark: about #C8933A). One accent only.
- Each title may tint its own poster and sheet (a single colour drawn from its picture), so the library feels varied.
- Light theme exists, same structure, warm off-white.
- Correct/incorrect in quizzes: green and red, with icons, never colour alone.

## Type
- UI and body: a clean modern sans (Inter or similar), bundled.
- Titles: each of the 28 topics gets its own title treatment; people titles (Think Like...) are portrait illustrations with the name set in a matching lettering style (examples: Roman = chiselled caps; French Revolution = hand-lettered tricolour; WW2 = stencil; Egypt = carved). Max 3 or 4 font families in total, all bundled and licence-checked.
- Reader body: readable sans or soft serif at 17 sp default, line height 1.55.

## Imagery
- Real images on almost every screen: title posters, onboarding tiles, feed cards, quiz headers.
- Source: Wikimedia Commons (PD, CC0, CC BY, CC BY-SA), hand-picked per title. Credit line one tap away.
- Treatment: gradient scrim at bottom for legible text, slight vignette, no filters that hide the picture.

## Motion and surprise
- Poster rows scroll with parallax; hero auto-previews.
- Add to study list: poster flips to "Added" with a small pop.
- Match % counts up on reveal.
- Onboarding: guess-the-year, tile pops, confetti on first match.
- Lesson finished: short celebration. Quiz right answer: quick bounce. Keep it gentle; no guilt, no streak loss.

## Components
Poster card (2:3), hero banner, title sheet (bottom sheet), match badge, thumbs rating, progress bar, lesson page, quiz option button, chat bubble, feed card (9:16), dashboard tiles, bottom nav with contextual Chat button.

## Screens to design (in order)
Splash, onboarding (4), Home/dashboard, Library, Title sheet, Study list, Reader, Chat, Quiz (question + result), Feed, Settings.

## Logo
Engraved "M" in a roundel/stamp (round-1 direction A), simplified to work at 48 px as an app icon. Only logo and splash carry the Roman look. Name still undecided; design the mark so the letter can change.

## Accessibility
Contrast AA on all text over images (use scrims), text size setting, touch targets 48 dp, read-aloud, no information by colour alone.
