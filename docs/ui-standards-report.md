# UI standards: Recipe Finder (Flutter), 2026-10-24

Checklist: `~/.claude/skills/ui-standards/checklist.md`. Screens: Home (featured,
categories, recipe grid, search), Recipe detail (ingredients / instructions),
Saved, Shopping list. Data states: loading, data, empty, error, offline.

```
Must   ✅ 25  ❌ 0  ⚠️ 1 (framework)   Should ✅ 16  ⚠️ 3   Nice ✅ 2
```

## How it was checked

- `flutter analyze`: no issues. `flutter test`: 24 pass.
- [`test/screens_test.dart`](../test/screens_test.dart) pumps Home, Recipe and
  Shopping list at **320×568, 412×915 and 800×1280**, each at **100% and 200%
  text**, and fails on any layout overflow or on Flutter's own guidelines:
  `androidTapTargetGuideline` (48×48 dp), `labeledTapTargetGuideline`,
  `textContrastGuideline`. It also checks the offline and server-error states.
  It found two overflows at 200% text (greeting row, "Add all to list" row),
  which are now fixed.
- Release web build in headless Chromium (Playwright): screenshots at 320, 375,
  768 and 1440. Loading (held requests), empty (search "zzzz"), error (HTTP 500)
  and offline (requests aborted) states forced with `page.route`. Keyboard pass
  (Tab, Enter). axe-core 4.10 run on Flutter's semantics DOM (Home, Recipe).
- Contrast computed by hand from the theme colours (below).

## 1. Accessibility

- ✅ Must · Text contrast · muted text #556070 is 6.38:1 on white and 5.81:1 on
  the card tint; teal links #2F6F74 are 5.76:1; dark ink on the teal
  cards/chips is 7.14:1; white on the dark toggle is 15.99:1.
  `textContrastGuideline` passes on every screen.
- ✅ Must · Design conflict, resolved in code. The kit's white text on its light
  teal is **2.24:1** and its grey captions are **2.59:1**, which fail WCAG. Teal
  backgrounds carry the kit's dark ink (#042628) instead, captions use #556070,
  and teal text uses #2F6F74. All colours are in `lib/theme.dart`.
- ✅ Must · Non-text contrast · the focus ring #042628 is 7.14:1 against teal
  and 15.99:1 against white. The search field's focus border is 5.76:1.
- ✅ Must · Not colour alone · a saved heart changes from outline to filled; an
  ingredient on the list changes from ⊕ to ✓; checked shopping items get a
  tick and strikethrough.
- ✅ Must · Keyboard · Tab reaches the header buttons, search, featured cards,
  chips, cards and hearts in order, and Enter opens a recipe. The checkboxes,
  delete buttons and Undo snackbar action are standard Material widgets.
- ✅ Must · Visible focus · Material's focus tint on cards was too faint, so
  cards and the Ingredients/Instructions toggle get a 3 px ring
  (`widgets/focus_ring.dart`), shown only for keyboard focus.
- ✅ Must · Labels and names · every icon button has a tooltip naming its
  action and item ("Save Teriyaki Chicken Casserole", "Remove Soy sauce",
  "Shopping list, 3 items"). `labeledTapTargetGuideline` passes.
- ✅ Must · Alt text · photos are decorative (`excludeFromSemantics`) because
  the recipe name sits next to each one.
- ✅ Must · Status messages · snackbars ("Added 9 items…", "Removed…") are
  announced (Flutter marks SnackBar as a live region). Search results use a
  live-region heading, and the cart badge count is in the button's label.
- ✅ Must · Target size · 48×48 dp everywhere (`androidTapTargetGuideline`).
- ✅ Must · Errors · offline: "You're offline. Check your connection…"; server:
  "TheMealDB returned an error (500)." Both have Try again.
- ⚠️ Must (framework) · Reflow / zoom · axe `meta-viewport`: Flutter web's
  full-page embedding always replaces the viewport tag with
  `user-scalable=no` (see `full_page_embedding_strategy.dart` in the engine).
  App code can't change this. Text resizing still works: the app follows the
  browser's and OS's text size and is tested at 200%, and 320 px has no
  sideways scroll.
- ⚠️ Should (framework) · Landmarks · axe `region`: Flutter's `SemanticsRole`
  has no main/navigation landmark roles. Headings are marked with
  `Semantics(header: true)`.
- ✅ Should · Touch targets · 48 dp.
- — N/A · Modals: only the system About dialog and snackbars (Material handles
  focus) · Skip link: Flutter renders on a canvas, so there is no DOM nav to
  skip · Reduced motion: only Material's default transitions.
- **Not checked:** TalkBack/VoiceOver on a real device (no emulator on this
  machine). The semantics tree was checked only through tests and axe on the
  web DOM.

## 2. Component states

- ✅ Must · Focus-visible · ring for keyboard focus, distinct from the hover
  tint.
- ✅ Must · Disabled · "All on your list" is disabled once every ingredient is
  added, and the label says why.
- ✅ Must · Loading/busy · saving a heart from a list card fetches the full
  recipe first: the heart shows a spinner and is disabled until it finishes.
- ✅ Should · Hover/pressed · Material ink on cards, chips and buttons.
- ✅ Should · Success · snackbars confirm adds and removes. The heart fills;
  the ⊕ turns into ✓.
- ✅ Should · Selected · chips, nav destinations and the toggle (marked
  `Semantics(selected:)`) show their selected state. The shopping list's
  By dish / All items switch is a Material `SegmentedButton`. A combined row
  where only some dishes are ticked shows a dash (tristate checkbox).
