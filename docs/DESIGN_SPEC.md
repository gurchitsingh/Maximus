# DESIGN_SPEC: Maximus v3 (extracted for Flutter build)

Extracted in S2 (2026-11-22) from the Claude Design handoff bundle at
`C:\Users\gurch\OneDrive\Desktop\Projects\Maximus\Maximus_v1\mobile-app-design-scope\`.
This file is the single source for S4 (theme + components) and S5 to S9 (screens). If the bundle and this file disagree, the bundle wins, then log the fix here.

**Units.** Prototype CSS px = Flutter logical px (dp), 1:1.
**Read section 11 (Ambiguities) before S3/S4.** Several items need a decision from the owner.

---

## 0. Sources and what is canonical

| File (in `project/`) | Role | Status |
|---|---|---|
| `Maximus v3 All Pages.dc.html` | Board that renders every v3 screen, in order, dark theme | **Primary.** Defines the screen list (section 9) |
| `Maximus v3 App.dc.html` | The single prototype component all boards import. Holds all markup, styles, data and logic | **Canonical for every value in this spec** |
| `android-frame.jsx` | Device frame used by the prototype (412x892 bezel, 40 status bar, 24 gesture bar, 8 px border) | Frame only, not app UI |
| `support.js` | Claude Design runtime (React glue) | Not design. Ignore |
| `Maximus v3 Foundations.dc.html` | Token board: colour, type, spacing, radii, elevation, motion, component sheet | Canonical for **motion and elevation** (the prototype has neither). Some values differ from the App; App wins (section 11) |
| `Maximus v3 Overview.dc.html` | Screen map, token summary, behaviour rules, build notes | Behaviour reference |
| `Maximus v3 Start / Library / Learning.dc.html` | Same App screens, plus light-theme versions and "at the limit" states | Confirms light theme coverage |
| `Maximus v3 Logo Final.dc.html` | Final logo ("The disc"), lockups, app-icon variants | **Canonical logo** |
| `_ds/classical-*/` (readme, styles.css, manifest) | "Classical" design system: Cormorant Garamond + Lora, outlined buttons, 4 px radii | **Retired for v3.** Foundations says: "Classical's bronze accent is kept; its serif editorial layer is retired." Only the pre-v3 files use it. Only `#C8933A` (a lifted version of Classical `#b68235`) carries over |
| `Maximus App / Canvas / Screens / States / Mark.dc.html`, `v3 Logo`, `v3 Symbol 1-8`, `screenshots/*`, `uploads/*` | Pre-v3 drafts, logo exploration rounds, screenshots of the old Classical build, a screenshot of the Claude Design UI | Superseded. Not used |

---

## 1. Colour

Dark is the default. Light shares every role and the same structure.

### 1.1 Theme tokens (from `VARS` in the App file)

| Token (prototype var) | Role | Dark | Light |
|---|---|---|---|
| `color.bg` (`--bg`) | Screen background | `#0F0D0A` | `#F7F1E6` |
| `color.surface` (`--s1`) | Cards, sheets, bottom nav, read-aloud bar, idle quiz option | `#1A1611` | `#FFFFFF` |
| `color.surfaceRaised` (`--s2`) | Progress-bar tracks, AI chat bubble, explanation box, offline banner | `#262017` | `#EFE6D6` |
| `color.text` (`--tx`) | Main text | `#F4EDE0` | `#1C1710` |
| `color.textMuted` (`--mu`) | Secondary text, inactive nav | `#B5A998` | `#5E5445` |
| `color.accent` (`--ac`) | Accent **fill** (primary buttons, selected segments, user bubble) | `#C8933A` | `#C8933A` |
| `color.accentText` (`--acT`) | Accent used as **text/stroke** (links, active nav label, kickers, outlined Add button) | `#C8933A` | `#8A5A0C` |
| `color.accentContainer` (`--acA`) | Active nav pill background | `rgba(200,147,58,0.22)` | `rgba(200,147,58,0.25)` |
| `color.onAccent` (`--onAc`) | Text/icon on accent fill | `#1A1208` | `#1A1208` |
| `color.success` (`--ok`) | Right answer, quiz score tiles | `#6FCF8E` | `#1F7A45` |
| `color.successContainer` (`--okBg`) | Right-answer option fill | `rgba(111,207,142,0.14)` | `rgba(31,122,69,0.12)` |
| `color.error` (`--er`) | Wrong answer, "Clear my data" | `#FF8A7A` | `#B3392B` |
| `color.errorContainer` (`--erBg`) | Wrong-answer option fill | `rgba(255,138,122,0.14)` | `rgba(179,57,43,0.10)` |
| `color.divider` (`--dv`) | Borders, hairlines, unselected outlines | `rgba(244,237,224,0.12)` (12% of text) | `rgba(28,23,16,0.14)` (14% of text) |

### 1.2 Fixed colours (same in both themes; used on artwork or overlays)

| Use | Value |
|---|---|
| Image scrim (posters, hero, resume card, feed, mystery card) | linear gradient to top from `rgba(10,8,5,α)` to `rgba(10,8,5,0)`; α and stops per component |
| Text on artwork | `#F4EDE0` (titles/facts), `#E3D9C6` (celebration body) |
| Match badge | bg `rgba(15,13,10,0.9)`, text `#E7B25A` |
| Feed side buttons | bg `rgba(15,13,10,0.62)`, icon `#F4EDE0` |
| Feed topic tag | bg `rgba(15,13,10,0.8)`, text = topic tint |
| Sheet backdrop | `rgba(0,0,0,0.62)` |
| Celebration backdrop | `rgba(10,8,5,0.78)` |
| Selected-tile ring and tick badge | `#C8933A` ring 3 px (inset); tick badge `#C8933A` with `#1A1208` tick |
| Dark ink on tint buttons | `#140D07` (sheet Start), `#1A0805` (Resume pill, "Take the quiz"), `#1A1208` (hero Start, Go deeper). Treat all three as `onAccent #1A1208` (see 11.17) |
| Splash background | `#0F0D0A` in both themes |
| Confetti | `#E8553A`, `#C8933A`, `#F2C14E`, `#6C8CFF`, `#6FCF8E` (cycled) |
| Hairline on artwork | progress track on resume card `rgba(244,237,224,0.25)`; "Not now" border `rgba(244,237,224,0.3)`; sheet drag handle `rgba(244,237,224,0.7)` |

### 1.3 Per-topic colours

Each topic carries two colours (data, not theme):
- `bg`: the poster/banner/thumbnail background behind the artwork.
- `tint`: dominant hue of the art. Used for: resume-card kicker, progress fill and Resume pill; study-list progress bars; title-sheet Start button; topic header kicker and reader progress segments; "Take the quiz" button; feed topic tag text.
Foundations: tint is taken at lightness 60% for dark, 38% for light. The prototype uses one tint for both themes (see 11.9). Full table in section 8.1.

### 1.4 Contrast rules (from Foundations/Overview)
- Text over artwork always sits on a scrim; target 4.5:1.
- Accent as text on light uses `#8A5A0C`, never `#C8933A`.
- Right/wrong is never colour alone: always an icon plus a word ("Right", "Not quite", "Not this one").

---

## 2. Typography

### 2.1 Families and licences

| Family | Job | Weights used | Source | Licence |
|---|---|---|---|---|
| **Figtree** (Erik Kennedy) | All UI and reading text; also the "carved" poster lettering (Egypt etc.) and logo wordmark | 500, 600, 700, 800, 900 | Google Fonts | SIL Open Font License 1.1 |
| **Cinzel** (Natanael Gama) | "roman" poster/sheet titles (Roman, Greece, Renaissance, British, Byzantine, Persia, Crusades) | 700 | Google Fonts | SIL Open Font License 1.1 |
| **Caveat Brush** (Impallari Type) | "brush" titles (revolutions, Vikings, Mongols, Samurai...) | 400 (only weight) | Google Fonts | SIL Open Font License 1.1 |
| **Big Shoulders Stencil Display** (Patric King) | "stencil" titles (wars, Russian Revolution, Cold War) | 900 | Google Fonts | SIL Open Font License 1.1 |