- — N/A · Field error: no validated forms.

## 3. Screen states

- ✅ Must · Loading · card-shaped skeletons for featured and the grid, and a
  spinner on the recipe page, each with a semantics label.
- ✅ Must · Empty · search: "Nothing matches 'zzzz'…" + Clear search; Saved:
  "No saved recipes yet" + Browse recipes; Shopping list: "Your shopping list
  is empty" + Find a recipe.
- ✅ Must · Error · plain message + Try again (screenshots `docs/error.png`,
  `docs/offline.png`).
- ✅ Should · Offline · a separate offline message. Saved recipes are stored
  whole, so they open with no connection, and the shopping list is local.
- ✅ Should · Partial · a failed Featured shows a small inline retry and the
  rest of Home still loads. Images that fail show a placeholder icon.
- ✅ Should · Long content · names wrap to 2–3 lines with ellipsis. Tested with
  an 80-character name at 320 px and 200% text.

## 4. Feedback and interaction

- ✅ Must · Immediate response · ink ripple on press, and skeletons on fetch.
- ✅ Should · Undo · removing a shopping item, "Clear checked" and un-saving
  a recipe all offer Undo, and Undo puts items back in their old place.
- ✅ Should · Success · Fixed after Ian's review: in this Flutter version a
  SnackBar with an action stays up until dismissed (`persist` defaults to true),
  so "Added… View" stayed on screen and followed you to the shopping list,
  where View did nothing visible. All snackbars now set `persist: false` (gone
  after 4 s), and opening the shopping list clears any leftover one. Covered by
  tests and checked in the web build.
- ✅ Should · Preserve user work · saved recipes and the shopping list persist
  (`shared_preferences`).
- ⚠️ Should · State in the URL · recipe pages have their own URL
  (`/#/recipe/52772`, refresh-safe and shareable). The selected category and
  search text are **not** in the URL: with Flutter's built-in Navigator the
  URL is rewritten to `/` when a page closes. Adding this needs `go_router`
  (a new dependency). Raised with Ian.
- ✅ Must · Touch parity · nothing is hover-only.
- ✅ Should · Affordance · cards, chips and buttons look tappable; headings
  don't.

## 5. Responsive

- ✅ Must · Widths · 320/375 (bottom nav, 1–2 columns), 768 (recipe page
  splits into photo and details side by side), 1440 (side rail, content
  capped at 1200 px, 6 columns). 320 px: `scrollWidth − clientWidth = 0`.
- ✅ Should · Safe areas · `SafeArea` around the shell; the recipe photo runs
  under the status bar, as in the design.
- ✅ Should · Responsive images · cards and Featured use TheMealDB's
  `/medium` preview (~45 KB, ~350 px); only the recipe page's large photo
  loads the original (~125 KB).
- — N/A · Overlays fit: only the system About dialog.

## 6–7. Performance and resilience

- ✅ Must · CLS · image boxes keep their size while loading (AspectRatio +
  tint placeholder).
- ✅ Should · Timeouts · requests end after 10 s with an error state.
- ✅ Should · Bundle · three packages: `flutter_riverpod` (state), `http` (web
  needs it), `shared_preferences` (offline saves). Fonts and icons are bundled.
- — Not measured: LCP/INP (not yet measured on the live Cloudflare Pages site).
- — N/A · Error boundary: React-only item · Service worker: Flutter's own was
  removed upstream; offline here means saved data, not the app shell.

## 9. Visual consistency

- ✅ Must · Matches design · compared side by side with the Recipely cover
  frames (Home: greeting, cart, Featured carousel, Category chips, recipe
  cards, bottom nav. Detail: full-bleed photo with close/heart, rounded sheet,
  2×2 info tiles, dark Ingredients/Instructions toggle, ingredient rows with
  thumbnails and "Add all"). Changes from the kit:
  - contrast colours (above);
  - the nutrition tiles show category, cuisine, ingredient count and step
    count, because the API has no kcal or time;
  - the ingredient quantity stepper is replaced by add/remove (measures are
    text such as "3/4 cup");
  - the scan FAB and the notification and profile tabs are left out (out of
    scope);
  - the user name in the greeting becomes a question.
- ✅ Should · Tokens · all colours in `lib/theme.dart`, font Sofia Sans (OFL)
  close to the kit's geometric sans.

## 10–13. Content, forms, SEO, security

- ✅ Must · No dead ends · every empty, error and offline state has an action.
  Fixed during the check: the recipe page's loading, offline and not-found
  states had no on-screen way back. They now have a close button (covered by
  a test). Real offline was checked by switching the browser offline after
  load and opening an unsaved recipe: the offline message showed within 3 s.
- ✅ Must · Labels · the search field has a hint. Flutter exposes the hint as
  the field's accessible name.
- ✅ Should · Title + description · `web/index.html` has a title, a
  description, `lang="en"`, Open Graph tags and `theme-color`.
- ✅ Nice · Favicon/app icons · custom R-on-plate icon for web, the PWA
  manifest and Android.
- ✅ Nice · Social preview · `og:image` points to the live Cloudflare Pages
  URL.
- ✅ Must · No secrets · TheMealDB's public test key "1" is part of the URL by
  design and is not secret.

## 14. Flutter

- ✅ Must · Semantics, tap targets, text scaling (200%), contrast, states,
  sizes (small phone, large phone, tablet), analyzer: see above.
- ✅ Should · Flutter web · keyboard and focus checked, recipe URLs work.
- ⚠️ Not checked on a physical Android device or emulator: the release APK
  is built but not installed or run here.