OFL 1.1 allows bundling inside an app (free or paid). Obligations: ship the licence text with the app (register it in Flutter's licence page), do not sell the font files alone, and do not reuse the Reserved Font Name if you modify a font. Bundle the TTFs as assets (the app must work offline); do not fetch at runtime.
Verify at download (S4): Google Fonts has reorganised the Big Shoulders family into variable "Big Shoulders" / "Big Shoulders Stencil" families; pick the stencil cut at weight 900 / display optical size that matches.
Fallback in the prototype: `system-ui, sans-serif`.

### 2.2 Named scale (Foundations)

| Role | Size / line height | Weight | Notes |
|---|---|---|---|
| Display | 32 / 38 | 800 | "Pick what pulls you" |
| Title | 24 / 30 | 800 | |
| Heading | 20 / 26 | 700 | |
| Body | 16 / 24 | 500 | |
| Reader body | 18 / 29 | 500 | Default reader size |
| Label | 13 / 18 | 700 | Uppercase, +8% tracking |
| Caption | 12 / 16 | 600 | |

### 2.3 Styles actually used in the App (build these; App wins over 2.2)

Font is Figtree unless stated. `lh` = line-height multiplier.

| Token suggestion | Size | Weight | lh | Tracking | Where |
|---|---|---|---|---|---|
| `scoreXL` | 56 | 900 | 1.0 | | Quiz result score "4 out of 6" (accentText) |
| `heroTitle` | 40 | 900 | 0.95 | 0.06em, uppercase | Library featured title; text-shadow `0 3px 0 #1E0D05`, colour `#FBE2AE` |
| `display` | 34 | 900 | 1.05 | -0.01em | Sign-in title, "Topic finished" |
| `lessonTitle` | 30 | 900 | 1.08 | | Reader lesson title |
| `onboardTitle` | 28 | 900 | 1.1 | | All onboarding headings |
| `screenTitle` | 26 | 900 | 1.0 | -0.01em | "Good evening", "Study list", "Settings" |
| `question` | 26 | 900 | 1.15 | | Quiz question |
| `emptyTitle` | 24 | 900 | 1.15 | | "Nothing here yet" |
| `cardTitle` | 22 | 900 | 1.15 | | Resume card lesson title |
| `feedFact` | 22 | 800 | 1.28 | | Feed fact on artwork |
| `otdTitle` | 20 | 900 | 1.2 | | On this day title |
| `readerHeading` | 20 | 800 | 1.2 | | Reader sub-heads (margin 18 top, 6 bottom); quiz result message |
| `section` | 19 | 800 | 1.0 | | Home/Library row headings |
| `factCard` | 19 | 800 | 1.3 | | Mystery card fact |
| `option` | 18 | 800 | 1.25 | | Quiz/guess answer buttons |
| `groupTitle` | 18 | 800 | 1.0 | | Onboarding group name ("Ancient") |
| `feedbackHead` | 18 | 900 | 1.2 | | "Spot on!" / "Close, but no." |
| `buttonL` | 17 | 800 | 1.0 | | Primary buttons (56 tall) |
| `rowTitleL` | 17 | 800 | 1.2 | | Study tab row name, topic header subtitle |
| `buttonM` | 16 | 800 | 1.0 | | Secondary/outline buttons (52 tall), Add to study list |
| `rowTitle` | 16 | 800 | 1.2 | | Home study rows, "Chat is resting" |
| `listRow` | 16 | 700 | 1.0 | | Settings rows |
| `bodyL` | 16 | 500 | 1.45 | | Sheet brief, sign-in subtitle, celebration body |
| `input` | 16 | 500 | 1.0 | | Text inputs |
| `segment` | 15 | 800 | 1.0 | | Settings/onboarding segmented buttons, feed "Go deeper" |
| `body` | 15 | 500 | 1.45 | | Muted body, explanation box, On this day body |
| `chat` | 15 | 500 | 1.4 (user) / 1.45 (AI) | | Chat bubbles |
| `skip` | 15 | 700 | 1.0 | | "Skip" |
| `buttonS` | 14 | 800 | 1.0 | | Add/Added on match cards, Resume pill, match line on sheet |
| `chip` | 14 | 700 | 1.0 | | Suggested question chips, "Forgot password?", "Listen to this lesson" |
| `hint` | 14 | 600 | 1.3 | | Onboarding hint ("Pick 3 to 5...") |
| `labelCaps` | 13 | 800 | 1.0 | 0.12em to 0.14em, uppercase | Settings section labels, onboarding kicker ("GUESS THE YEAR") |
| `meta` | 13 | 700 | 1.0 | | "8 lessons · 48 min", "or with email" |
| `sub` | 13 | 600 | 1.3 | | Row subtitles, counts, score topic, rate note |
| `kicker` | 12 | 800 | 1.0 | 0.12em to 0.14em, uppercase | "CONTINUE · ROMAN EMPIRE", topic header kicker, "DID YOU KNOW" |
| `tileLabel` | 12 | 800 | 1.15 | | Onboarding tile names |
| `caption` | 12 | 600 | 1.3 | | Leader sub, read-aloud meta |
| `navLabel` | 12 | 600 (inactive) / 800 (active) | 1.0 | | Bottom nav and topic bar |
| `tag` | 12 | 700 | 1.0 | | "From lesson 4" chip |

Reader paragraph size follows the Text size setting: Small 16, **Medium 18 (default)**, Large 20; weight 500, lh 1.6, 10 bottom margin. The Text size setting only affects reader paragraphs and the sample text in the prototype.

### 2.4 Poster title lettering (per topic `kind`)

Poster titles are two centred lines (`l1`, `l2`), no wrap, lh 1.08. `w` = poster width; `len` = max(len(l1), len(l2), 4).

| kind | Font | Size | Tracking | Colour | Extra |
|---|---|---|---|---|---|
| `roman` | Cinzel 700 | min(0.115w, 0.9w / (len·0.86)) | 0.12em | `#F7E6C4` | shadow `0 1px 0 #000` |
| `brush` | Caveat Brush | min(0.21w, 0.9w / (len·0.5)) | | `#F7F0E0` | rotate -4°, shadow `0 2px 4px rgba(0,0,0,.7)` |
| `stencil` | Big Shoulders Stencil Display 900 | min(0.22w, 0.9w / (len·0.45)) | 0.04em | `#ECE9CC` | |
| `carved` | Figtree 900 | min(0.085w, 0.9w / len) | 0.26em | `#FBE2AE` | shadow `0 2px 0 #1E0D05` (incised look) |

Title sheet uses fixed sizes, colour = `color.text`, lh 1.05:
roman Cinzel 700 28, 0.1em · brush Caveat Brush 40, lh 1 · stencil BSSD 900 38, uppercase, 0.03em · carved Figtree 900 22, 0.22em, uppercase.

---

## 3. Spacing

Foundations scale (dp): **4, 8, 12, 16, 20, 24, 32, 48.**
The App also uses off-scale values often enough to keep as-is: 2, 6, 10, 14, 18, 22, 28, 36.

| Rule | Value |
|---|---|
| Screen side gutter | 20 (onboarding/login: 20 and 24) |
| Gap between Home/Library sections | 22 top margin |
| Section heading to content | 12 |
| Horizontal poster row gap | 12; row has 20 side padding and scrolls edge to edge |
| List gaps | Home study rows 12; Study tab rows 14; quiz options 10; chat messages 12; result rows 8 |
| Card padding | 12 (rows), 14 (score tiles), 18 (On this day, resting card, empty scores) |
| Top app bar height | 64 (login 72) |
| Bottom bars | nav/topic bar 68; read-aloud bar 48 button + padding 8/10 |
| Bottom CTA area | padding 12 top, 20 sides, 20 bottom (quiz: 12/20/12) |

---

## 4. Radii

Foundations names: **8 chip · 14 poster · 18 tile · 24 sheet · 999 button.** The App uses:

| Value | Used for |
|---|---|
| 3 | Progress bar ends (6 tall bars) |
| 4 | Quiz progress bar (8 tall); chat bubble tail corner |
| 10 | Posters (formula max(10, 0.075·w), so 10 at 112 to 128 wide, about 12.75 at 170) |
| 14 | Thumbnails (64), quiz review rows, drag handle 3 |
| 15 | Nav pill (56x30), feed tag (30 tall) |
| 16 | Onboarding/leader tiles, inputs, explanation box, bottom-bar top corners |
| 18 | Quiz options, score tiles, empty-scores box, theme preview cards, resting card |
| 20 | Reader hero image, Study tab rows, chat bubbles (big corners), guess-the-year image |
| 22 | Resume card, On this day card |
| 24 | Empty-state art, mystery card |
| 28 | Bottom sheet top corners |
| full (h/2) | Every button, chip, pill, badge, circle icon button |

---

## 5. Elevation and shadows

From Foundations (the App prototype draws no box shadows):

| Level | Shadow | Use |
|---|---|---|
| L0 | none; depth from surface steps (`bg` → `surface` → `surfaceRaised`) + 1 px divider borders | Everything by default |
| L1 | `0 2 8 rgba(0,0,0,.45)` | Feed side controls |
| L2 | `0 12 32 rgba(0,0,0,.6)` | Bottom sheet |

Text shadows: see 2.4 (poster lettering) and hero title (`0 3px 0 #1E0D05`, "Featured" `0 2px 0 #1E0D05`).

---

## 6. Motion

Principle: "Soft, quick, never blocking. Reduced motion replaces every move with a fade." (Foundations). Prototype implements only the tile/rating scale transitions and the splash timer; the rest are specified in Foundations.

| Motion | Spec |
|---|---|
| Splash | Auto-advance after **1500 ms** (tap also advances). FLOW.md: logo animates during it (animation not designed) |
| Poster row parallax | Artwork shifts 6% against the card as the row scrolls; no delay |
| Added pop | Button fills with bronze, icon swaps plus → tick, scale 1 → 1.08 → 1 over **220 ms** |
| Match % count-up | 0 → value over **700 ms**, ease-out, once per appearance |
| Tile pop (onboarding topic/leader select) | Scale to **1.04** (App; Foundations says 1.06) and settle, tick fades in, **180 ms** |
| Rating button select | Scale 1.08, 180 ms |
| Answer bounce | Right: small upward bounce + tick. Wrong: 6 px horizontal nudge + cross. No sound by default |
| Finish celebration | Confetti pieces (App draws 36; Foundations says thirty) in bronze and poster tints drift down for **1.6 s**, then stop. No counters |
| Feed | Vertical snap scrolling, one card per page (`scroll-snap-stop: always`) |
| Bottom sheet | Not specified. Use a standard slide-up with backdrop fade |
| Reduced motion | Replace every movement with a fade |

---

## 7. Components

Global: minimum touch target **48 dp**; primary buttons 56, secondary 52. No hover/pressed/focus states are designed (see 11.14).

### 7.1 Buttons

| Component | Size | Style | States |
|---|---|---|---|
| **Primary** | h56, full width, radius 28 | bg `accent`, text `onAccent`, `buttonL`; optional leading icon, gap 8 | Enabled; **disabled = opacity 0.4**, tap does nothing |
| **Secondary (outline neutral)** | h52, full width, radius 26 | 2 px `divider` border, transparent, text `color.text`, `buttonM` | "Review lessons you missed", login provider buttons (h56) |
| **Accent outline** | h52, radius 26 | 2 px `accentText` border, transparent, text `accentText`, `buttonM`, icon 22 | Title sheet "Add to study list" (plus icon) ↔ "Added to study list" (tick icon); `aria-pressed` |
| **Add (match card)** | h48, full width, radius 24, `buttonS`, icon 18 | Not added: bg `accent`, text `onAccent`, plus icon, "Add". Added: 2 px `accentText` border, transparent, `accentText`, tick icon, "Added" | Toggle |
| **Tint button** | h56, radius 28, `buttonL`, text `#140D07`/`#1A0805` | bg = topic tint, play icon 18 | Title sheet Start/Continue; "Take the quiz" (no icon) |
| **Pill CTA on art** | Resume: h40, radius 20, pad 0 16, tint bg, 800 14, play 14. Hero Start: h48, radius 24, pad 0 22, tint bg, 800 16, play 16. Go deeper: h48, radius 24, pad 0 20, bg `#C8933A`, 800 15, trailing arrow 18 | | |
| **Text button** | h48 | transparent; "Skip" 700 15 `textMuted`; "Forgot password?" 700 14 `accentText`; toggle link 800 15 `accentText` | |
| **Icon button** | 48x48, transparent, icon 24 (`color.text`) | Back, Settings, Remove (X, 20, muted), prev/next lesson (22) | |
| **Circle icon (filled)** | 48 (read aloud, play 20) or 52 (chat send, icon 22); bg `accent`, icon `onAccent` | | |
| **Feed action** | 52 circle, bg `rgba(15,13,10,.62)`, icon 24 `#F4EDE0` | Save, Like, Dislike. Active state not designed (11.14) | |

### 7.2 Segmented choice (settings, onboarding group toggle)
- Row of buttons, gap 8. Each: h48 (group toggle h44, `flex:none`, pad 0 18), radius full, `segment` text.
- **Selected:** bg `accent`, 2 px `accent` border, text `onAccent`. **Unselected:** transparent, 2 px `divider` border, text `color.text`. `aria-pressed`.

### 7.3 Poster card (2:3)
- Size w × 1.5w (w = 128 Home "For you", 126 Library rows, 170 first-matches grid, 112 alt). Radius max(10, 0.075w). bg = topic `bg`; artwork fills, anchored top (`xMidYMin slice`). Hero topics use art viewBox `0 0 200 300`, others `0 -20 100 150`.
- Scrim at bottom: padding top 0.26w, sides 0.04w, bottom 0.07w; gradient to top `rgba(10,8,5,.9)` at 22% → 0.
- Two title lines in the topic lettering (2.4).
- **Match badge**: top-left 8/8, h max(24, 0.14w), pad 0 9, radius full, bg `rgba(15,13,10,.9)`, text `#E7B25A` 800 max(12, 0.08w). Copy "94% match" (rows) or "96%" (first matches).
- Tap opens the title sheet. Accessible label `l1 + l2`.

### 7.4 Hero banner (Library "Featured")
- Full width, h430, no radius, bg topic bg, art viewBox `0 40 200 240` cover.
- Scrim to top `rgba(10,8,5,.96)` 6% → 0 at 60%.
- Bottom block inset 20: "FEATURED" Figtree 900 15, 0.34em, `#FBE2AE`, shadow; title `heroTitle` two lines; brief 500 15/1.4 `#F4EDE0`, 14 below; Start pill.
- Whole banner is tappable (opens the title sheet).

### 7.5 Resume card (Home)
- h190, radius 22, bg topic bg, art viewBox `0 70 200 130` cover. Scrim `rgba(10,8,5,.94)` 8% → 0 at 70%.
- Inset 18 sides, 16 bottom: kicker "CONTINUE · ROMAN EMPIRE" in tint; title `cardTitle` `#F4EDE0`; row of progress bar (flex, h6, track `rgba(244,237,224,.25)`, fill tint) and Resume pill, gap 12.
- Tap: opens the topic reader at the current lesson.

### 7.6 Study row
- **Home variant:** no card; thumb 64 radius 14 (topic art, `tv` crop) · name `rowTitle` · sub `sub` muted ("Lesson 4 of 8" or "Not started"), 2 top / 8 bottom · progress bar h6 radius 3, track `surfaceRaised`, fill tint.
- **Study tab variant:** card pad 12, radius 20, `surface`, 1 px divider; name 17; trailing remove button (X 20, muted, 48 target, label "Remove <title>"). Row tap opens the title sheet.

### 7.7 Progress bars
- Thin: h6 radius 3 (rows, resume, onboarding steps, reader segments). Quiz: h8 radius 4, fill `accent`.
- Onboarding step bar: 4 equal segments, gap 6; filled `accent` up to the current step, rest `surfaceRaised`.
- Reader lesson bar: one segment per lesson (8), gap 6; done = tint, current = half tint / half `surfaceRaised` (hard stop at 50%), future = `surfaceRaised`.

### 7.8 Bottom navigation and topic bar
- h68, bg `surface`, 1 px top divider, top radius 16. Items share width equally.
- Item: icon 22 inside a 56x30 pill (radius 15), label below, gap 4, `navLabel`.
- **Active:** pill bg `accentContainer`, icon and label `accentText`, label 800. **Inactive:** no pill fill, `textMuted`, 600.
- Main tabs: Home, Library, Feed, Study. Shown only on those four screens.
- Topic bar (inside a topic): Lessons, Chat, Quiz. Replaces the main nav.

### 7.9 Top app bars
- **Tab screens:** h64, pad 0 12 0 20; Home = logo 30 + "Good evening" with Settings icon button right; Study = "Study list" only. Library and Feed have no top bar.
- **Pushed screens (Settings, Topic):** h64, pad 0 12 0 4, Back icon button (48). Settings: title "Settings" `screenTitle`. Topic: two lines, kicker topic name in tint (800 12, 0.12em, caps) + `rowTitleL` subtitle ("Lesson 4 of 8" / "Ask a question" / "Quiz").
- **Onboarding:** h64, pad 0 8 0 20; step bar (flex) + Skip text button, gap 14.

### 7.10 Title bottom sheet
- Modal over the current screen; backdrop `rgba(0,0,0,.62)`, tap backdrop to close. Sheet max height 96%, scrolls; top radius 28; bg `surface`; 1 px divider border; L2 shadow.
- Banner h200 (topic bg + art `bv` crop, cover) with drag handle 44x5 at top 10.
- Content pad 18 20 22, gap 12:
  1. Match line: "94% match" 800 14 `accentText` + reason 500 13 muted ("because you liked Ancient Greece" / "because of what you picked").
  2. Title in topic lettering (2.4 sheet sizes).
  3. Brief, `bodyL`.
  4. Meta "8 lessons · 48 min", `meta` muted.
  5. Rating row: three 52 circles (gap 10) + note.
  6. Start/Continue tint button (play icon).
  7. Add to study list accent-outline button.
- **Rating buttons:** 52 circle, 2 px divider border, transparent, icon 24 (`color.text`): thumbs-up "Like", minus "It is okay", thumbs-down "Not for me". **Selected:** bg `accent`, border `accent`, icon `onAccent`, scale 1.08. Single choice per topic.
- **Rate note copy:** none → "How does it look?"; up → "Noted. Similar topics move up."; okay → "Noted."; down → "Noted. You will see less like this."
- States designed: 09a not added · 09b Added · 09c Rated (match % on other posters behind the sheet moves).

### 7.11 Onboarding topic tile
- Grid 3 columns, gap 10, row height 112. Tile radius 16, topic bg + art (`tv` crop), label scrim (pad 18 6 7, gradient `rgba(10,8,5,.9)` → 0) with `tileLabel` `#F4EDE0`, centred.
- **Selected:** inset 3 px ring `#C8933A`, scale 1.04, tick badge (26 circle, `#C8933A`, tick 16, stroke 2.6, `#1A1208`) top-right 6/6.
- **Capped** (limit reached and not selected): opacity 0.4, tap ignored.
- Group header above each grid: name `groupTitle` + count "5 topics" `sub` muted, baseline aligned, margin 16 top 10 bottom.

### 7.12 Leader tile
- Grid 3 columns, gap 14 vertical / 10 horizontal. Art block h104, radius 16, leader bg + portrait (viewBox 0 0 100 100). Below: name 800 14/1.2, sub `caption` muted ("Rome · Ancient"). Gap 6.
- Selected / capped exactly as 7.11.

### 7.13 Answer option (quiz and guess-the-year)
- min h60, pad 8 18, radius 18, 2 px border, gap 12, `option` text, full width; text left, feedback right.
- **Idle:** bg `surface`, border `divider`. **Right:** bg `successContainer`, border `success`, trailing tick 20 + "Right" (800 13, `success`). **Wrong (picked):** bg `errorContainer`, border `error`, trailing cross 20 + "Not quite" (quiz) / "Not this one" (guess). After answering, the correct option shows Right and other options stay idle; further taps ignored.
- Explanation box after answering: margin-top 14, pad 14 16, radius 16, `surfaceRaised`, `body`.

### 7.14 Chat
- **User bubble:** right-aligned, max 80% width, pad 12 16, radius 20 20 4 20, bg `accent`, text `onAccent`, `chat`.
- **Assistant bubble:** left-aligned, max 88%, pad 12 16, radius 20 20 20 4, bg `surfaceRaised`, text `color.text`; optional source chip inside, gap 8.
- **Source chip:** h28, pad 0 10, radius 14, 1 px `accentText` border, `accentText`, book icon 14 + "From lesson 4" (`tag`). FLOW: tapping jumps to that lesson.
- **Suggestion chip:** h44, pad 0 16, radius 22, 2 px divider border, transparent, `chip`, no wrap; horizontal scroll row, gap 8, pad 8 20 4. Disabled (resting): opacity 0.4, taps ignored.
- **Composer:** field h52 radius 26, 2 px divider border, pad 0 18, placeholder "Ask about the Roman Empire" (500 15, muted); send button 52 circle `accent`, send icon 22. Row pad 8 16 12, gap 10.
- **Resting card:** pad 18, radius 18, `surface`, divider border; moon icon 28 `accentText`; "Chat is resting" (`rowTitle`) / "It has answered a lot today. Back tomorrow." (500 14/1.4 muted).
- **Offline banner:** full width under the header, pad 10 20, bg `surfaceRaised`, wifi-off icon 18 + "You are offline. Chat needs a connection." (600 14/1.3).

### 7.15 Score tile and dashboard tile
- **Quiz score tile (Home):** flex 1 (two side by side, gap 10), pad 14, radius 18, `surface`, divider border; score 900 28 `success` ("5/6"); topic `sub` muted, 4 above.
- **Empty scores:** pad 18, radius 18, **2 px dashed** divider border, question-circle icon 32 + "No quizzes yet. Finish a topic and your scores land here." (600 15/1.4, muted).
- **Dashboard tiles (Foundations only, not placed on any v3 screen):** three across, pad 14, radius 18, `surface`, divider border, gap 2; value 900 30 (accent / success / text) + label `sub` muted: "3 topics in progress", "82% best quiz score", "12 lessons read". See 11.6.

### 7.16 Info card (On this day)
Pad 18, radius 22, `surface`, divider border. Kicker "ON THIS DAY · 21 NOVEMBER" (800 12, 0.14em, `accentText`), title `otdTitle`, body 500 15/1.45 muted.

### 7.17 Feed card
- Full height of the area above the nav (744 dp in the frame), full width, snap page. Topic bg + art cover (hero viewBox `0 0 200 300`, others `0 -20 100 150`).
- Scrim `rgba(10,8,5,.94)` 18% → 0 at 58%.
- Topic tag top-left 20/20: h30, pad 0 12, radius 15, bg `rgba(15,13,10,.8)`, text tint 800 13.
- Bottom-left block (left 20, right 84, bottom 22, gap 14): fact `feedFact` `#F4EDE0`; "Go deeper" pill.
- Right column (right 12, bottom 22, gap 8): Save (bookmark), Like (thumb up), Dislike (thumb down).

### 7.18 Theme preview card (onboarding)
Two cards in a 2-column grid, gap 12. Card pad 8, radius 18, 3 px border (`accent` when selected, else `divider`). Inside: mini preview h128, radius 10, pad 12, gap 6 in that theme's colours: block h56 radius 6 `#E8553A`; line h8 70% text colour; line h8 45% muted colour; pill h14 w50 radius 7 `#C8933A` pinned to bottom. Label row below (pad 12 2 2): moon/sun icon 18 + "Dark"/"Light" 800 15.

### 7.19 Text input
h56, full width, radius 16, 2 px divider border, transparent, pad 0 16, `input`, placeholder muted. Focus/error states not designed (11.14).

### 7.20 Settings list row
min h60, space-between, 1 px top divider (last row also bottom), `listRow` label left, value right (600 15 muted) or chevron/arrow 20 muted. Destructive row: label 800 16 `error`, right hint 600 13/1.3 muted.

### 7.21 Celebration overlay
Over the topic screen (z above everything). bg `rgba(10,8,5,.78)`, centred column, pad 0 32, gap 14. Confetti layer behind text. Title `display` 34 `#F4EDE0`; body 500 16/1.45 `#E3D9C6`; buttons (gap 8, margin-top 8): tint button "Take the quiz", outline "Not now" (h52, 2 px `rgba(244,237,224,.3)`, `#F4EDE0`).

### 7.22 Read-aloud bar
Pinned under the lesson scroll, above the topic bar. pad 8 12 10 16, gap 8, bg `surface`, 1 px top divider. Play circle 48 (`accent`, play 20) · text column ("Listen to this lesson" 700 14/1.2; "About 3 min · 1x speed" 600 12/1.3 muted) · Previous lesson (chevron 22) · Next/Finish (mirrored chevron 22). Playing/paused states not designed (11.14).

### 7.23 Empty state
Centred column, pad 0 36 60, gap 18: art 150x150 radius 24 · title `emptyTitle` · body 500 15/1.45 muted · full-width primary button.

---

## 8. Content data used by the design

The prototype's topic and leader sets are **placeholders that do not match `docs/TOPICS.md`** (see 11.4). Colours, crops and lettering kinds below are still the design values to reuse.

### 8.1 Topics (30 in prototype)

`hero` = detailed 200x300 illustration (4 of them); others are simple motifs. `base` = prototype starting match %. `grp` = rating group (a ancient, m medieval/early modern, r revolutions, w wars, e empire/India).

| id | Poster lines | Tile name | kind | bg | tint | base | grp | Era | Region | Lessons · min | Brief |
|---|---|---|---|---|---|---|---|---|---|---|---|
| roman (hero) | ROMAN / EMPIRE | Roman history | roman | #2B0E0C | #E8553A | 94 | a | Ancient | Europe | 8 · 48 | From a village on seven hills to the biggest empire of the ancient world. |
| greece | ANCIENT / GREECE | Ancient Greece | roman | #1E3A5F | #6FB1E0 | 91 | a | Ancient | Europe | 7 · 40 | City-states, philosophers, and the first democracy. |
| egypt (hero) | ANCIENT / EGYPT | Ancient Egypt | carved | #F0B35A | #E8A33D | 88 | a | Ancient | Middle East and Africa | 9 · 52 | Pharaohs, pyramids and 3,000 years of one river. |
| mongol | The Mongol / Empire | Mongol Empire | brush | #D9A441 | #B5481F | 79 | m | Medieval | Asia | 6 · 34 | Horse archers who built the largest land empire in history. |
| vikings | The / Vikings | Vikings | brush | #12303A | #7FC3D1 | 86 | m | Medieval | Europe | 6 · 32 | Raiders, traders and explorers from the north. |
| renaissance | THE / RENAISSANCE | Renaissance | roman | #6B2D2D | #E8B27A | 83 | m | Early modern | Europe | 7 · 38 | Art, science and big ideas reborn in Italy. |
| ottoman | OTTOMAN / EMPIRE | Ottoman Empire | carved | #0F4C4A | #F2C14E | 74 | m | Early modern | Middle East and Africa | 7 · 40 | Six centuries of sultans, from Istanbul to the Balkans. |
| mughal | MUGHAL / EMPIRE | Mughal Empire | carved | #7A2E3B | #F0A8B0 | 72 | m | Early modern | Asia | 6 · 34 | Emperors, gardens and the Taj Mahal. |
| american | The American / Revolution | American Revolution | brush | #1B2A52 | #7C9CFF | 80 | r | Early modern | Americas | 6 · 34 | Thirteen colonies, one big argument about taxes. |
| french (hero) | The French / Revolution | French Revolution | brush | #E9D9B2 | #6C8CFF | 85 | r | Early modern | Europe | 7 · 42 | A king falls, a republic rises, and the guillotine gets busy. |
| napoleon | Napoleon / (blank) | Napoleon | brush | #1F2A44 | #E2B65A | 82 | r | Modern | Europe | 6 · 36 | From artillery officer to emperor of France. |
| russian | RUSSIAN / REVOLUTION | Russian Revolution | stencil | #7A1414 | #F2C14E | 70 | r | Modern | Europe | 6 · 34 | 1917: the tsar goes and the world looks different. |
| industrial | INDUSTRIAL / REVOLUTION | Industrial Revolution | carved | #3A3F44 | #D9A441 | 68 | r | Modern | Europe | 6 · 34 | Steam, iron and the first factories. |
| civilwar | AMERICAN / CIVIL WAR | American Civil War | stencil | #26324D | #9DB2D6 | 71 | w | Modern | Americas | 7 · 40 | A nation splits over slavery and fights for four years. |
| ww1 | WORLD / WAR I | WW1 | stencil | #4A4232 | #E06A4F | 77 | w | Modern | Global | 7 · 42 | Trenches, alliances and a war nobody expected to last. |
| ww2 (hero) | WORLD / WAR II | WW2 | stencil | #1B261F | #B8C25A | 81 | w | Modern | Global | 9 · 54 | Six years, dozens of countries, and a changed world. |
| coldwar | COLD / WAR | Cold War | stencil | #14213D | #8FD3F0 | 73 | w | Modern | Global | 7 · 38 | Two superpowers, no direct war, and a race to space. |
| indian | Indian / Independence | Indian independence | brush | #F08A24 | #2B8A4A | 69 | e | Modern | Asia | 6 · 36 | Marches, boycotts and the end of British rule in 1947. |
| british | BRITISH / EMPIRE | British Empire | roman | #1C2E4A | #E06A6A | 75 | e | Modern | Global | 7 · 40 | How a small island came to run a quarter of the world. |
| ancientindia | ANCIENT / INDIA | Ancient India | carved | #8A3B12 | #F2A64A | 78 | a | Ancient | Asia | 7 · 40 | Cities on the Indus, empires on the Ganges. |
| maya | THE / MAYA | The Maya | carved | #1F3A2A | #E8C547 | 66 | m | Medieval | Americas | 6 · 34 | Pyramids, calendars and city-states in the jungle. |
| aztec | AZTEC / EMPIRE | Aztec Empire | carved | #5A1F12 | #E8A33D | 67 | m | Medieval | Americas | 6 · 34 | A lake city that ruled central Mexico. |
| inca | INCA / EMPIRE | Inca Empire | carved | #1E3326 | #F2C14E | 64 | m | Medieval | Americas | 6 · 32 | An empire strung along the Andes by roads and bridges. |
| byzantine | BYZANTINE / EMPIRE | Byzantine Empire | roman | #3A1A5A | #E8C547 | 70 | m | Medieval | Europe | 7 · 38 | The Roman Empire that lasted another thousand years in the east. |
| persia | PERSIAN / EMPIRE | Persian Empire | roman | #0F3B5A | #E8C547 | 72 | a | Ancient | Middle East and Africa | 6 · 34 | The first great empire to span three continents. |
| samurai | The Age of / Samurai | Samurai Japan | brush | #1A1A22 | #E06A6A | 74 | m | Medieval | Asia | 6 · 36 | Warlords, castles and a code of honour. |
| mali | MALI / EMPIRE | Mali Empire | carved | #B5661E | #F2C14E | 65 | m | Medieval | Middle East and Africa | 5 · 30 | Gold, Timbuktu and the richest ruler of his age. |
| crusades | THE / CRUSADES | The Crusades | roman | #2A2F4A | #E06A6A | 69 | m | Medieval | Europe | 6 · 36 | Two centuries of campaigns for the Holy Land. |
| ming | MING / DYNASTY | Ming China | carved | #0F2A4A | #8FB6FF | 71 | m | Early modern | Asia | 6 · 34 | Porcelain, treasure fleets and the Great Wall rebuilt. |
| zulu | The Zulu / Kingdom | Zulu Kingdom | brush | #3A2A12 | #E8A33D | 63 | r | Modern | Middle East and Africa | 5 · 30 | Shields, spears and a kingdom built by Shaka. |

Art crops (SVG viewBox): poster `0 0 200 300` (hero) / `0 -20 100 150`; onboarding tile `tv` (roman `20 40 160 160`, egypt `20 90 160 160`, french `20 120 160 160`, ww2 `20 60 160 160`, else `0 0 100 100`); sheet banner `bv` (roman `0 70 200 100`, egypt `0 100 200 100`, french `0 110 200 100`, ww2 `0 90 200 100`, else `0 12 100 50`).
Era groups order: Ancient, Medieval, Early modern, Modern. Region groups order: Europe, Middle East and Africa, Asia, Americas, Global.

### 8.2 Leaders (12 in onboarding)

| id | Name | Sub | Art bg | Linked topic |
|---|---|---|---|---|
| caesar | Julius Caesar | Rome · Ancient | #2B0E0C | roman |
| cleopatra | Cleopatra | Egypt · Ancient | #14425A | egypt |
| alexander | Alexander the Great | Macedon · Ancient | #1B2A52 | greece |
| ashoka | Ashoka | India · Ancient | #1E4A3A | ancientindia |
| genghis | Genghis Khan | Mongolia · Medieval | #3A4A2A | mongol |
| suleiman | Suleiman | Ottoman · Early modern | #0F4C4A | ottoman |
| akbar | Akbar | India · Early modern | #7A2E3B | mughal |
| elizabeth | Elizabeth I | England · Early modern | #4A1A3A | british |
| catherine | Catherine the Great | Russia · Early modern | #3A1F5A | russian |
| napoleon | Napoleon | France · Modern | #243A5A | napoleon |
| lincoln | Abraham Lincoln | USA · Modern | #2A2F3A | civilwar |
| churchill | Winston Churchill | Britain · Modern | #14213D | ww2 |

### 8.3 Sample content (Roman Empire is the only topic with lessons, chat and quiz)

**Lesson 4 of 8, "Why the Republic fell"** (hero art 210 tall, roman, viewBox `0 60 200 150`):
- *Armies with their own loyalty:* For centuries, Roman soldiers were citizens who went home after a war. That changed when generals began to pay and reward their own troops.
- *Caesar crosses the line:* In 49 BCE Julius Caesar led his army over the Rubicon. Doing that was treason. He won the civil war that followed.
- *One man in charge:* After Caesar was killed in 44 BCE, another civil war began. Octavian won it and was given the name Augustus. The Republic was over, though the Senate still met.

**Quiz bank (6):**
1. Who was the first Roman emperor? Julius Caesar / **Augustus** / Nero / Trajan. "Octavian took the name Augustus in 27 BCE."
2. Which city did Rome fight in the Punic Wars? Athens / Sparta / **Carthage** / Alexandria. "Carthage, in North Africa, was destroyed in 146 BCE."
3. What was the Colosseum mainly used for? Senate meetings / **Gladiator games** / A market / A library. "It held about 50,000 people for games and shows."
4. In which year did Julius Caesar die? **44 BCE** / 31 BCE / 100 BCE / 14 CE. "He was stabbed on the Ides of March, 15 March 44 BCE."
5. Which language did most Romans speak? Greek / Etruscan / **Latin** / Italian. "Latin. Italian grew out of it much later."
6. Which wall marked the north of Roman Britain? Offa's Dyke / **Hadrian's Wall** / The Great Wall / Antonine Gate. "Hadrian's Wall ran about 73 miles across northern England."

**Chat suggestions and canned replies:**
- "Why did the Republic fall?" → "Mostly because generals began to command armies that were loyal to them, not to Rome." [From lesson 4]
- "Who was Augustus?" → "Rome's first emperor. He ruled from 27 BCE until 14 CE." [From lesson 4]
- "What is the capital of France?" → "I only know about the Roman Empire." (no tag)
- Opening message: "Ask me anything about the Roman Empire."

**Feed facts (3):**
- Roman Empire: "Roman concrete set underwater, which is why some Roman harbours still stand."
- French Revolution: "The guillotine was proposed as a gentler way to carry out an execution."
- World War II: "The Blitz bombed London on 57 nights in a row." (Foundations wording differs: "The Blitz lasted 57 nights in a row and hit London every single time." Use the App wording; fact-check either way.)

---

## 9. Screens

Frame: content area **396 × 812 dp** inside the Android status bar (40) and gesture bar (24) (the 412 × 892 frame has an 8 px border; see 11.16). Every screen exists in dark and light; the token swap is the only difference unless noted.
Numbering follows the All Pages board.

### 1 · Getting started

**1.1 Splash** (`splash`)
- Full screen `#0F0D0A` (both themes). Logo mark 168 × 168, `#C8933A`, centred. No text.
- Whole screen is a button (label "Continue"). Auto-advances to Sign in after 1.5 s.

**1.2 Sign in** (`login`, mode in) and **1.3 Create account** (`loginUp`, mode up)
- Scroll column, bg `bg`, pad 0 24 20.
- Header h72: logo mark 40 `accent`.
- Title (`display`, margin 8 0 8): "Welcome back" / "Create your account".
- Subtitle (`bodyL` muted, 22 below): "Sign in to pick up where you left off." / "Save your study list and pick up where you left off on any device."
- Provider buttons (outline neutral h56, gap 10): "Continue with Google", "Continue with Apple". No provider logos drawn.
- Divider row (margin 18 0, gap 12): hairline, "or with email" (700 13 muted), hairline.
- Inputs (gap 12): [create only] "Your name"; "Email"; "Password".
- [sign in only] "Forgot password?" text button, left aligned.
- Spacer, then primary button: "Sign in" / "Create account".
- Footer (centred, 6 above): "New to Maximus?" + link "Create an account" / "Already have an account?" + link "Sign in" (toggles mode).
- All buttons just advance (mock). **Conflicts with "no accounts in v1"** (11.1).

**1.4 What are you into? By era** (`ob3`), **1.5 By region** (`ob3region`), **1.6 5 of 5 topics** (`ob3full`)
- Onboarding header, step 1 of 4 filled.
- Fixed top block (pad 0 20): title "What are you into?" · hint (dynamic, below) · group toggle "By era" | "By region" (margin-top 12).
- Scrolling grid area (pad 4 20 8): one group per era (or region), each with header and 3-column topic tiles (7.11).
- Bottom CTA: primary button.
- Rules: pick 3 to 5. Hint copy: 0 to 2 picked "Pick 3 to 5 · N of 5 picked"; 3 or 4 "N of 5 picked. Add up to M more."; 5 "5 of 5 picked. Remove one to swap." Button: under 3 "Pick N more" (disabled); 3+ "Next". At 5, other tiles dim to 0.4 and ignore taps until one is removed.

**1.7 Favourite leader** (`leader`), **1.8 3 of 3 leaders** (`leaderFull`)
- Onboarding header, step 2 of 4.
- Title "Who is your favourite leader?"; hint "Pick up to 3 · N of 3 chosen".
- Scrolling 3-column grid of 12 leader tiles (7.12), pad 16 20 8.
- Primary "Next", disabled until 1 is chosen. At 3, others dim and ignore taps.

**1.9 Your first matches** (`ob4`)
- Onboarding header, step 3 of 4.
- Title "Your first matches"; sub "Because you chose Julius Caesar, Cleopatra." (leader names joined with ", ") or "Based on what you picked." if no leaders.
- Scrolling 2-column grid (gap 18 12, pad 16 20 8) of 6 match cards: poster (w170, badge "96%") + Add button (7.1) below, gap 10.
- Ranking: chosen leaders' linked topics first, then picked topics by base score, then all topics by base. Prototype shows fixed values 96, 93, 90, 87, 84, 81.
- Primary "Continue" (always enabled).

**1.10 Light or dark?** (`ob5`)
- Onboarding header, step 4 of 4.
- Title "Light or dark?" (16 below), two theme preview cards (7.18). Tapping switches the whole app theme live.
- Primary "Start exploring" → Home.
- Overview/FLOW say this step also sets text size; the v3 screen has no size control (11.3).

Skip (every onboarding step) → Home immediately, and adds Roman Empire to the study list (prototype rule).

### 2 · Home, library, study

**2.1 Home** (`home`) and **2.2 Home, no quizzes yet** (`home` + `homeEmpty`)
- Bottom nav (Home active). Scroll column, bottom padding 20.
- Top bar: logo 30 (`#C8933A`) + "Good evening"; Settings icon button right (label "Settings").
- Resume card (7.5), side padding 20: "Continue · Roman Empire", "Lesson 4: Why the Republic fell", 50% progress, "Resume".
- "Your study list": first 2 study rows (Home variant). Sample: Roman history "Lesson 4 of 8" 50%; Ancient Greece "Lesson 2 of 7" 25%.
- "For you": poster row w128 (Roman, Egypt, WW2, Greece) with match badges.
- "Your quiz scores": two score tiles ("5/6" Roman Empire, "4/6" Ancient Greece). **Empty state (2.2):** dashed box "No quizzes yet. Finish a topic and your scores land here."
- On this day card: "On this day · 21 November" / "1783: the first free balloon flight" / "Two men rose over Paris in a hot-air balloon and landed 25 minutes later."
- Taps: resume → Reader; poster → title sheet; settings → Settings. Study rows on Home are not tappable in the prototype (11.12).

**2.3 Library** (`library`)
- Bottom nav (Library active). Scroll column. No top bar; the hero starts at the top.
- Hero banner (7.4): Featured, "Ancient / Egypt", brief, "Start". Tap opens the Egypt sheet.
- Poster rows (w126): "For you" (Roman, Egypt, Greece, Vikings) · "Ancient" (Roman, Greece, Egypt, Ancient India) · "Revolutions" (French, American, Russian, Industrial) · "Wars" (WW1, WW2, Civil War, Cold War) · "India and Empire" (Indian independence, Mughal, British, Ancient India).
- Any poster → title sheet. No search (Overview: not built).

**2.4 Title sheet** (`sheetAdded`; also `sheet` not-added state on the Library board) and **2.5 Rated: matches update** (`sheetRated`)
- Library behind, sheet over it (7.10). Roman example: "94% match · because you liked Ancient Greece", ROMAN EMPIRE (Cinzel), brief, "8 lessons · 48 min", rating, "Continue" (if added) / "Start", "Added to study list" / "Add to study list".
- 2.5: Ancient Greece rated up, so same-group posters behind show +4.
- Start/Continue → Reader. Close by tapping the backdrop. Swipe-down dismiss implied by the handle.
- In the prototype only Roman opens lessons; other topics show "Lessons are in the full app" on a 55%-opacity Start button (prototype-only copy, do not build).

**2.6 Study list** (`study`) and **2.7 Study list, empty** (`studyEmpty`)
- Bottom nav (Study active). Top bar "Study list".
- List (pad 0 20, gap 14) of Study-tab rows (7.6): Roman history (Lesson 4 of 8, 50%), Ancient Greece (Lesson 2 of 7, 25%), Ancient Egypt (Not started).
- Row tap → title sheet; X → remove (label "Remove Roman history").
- Empty (2.7): Greece art tile, "Nothing here yet", "Add a topic from the library and it will wait for you here.", primary "Browse the library" → Library.

**2.8 Feed** (`feed`)
- Bottom nav (Feed active). Full-height snap pager of feed cards (7.17), 3 sample cards.
- "Go deeper" opens the title sheet in the prototype (FLOW says it opens the lesson; 11.12). Save/Like/Dislike have no behaviour in the prototype.

### 3 · Inside a topic

Topic shell: top bar with Back + kicker "ROMAN EMPIRE" (tint) + subtitle; content; topic bar (Lessons, Chat, Quiz). No main nav. Back returns to where the topic was opened from.

**3.1 Lesson reader** (`reader`)
- Subtitle "Lesson 4 of 8". Lesson segment bar (8 segments) under the header, pad 0 20 10.
- Scroll area (pad 0 20): hero 210 tall radius 20; lesson title (`lessonTitle`, margin 20 0 14); sub-heads (`readerHeading`) and paragraphs (reader size setting); 16 spacer.
- Read-aloud bar (7.22): "Listen to this lesson" / "About 3 min · 1x speed" (speed label follows the setting: "0.8x speed", "1x speed", "1.2x speed").
- Previous → previous lesson. Next on the last lesson ("Finish lesson") → celebration.
- No lesson list, images-with-credit or in-lesson images other than the hero are designed (11.7).

**3.2 Topic finished** (`readerDone`)
- Reader with celebration overlay (7.21): "Topic finished" / "You read all 8 lessons of the Roman Empire. Ready for a quick quiz?" / "Take the quiz" (→ Quiz tab, question 1) / "Not now" (dismiss).

**3.3 Chat** (`chat`)
- Subtitle "Ask a question". Message list (pad 8 20, gap 12) starting with the assistant greeting. Suggestion chips row, composer.
- Tapping a suggestion appends the question and the reply (with source chip when on-topic).

**3.4 Off-topic refusal** (`chatOff`)
- Greeting, user "What is the capital of France?", assistant "I only know about the Roman Empire." (no source chip).

**3.5 Chat is resting** (`chatRest`)
- Greeting + resting card at the end of the list; suggestion chips at 0.4 opacity and inert. Composer still drawn normally (11.13).

**3.6 Offline** (`chatOffline`)
- Offline banner under the header; rest as 3.3 (input not visibly disabled; 11.13).

**3.7 Quiz question** (`quiz`), **3.8 Quiz: right** (`quizRight`), **3.9 Quiz: wrong** (`quizWrong`)
- Subtitle "Quiz". Scroll area pad 0 20.
- Progress row (gap 12, 16 below): quiz bar (fills (index + answered) / 6) + counter "2 of 6" (800 14 muted).
- Question (`question`, 18 below); 4 options (7.13), gap 10; explanation box after answering.
- Bottom CTA: primary "Next" (disabled until answered); on question 6 the label is "See result".
- 3.8: picked Carthage → Right. 3.9: picked Athens → Not quite; Carthage shows Right.
- No timer, no lives, no streaks.

**3.10 Quiz result** (`quizResult`)
- Score "4 out of 6" (`scoreXL`, `accentText`), message (`readerHeading`, margin 6 0 16): 5 to 6 "Ave! Very nicely done."; 3 to 4 "Good going. A few to revisit."; 0 to 2 "A start. The lessons will help."
- Review list (gap 8): row pad 10 12, radius 14, `surface`, 600 14/1.3; tick (success) or cross (error) 20, question text, then the correct answer text at the end for missed ones.
- Buttons: primary "Try 6 new questions" (restarts); outline "Review lessons you missed" (→ Lessons tab).

### 4 · Settings

**4.1 Settings** (`settings`)
- No bottom nav. Top bar Back + "Settings". Scroll, bottom pad 24.
- Sections (pad 12 20 4; label `labelCaps` muted, 10 below; segmented row, gap 8):
  - THEME: Dark | Light
  - TEXT SIZE: Small | Medium | Large
  - VOICE SPEED: 0.8x | 1x | 1.2x
- List (pad 16 20 0), rows (7.20): "Voice" — "Device default"; "Clear my data" (error colour) — "Topics, scores, settings"; "About" — "Version 1.0"; "Credits" — arrow.
- Clear my data: resets study list, ratings, picks and returns to the splash (no confirm dialog designed; 11.14). Credits screen not designed (11.8).

### Also in the prototype but not on the v3 boards
- **Guess the year** (`ob1`, `ob1right`, `ob1wrong`): kicker "GUESS THE YEAR"; image 300 tall radius 20 (French Revolution art); "A crowd storms a prison in Paris. When?"; options 1789 / 1799 / 1804; feedback box "Spot on!" or "Close, but no." + "The Bastille fell on 14 July 1789. It held just seven prisoners that day."; "Next" disabled until answered.
- **Mystery card** (`ob2`, `ob2open`): kicker "MYSTERY CARD"; title "A card is waiting" → "Surprise!"; sealed card (surface, 2 px accent border, radius 24, logo 112, "Tap to open") flips to Egypt art with "DID YOU KNOW" + "Cleopatra lived closer in time to the Moon landing than to the building of the Great Pyramid."; "Next" disabled until opened.
These are in FLOW.md but dropped from the v3 flow order (11.2).

### Navigation map (Overview + code)
- First launch: Splash → Sign in → What are you into? → Favourite leader → First matches → Light or dark → Home. (Overview's map also lists Mystery card; the code does not.)
- Bottom tabs: Home, Library, Feed, Study.
- Home: Resume card → Topic (Reader). Poster → Title sheet. Gear → Settings.
- Library: Featured banner or any poster → Title sheet → Rate / Add to study list / Start.
- Study: row → Title sheet. Empty state → Library.
- Topic: Lessons ⇄ Chat ⇄ Quiz; finish lesson → Celebration → Quiz → Result.

### Behaviour rules (Overview + code)
- **Match % (prototype):** start from the topic's base; for every rated topic in the same group (not itself): up +4, down -6, okay 0; clamp 40 to 99. FRONTEND.md has the real formula (S6). Thresholds and reasons ("because you liked X") come from that logic.
- **Study list:** add/remove from the sheet, match cards and Study tab. Progress = lessons read / lessons.
- **Theme and text size:** set in onboarding and Settings, applied live.
- **Read aloud:** bar and speed setting designed; audio not built in prototype (S6 uses flutter_tts).
- **Rewards:** no streak loss, no lives, no timers, no counters.

---

## 10. Assets

### 10.1 Logo ("The disc", final)
A complete ring with the left half filled ("what is already known, and the part still to be opened").
- SVG, viewBox 0 0 100 100: circle cx50 cy50 r42, no fill, stroke 8; path `M50 18 A32 32 0 0 0 50 82z` filled. Gap between ring and fill is 6 units.
- Colours: dark `#C8933A` · light `#8A5A0C`.
- Lockup: mark 52 + "Maximus" Figtree 700 34, -0.02em, gap 16 (text `#F4EDE0` dark / `#1C1710` light).
- Android adaptive icon: background `#C8933A`, mark `#14110C` (shown in circle and squircle masks; squircle radius 40 on 136). Alternative: near-black `#14110C` background with `#C8933A` mark. Themed monochrome icon: shown as `#E8D9B8` on `#2a2318`. Mark tested at 48 and 24.
- In-app uses: splash 168, sign-in 40, Home header 30, mystery card 112. The app uses `#C8933A` for the mark in light theme too (11.10).

### 10.2 Topic illustrations
- Style (Foundations): flat shapes, one dominant silhouette, a light source that becomes the focal circle or flag, 3 to 5 colours per poster. No outlines, no gradients inside the art, no photographic texture. Only gradient is the title scrim. Final art at **2:3**.
- Prototype has 30 inline SVG stand-ins (`<g id="g-<topic>">` in the `<defs>` of `Maximus v3 App.dc.html` line 14 to 27): 4 detailed hero posters on a 200 × 300 canvas (roman, french, ww2, egypt) and 26 simple motifs on about 100 × 150.
- Needed for the build: one 2:3 poster per **real** topic in `TOPICS.md` (28), plus crops for tile (square), banner (2:1) and feed (9:16, full bleed). 9 real topics have no stand-in at all (Black Death, Sikh history, Maratha Empire, Rajput history, Green Revolution, Space history, Great Depression, Dotcom bubble, Housing crisis); 11 stand-ins are for topics not on the list.
- Per-topic data that must ship with each poster: `bg`, `tint` (dark and light), lettering `kind`, two title lines.
- ROUTING plans poster art from ChatGPT/Gemini image "after style frozen in S2". The style above is the frozen brief.

### 10.3 Leader portraits
- 12 inline SVG stand-ins (`<g id="l-<leader>">`, 100 × 100, flat head-and-shoulders style, 5 to 9 shapes): caesar, cleopatra, alexander, genghis, napoleon, elizabeth, akbar, ashoka, lincoln, churchill, catherine, suleiman.
- `TOPICS.md` lists 40 leaders + 11 thinkers; only Caesar, Cleopatra, Alexander, Ashoka, Genghis, Elizabeth I and Napoleon overlap.

### 10.4 Icons
All 24 × 24 viewBox, stroke 2, round caps and joins, no fill, colour = current colour (play is filled). Lucide-like but custom paths; draw from these paths (SVG asset or CustomPainter) rather than substituting a library, or map to Lucide if exact match is not required.

| Name | Path(s) | Used in |
|---|---|---|
| home | `M4 11l8-7 8 7v9h-5v-6H9v6H4z` | Nav |
| library | `M4 4h7v7H4z M13 4h7v7h-7z M4 13h7v7H4z M13 13h7v7h-7z` | Nav |
| feed | `M8.5 3h7A2.5 2.5 0 0 1 18 5.5v13a2.5 2.5 0 0 1-2.5 2.5h-7A2.5 2.5 0 0 1 6 18.5v-13A2.5 2.5 0 0 1 8.5 3z M10.5 9.5v5l4-2.5z` | Nav |
| bookmark (study, save) | `M6.5 3.5h11v17l-5.5-4-5.5 4z` | Nav, feed Save |
| book (lessons) | `M4 5.5C6 4.5 9 4.5 12 6c3-1.5 6-1.5 8-.5v13c-2-1-5-1-8 .5-3-1.5-6-1.5-8-.5z M12 6v13.5` | Topic bar, chat source chip |
| chat | `M4 5h16v11H10l-5 4v-4H4z` | Topic bar |
| quiz / help-circle | `M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18z M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.7.4-1 .9-1 1.7 M12 17h.01` | Topic bar, empty scores (32) |
| sun (also used as Settings) | circle cx12 cy12 r3 + `M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1` | Home Settings button, Light theme card (11.11) |
| moon | `M20 14A8 8 0 0 1 10 4a8 8 0 1 0 10 10z` | Dark theme card, resting card |
| chevron-left | `M15 5l-7 7 7 7` | Back, previous lesson; mirrored for next lesson |
| arrow-right | `M5 12h14M13 6l6 6-6 6` | Go deeper, Credits row |
| play (filled) | `M7 4.5v15l12.5-7.5z` | Resume, Start, read aloud |
| check | `M5 12.5l4.5 4.5L19 7` | Right, Added, selected tile, review |
| x | `M6 6l12 12M18 6L6 18` | Wrong, remove, review |
| plus | `M12 5v14M5 12h14` | Add |
| minus | `M6 12h12` | Rating "It is okay" |
| thumbs-up | `M7 11v9H4v-9zM7 11l4-8c1.5 0 2.5 1 2 3l-.7 3H19a2 2 0 0 1 2 2.3l-1 6a2 2 0 0 1-2 1.7H7` | Rating, feed Like |
| thumbs-down | `M7 13V4H4v9zM7 13l4 8c1.5 0 2.5-1 2-3l-.7-3H19a2 2 0 0 0 2-2.3l-1-6A2 2 0 0 0 18 4H7` | Rating, feed Dislike |
| wifi-off | `M2 8.5a15 15 0 0 1 20 0M5.5 12a10 10 0 0 1 13 0M9 15.5a5 5 0 0 1 6 0M12 19h.01M3 3l18 18` | Offline banner |
| send | `M4 12l16-8-6 16-3-7z` | Chat send |

### 10.5 Fonts (files to bundle)
Figtree 500/600/700/800/900 · Cinzel 700 · Caveat Brush 400 · Big Shoulders Stencil Display 900, each with its `OFL.txt`.

### 10.6 Not provided
Google/Apple provider logos, onboarding/feed photos, lesson images and their credit lines, Credits screen content, app store art.

---

## 11. Ambiguities and conflicts (decide before or during S3/S4)

Each item: what conflicts, and a recommended default.

1. **Accounts.** Sign in / Create account screens exist (1.2, 1.3), but BRIEF, APP_DETAILS, BACKEND and FLOW all say *no accounts in v1*. **Default:** drop both screens in v1; Splash goes straight to onboarding (first run) or Home.
2. **Onboarding steps.** FLOW.md: Guess the year → Mystery card → Pick topics → First matches → Theme + text size. v3 order: (Sign in) → Pick topics → Favourite leader → First matches → Theme. Guess-the-year and Mystery card are still built in the prototype but not in its flow, and the Overview map lists Mystery card. **Default:** v3 order without sign-in. Decide whether to restore Guess the year and Mystery card (they are fully specified above).
3. **Text size in onboarding.** FLOW and Overview say the theme step also sets text size ("one slider"); the v3 screen has only theme. **Default:** theme only; text size in Settings.
4. **Topic and people catalogue.** Design uses 30 placeholder topics (incl. Mughal, which TOPICS.md removed, and Maya, Aztec, Inca, Byzantine, Persia, Samurai, Mali, Crusades, Ming, Zulu, which are not on the list) and 12 leaders (Lincoln, Churchill, Catherine, Suleiman, Akbar not on the list). Overview text says "20 topics". **Default:** TOPICS.md is the source of truth for content; design data is visual reference only. Needs new colours/lettering kinds/rows for the 9 missing topics.
5. **"Think Like..." people section.** FLOW/TOPICS have a Think Like row of portrait posters and a Person sheet (traits, "What they changed", "Odds they beat", core ideas, "Use it today"). **None of this is designed in v3.** Only the onboarding leader picker exists. **Default:** S5 designs a person poster (portrait art + name lettering) and person sheet from the title-sheet components; confirm with the owner.
6. **Dashboard tiles.** Foundations and DESIGN.md include dashboard tiles ("3 topics in progress", "82% best quiz score", "12 lessons read"); Home in v3 has quiz score tiles instead. **Default:** build Home as designed; keep the dashboard tile as a component for S9.
7. **Reader details.** FLOW wants a Lessons list, images with credit, previous/next lesson and an "images credit one tap away". v3 has only the reader page (Lessons tab = current lesson), a single hero image and no credit line. **Default:** S6 adds a lessons list sheet and a credit caption (`caption` style) under images; confirm.
8. **Credits screen** (CC BY-SA notice, image credits, font licences) is a row in Settings but not designed. **Default:** a plain list screen using 7.20 rows.
9. **Light-theme poster tint.** Foundations: tint at lightness 38% in light vs 60% in dark. The prototype uses one tint in both. **Default:** one tint per topic for poster art; derive a darker variant only for tint-coloured *text* on light backgrounds (kickers) if contrast fails.
10. **Logo colour in light theme.** Logo Final uses `#8A5A0C` on light; the App hard-codes `#C8933A` for the Home/sign-in mark. **Default:** use `accentText` (so `#8A5A0C` on light).
11. **Settings icon** is the sun glyph (same as the Light theme icon), not a gear. Overview calls it a "gear icon". **Default:** use a proper gear/settings icon to avoid confusing it with theme.
12. **Tap targets that differ from FLOW.** Study row: FLOW says tap opens the Reader at the next lesson and swipe removes; v3 opens the title sheet and uses an X button. Feed "Go deeper": FLOW says opens the lesson; v3 opens the sheet. Home study rows are not tappable in v3. Home "For you": FLOW says only titles you have not added; prototype shows added ones. **Default:** follow v3 for layout; for actions, follow FLOW (open Reader/lesson), keep the X button and add swipe-to-remove.
13. **Chat offline/resting.** FLOW says offline chat is disabled; v3 only shows a banner and leaves the composer looking active. Resting dims chips only. **Default:** in both states disable composer and chips (opacity 0.4).
14. **Undesigned states.** Pressed/focus/disabled styles beyond primary-button 0.4 opacity; input focus and error; feed Save/Like/Dislike active state; read-aloud playing/paused; loading (skeletons) and content-error states; first-run vs returning splash; confirm dialog for "Clear my data"; sheet with no rating yet on non-Roman topics. **Default:** pressed = 8% overlay of text colour on outline/ghost buttons and accent darken on fills; focus ring 2 px `accent`; active feed icons fill with `accent`; playing shows pause icon; add a confirm dialog for Clear my data.
15. **Foundations vs App numbers.** Foundations radii (8/14/18/24/999) and option style (h56, radius 16, 600 16) differ from the App (posters radius about 10, options h60 radius 18, 800 18; rating buttons 52 vs 56; tile pop 1.04 vs 1.06; confetti 36 vs 30; nav pill alpha 0.22 vs 0.20). Foundations type scale is lighter (800 display) than the App (900). **Default:** App values everywhere (this spec), Foundations only for motion and elevation. Foundations' "Add to study list" is filled-accent when not added; the App sheet uses accent outline in both states (filled is used only on match cards). Default: App.
16. **Screen width.** Overview says "412 × 812 dp"; the frame's 8 px border makes the prototype content 396 wide. Layouts are fluid (20 gutters) except fixed poster widths (126/128/170). **Default:** build fluid; keep poster widths fixed; test on Pixel 8 (412 dp wide).
17. **Three near-identical dark inks** on tinted buttons (`#140D07`, `#1A0805`, `#1A1208`). **Default:** use `onAccent #1A1208` everywhere.
18. **Badge colour `#E7B25A`** (match badge, hover link colour on the boards) is not a token. **Default:** add `color.accentBright #E7B25A` for on-image accent text.
19. **Greeting and On this day.** "Good evening" presumably changes by time of day; "On this day" is live (FLOW: works only online). Neither has a designed offline/empty state. **Default:** Good morning / afternoon / evening by local time; hide the card when no data.
20. **Hero banner secondary button.** Foundations hero shows Start + "Study list"; the App hero has Start only. **Default:** App (Start only).
21. **Big Shoulders family naming** on Google Fonts (see 2.1): confirm the exact file at download.
22. **Library rows.** v3 rows: For you, Ancient, Revolutions, Wars, India and Empire. FLOW rows: For you, Ancient and medieval, India, Revolutions and empires, Wars and space, Money and crashes, Because you liked X, Think Like... **Default:** FLOW rows (they match TOPICS.md groups), styled as v3 rows.
23. **App name** is still open (BRIEF). The design uses "Maximus" in the lockup and "New to Maximus?". Keep it as a single string constant.
24. **Retired assets in the bundle.** `_ds` Classical tokens (Cormorant/Lora, 4 px radii, outlined buttons) and DESIGN.md's "Inter" and "engraved M roundel" are superseded by v3 (Figtree, disc logo). Do not use them.


## 12. Owner decisions (2026-11-22) - these override section 11 defaults

1. **Accounts:** dropped. No sign-in or create-account screens in v1. Splash goes to onboarding (first run) or Home.
2. **Onboarding:** v3 order without sign-in: Pick topics, Favourite leader, First matches, Theme. Guess the year and Mystery card are built later as polish (specified above, not in v1 scope).
3. **Text size:** Settings only, not onboarding.
4. **Catalogue:** TOPICS.md is the source of truth (28 topics, 40 leaders, 11 thinkers). Design data is visual reference only. Topics without artwork use a tinted gradient poster with title lettering until illustrations are generated.
5. **Think Like...:** person row (portrait posters) and person sheet are NOT designed yet. Run Prompt 2b in Claude Design first; S5 waits for that output. Until then S4/S5 build everything else.
6. Items 6 to 24 of section 11: use the stated defaults. Item 22: use FLOW library rows. Item 15: App values win.
7. **Repo is PUBLIC (owner's choice).** Never commit .env, API keys, or personal data; keys live only in backend/.env (gitignored) and the host's secret store.
8. **Future features** (perspective mode, Think Like a Leader game) are NOT in v1. See docs/FUTURE_FEATURES.md. Reserve placeholder data models only (CONTRACTS.md).
