# Le Grenier du Message Reference UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Android and Windows UI so it follows the approved 4 October 2026 “Le Grenier du Message” reference composition while preserving the existing offline V4 search, corpus, conversation, navigation, highlighting, personal data, and printing behavior.

**Architecture:** Keep the current domain/search/runtime objects unchanged and rebuild the presentation around a small responsive design system. Pure presentation components receive data and callbacks; `ConversationShellScreen` remains the adapter to `AppScope` and `ConversationController`. Desktop uses banner + fixed sidebar + central workspace + optional details pane; mobile uses brand home + four-item bottom navigation + drawer for advanced destinations.

**Tech Stack:** Flutter/Dart, Material 3, existing `pdf`/`printing`, existing SQLite runtime, existing deterministic V4 IR, Flutter widget tests, GitHub Actions Android 15 ARM64 + Windows x64.

**Spec:** `docs/superpowers/specs/2026-10-04-le-grenier-du-message-reference-ui-design.md`

## Global Constraints

- Public identity: **Le Grenier du Message**.
- Product subtitle: **V4 – IR Expert**.
- Signature: **Toute Sa Parole. Toujours avec vous. Hors ligne.**
- Trust labels: **100% hors ligne**, **Aucune IA générative**, **Texte canonique uniquement**.
- Approved visual reference SHA-256: `ee903b9298301ca13f2bdf4f6200740a77d74fdbc7c7c1757968ef5be6d56a17`.
- Android target remains Android 15 ARM64; Windows target remains x64.
- No network dependency, remote API, web font, generative AI, LLM, embedding model, ONNX model, or new corpus format.
- `corpus.db`, the 39 corpus parts, and canonical text remain unchanged.
- Existing `user.db`, conversations, notes, collections, favorites, and reading positions remain compatible.
- No horizontal scrolling on mobile.
- Minimum practical touch target: approximately 44–48 px.
- Current exact-passage navigation and canonical highlight offsets remain authoritative.
- Light mode is the visual fidelity reference; dark mode must preserve the same hierarchy and contrast.
- CI completion requires `flutter analyze` with zero issues, all tests passing, V4 release validation OK, Android signature/16 KB verification, Windows build success, and zero warning-like log hits.

## Review Focus

1. **Long French titles, references, and filter labels on a 360 px-wide device** must wrap or ellipsize without horizontal overflow; Task 2 owns `mobile_shell_handles_long_labels_without_overflow`.
2. **A conversation with 100+ result cards** must remain lazily built and must not place all cards inside an eager `Column`; Task 4 owns `conversation_results_use_lazy_list_on_long_turn`.
3. **A canonical citation containing punctuation, apostrophes, or accented words** must display highlighted terms without changing the copied/exported text; Task 5 owns `canonical_highlight_preserves_exact_text`.
4. **A selected desktop result followed by a window resize below the wide breakpoint** must preserve access to details without keeping a clipped right pane; Task 5 owns `details_panel_collapses_to_mobile_sheet_after_resize`.
5. **Dark mode with the yellow citation highlight** must keep readable foreground/background contrast and visible focus states; Task 8 owns `dark_theme_highlight_and_focus_remain_readable`.

---

## File Structure

### New presentation primitives

- Create `lib/src/theme/grenier_tokens.dart` — brand constants, palette, breakpoints, spacing/radius constants.
- Modify `lib/src/theme/grenier_theme.dart` — light/dark Material 3 themes derived from the new tokens.
- Create `lib/src/screens/grenier_top_banner.dart` — desktop top banner and trust labels.
- Create `lib/src/screens/grenier_navigation.dart` — `GrenierDestination` enum plus pure desktop sidebar/mobile navigation widgets.
- Create `lib/src/screens/grenier_home_screen.dart` — responsive brand landing page and mobile CTA.
- Create `lib/src/screens/canonical_highlight_text.dart` — visual-only canonical term highlighting.
- Create `lib/src/screens/result_details_panel.dart` — desktop result detail pane and mobile detail surface.
- Create `lib/src/screens/comparison_picker_screen.dart` — real compare entry point that selects one/two passages before opening existing `ComparisonScreen`.
- Create `lib/src/screens/scripture_references_screen.dart` — UI over existing `ScriptureReferenceEngine`.

### Existing adapters/screens to change

- Modify `lib/src/app.dart` — public title/branding only; runtime wiring stays unchanged.
- Modify `lib/src/screens/conversation_shell_screen.dart` — responsive shell and route mapping.
- Modify `lib/src/screens/conversation_sidebar.dart` — replace old coupled sidebar with adapter usage or remove after migration.
- Modify `lib/src/screens/home_screen.dart` — retire old search landing in favor of `GrenierHomeScreen` or turn it into a compatibility wrapper.
- Modify `lib/src/screens/conversation_screen.dart` — workspace, lazy turns/results, selection/details behavior.
- Modify `lib/src/screens/conversation_composer.dart` — bottom composer styling and filter/context row.
- Modify `lib/src/screens/conversation_result_message.dart` — documentary response header and active filter bar.
- Modify `lib/src/screens/conversation_result_card.dart` — reference card layout, highlighting, actions, selection callback.
- Modify `lib/src/screens/library_screen.dart`, `personal_search_screen.dart`, `concordance_screen.dart`, `timeline_screen.dart`, `study_screen.dart`, `settings_screen.dart`, `comparison_screen.dart` — shared visual system only.
- Modify `lib/src/printing/print_document_builder.dart`, `lib/src/printing/print_service.dart` — public identity and reference-PDF hierarchy.
- Modify `pubspec.yaml` only if a local packaged reference/banner asset is added; do not add network packages.

### Tests

- Create `test/grenier_tokens_test.dart`.
- Create `test/grenier_navigation_widget_test.dart`.
- Create `test/grenier_home_widget_test.dart`.
- Create `test/conversation_workspace_widget_test.dart`.
- Create `test/result_card_details_widget_test.dart`.
- Create `test/study_navigation_widget_test.dart`.
- Create `test/print_branding_test.dart`.
- Create `test/grenier_accessibility_responsive_test.dart`.
- Keep and run all existing tests.

---

### Task 1: Design tokens, public identity, and theme foundation

**Files:**
- Create: `lib/src/theme/grenier_tokens.dart`
- Modify: `lib/src/theme/grenier_theme.dart`
- Modify: `lib/src/app.dart`
- Test: `test/grenier_tokens_test.dart`

**Interfaces:**
- Consumes: existing Material 3 theme usage from `MessageBotTheme.light()` / `dark()`.
- Produces:
  - `abstract final class GrenierBrand` with static constants `name`, `versionLabel`, `tagline`, `offlineLabel`, `noAiLabel`, `canonicalOnlyLabel`.
  - `abstract final class GrenierBreakpoints` with `mobile = 760.0`, `desktopWide = 1180.0`, `isMobile(double)`, `isWideDesktop(double)`.
  - `abstract final class GrenierPalette` exposing `navy`, `actionBlue`, `lightCanvas`, `highlightLight`, `offlineGreen`.
  - `MessageBotTheme.light()` and `MessageBotTheme.dark()` remain the public theme entry points for compatibility.

- [ ] **Step 1: Write the failing token/theme test**

Create tests asserting exact brand strings, exact breakpoint constants, and that light/dark themes use the approved navy/action blue families.

- [ ] **Step 2: Run the focused test to verify RED**

Run: `flutter test test/grenier_tokens_test.dart`  
Expected: FAIL because `GrenierBrand`, `GrenierBreakpoints`, and `GrenierPalette` do not exist.

- [ ] **Step 3: Implement the theme foundation**

Add the interfaces above, centralize radius/input/card/navigation styling in `grenier_theme.dart`, and change visible bootstrap/app title copy in `app.dart` to `GrenierBrand.name`. Do not alter runtime initialization.

- [ ] **Step 4: Run focused test and analyzer**

Run: `flutter test test/grenier_tokens_test.dart && flutter analyze`  
Expected: PASS; analyzer reports `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/src/theme/grenier_tokens.dart lib/src/theme/grenier_theme.dart lib/src/app.dart test/grenier_tokens_test.dart
git commit -m "feat: add Grenier design system foundation"
```

---

### Task 2: Responsive shell, desktop banner, sidebar, and mobile navigation

**Files:**
- Create: `lib/src/screens/grenier_top_banner.dart`
- Create: `lib/src/screens/grenier_navigation.dart`
- Modify: `lib/src/screens/conversation_shell_screen.dart`
- Modify: `lib/src/screens/conversation_sidebar.dart`
- Test: `test/grenier_navigation_widget_test.dart`

**Interfaces:**
- Consumes: `GrenierBrand`, `GrenierBreakpoints`, `GrenierPalette` from Task 1; `ConversationSummary` for recent conversations.
- Produces:
  - `enum GrenierDestination { home, library, conversations, collections, notes, concordance, timeline, compare, scripture, settings }`.
  - `GrenierTopBanner()`.
  - `GrenierDesktopSidebar({required GrenierDestination selected, required ValueChanged<GrenierDestination> onSelect, required VoidCallback onNewConversation, required List<ConversationSummary> recentConversations, required ValueChanged<int> onOpenConversation})`.
  - `GrenierMobileNavigation({required GrenierDestination selected, required ValueChanged<GrenierDestination> onSelect})`.
  - `ConversationShellScreen` becomes the only adapter that maps destinations to actual screens and controller actions.

- [ ] **Step 1: Write failing desktop/mobile navigation tests**

Assert at width 1440:
- `Le Grenier du Message`, `V4 – IR Expert`, `100% hors ligne`;
- fixed desktop sidebar;
- all ten navigation labels;
- `+ Nouvelle conversation`;
- no bottom navigation.

Assert at width 390:
- no fixed desktop sidebar;
- bottom labels exactly `Accueil`, `Bibliothèque`, `Conversations`, `Réglages`;
- advanced destinations available from drawer/menu.

Add Review Focus test `mobile_shell_handles_long_labels_without_overflow` using a 360 px surface and a deliberately long recent-conversation title; `tester.takeException()` must be null.

- [ ] **Step 2: Run the focused test to verify RED**

Run: `flutter test test/grenier_navigation_widget_test.dart`  
Expected: FAIL because the new navigation interfaces and layout do not exist.

- [ ] **Step 3: Implement pure navigation components**

Use a full-width top banner only for non-mobile layout. Keep navigation widgets pure: they receive destination values/callbacks and conversation summaries but do not call `AppScope.of` internally.

- [ ] **Step 4: Adapt `ConversationShellScreen`**

Map destinations:
- home → brand home;
- library → existing `LibraryScreen`;
- conversations → existing/rebuilt `ConversationScreen`;
- collections → `CollectionsScreen`;
- notes → `PersonalSearchScreen`;
- concordance → `ConcordanceScreen`;
- timeline → `TimelineScreen`;
- compare → Task 6 compare entry point once available; until Task 6 use a real `StudyScreen` compare route adapter, never a dead button;
- scripture → Task 6 scripture screen once available; until then route to `StudyScreen`;
- settings → `SettingsScreen`.

`+ Nouvelle conversation` must call `ConversationController.startNewConversation()` and navigate to `conversations`.

- [ ] **Step 5: Run focused tests and analyzer**

Run: `flutter test test/grenier_navigation_widget_test.dart && flutter analyze`  
Expected: PASS with no overflow exceptions and no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/src/screens/grenier_top_banner.dart lib/src/screens/grenier_navigation.dart lib/src/screens/conversation_shell_screen.dart lib/src/screens/conversation_sidebar.dart test/grenier_navigation_widget_test.dart
git commit -m "feat: rebuild responsive Grenier shell"
```

---

### Task 3: Reference-faithful home screen

**Files:**
- Create: `lib/src/screens/grenier_home_screen.dart`
- Modify: `lib/src/screens/home_screen.dart`
- Modify: `lib/src/screens/conversation_shell_screen.dart`
- Test: `test/grenier_home_widget_test.dart`

**Interfaces:**
- Consumes: Task 1 tokens and Task 2 shell navigation callback.
- Produces:
  - `GrenierHomeScreen({required VoidCallback onStartConversation})`.
  - Existing `HomeScreen` may remain as a thin compatibility wrapper only if other code imports it.

- [ ] **Step 1: Write failing home tests**

Desktop assertions: brand title, tagline, trust labels, primary CTA.  
Mobile 390×844 assertions: book mark, `Le Grenier du Message`, `V4 – IR Expert`, multiline tagline, `Commencer une recherche`, and no overflow.

- [ ] **Step 2: Run RED**

Run: `flutter test test/grenier_home_widget_test.dart`  
Expected: FAIL because `GrenierHomeScreen` does not exist.

- [ ] **Step 3: Implement home**

Use local colors/icons only; no web image/font dependency. CTA calls `onStartConversation` and the shell navigates to `GrenierDestination.conversations`.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test/grenier_home_widget_test.dart && flutter analyze`  
Expected: PASS, no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/grenier_home_screen.dart lib/src/screens/home_screen.dart lib/src/screens/conversation_shell_screen.dart test/grenier_home_widget_test.dart
git commit -m "feat: add Grenier reference home"
```

---

### Task 4: Conversation workspace, header, filters, and composer

**Files:**
- Modify: `lib/src/screens/conversation_screen.dart`
- Modify: `lib/src/screens/conversation_composer.dart`
- Modify: `lib/src/screens/conversation_result_message.dart`
- Test: `test/conversation_workspace_widget_test.dart`

**Interfaces:**
- Consumes: current `ConversationController.turns`, `currentFilters`, `searching`, and `send(String)`.
- Produces:
  - `ConversationComposer({required Future<void> Function(String) onSend, required bool busy, bool centered = false, ConversationFilterSet filters = const ConversationFilterSet()})`.
  - documentary response header preserves `ConversationResultMessageHeader({count, filters, fuzzySuggestions})`.
  - conversation screen exposes a lazy scrollable workspace; no eager nested list of all result cards.

- [ ] **Step 1: Write failing workspace tests**

Assert:
- user query is in a right-aligned blue bubble;
- result count and active filter chips are present;
- composer is anchored below scrollable content;
- busy state shows progress and prevents duplicate submit.

Add Review Focus test `conversation_results_use_lazy_list_on_long_turn`: construct a test turn with >100 lightweight result placeholders and assert the scrollable is a `ListView`/sliver-backed lazy list rather than an eager `Column` containing all result cards.

- [ ] **Step 2: Run RED**

Run: `flutter test test/conversation_workspace_widget_test.dart`  
Expected: FAIL on new layout/behavior assertions.

- [ ] **Step 3: Refactor the workspace**

Separate turn row generation from visual components, keep result rendering lazy, and style the composer to match the reference: rounded field, blue circular send action, filter/context chips close to the composer where width permits.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test/conversation_workspace_widget_test.dart && flutter analyze`  
Expected: PASS with no analyzer issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/conversation_screen.dart lib/src/screens/conversation_composer.dart lib/src/screens/conversation_result_message.dart test/conversation_workspace_widget_test.dart
git commit -m "feat: rebuild documentary conversation workspace"
```

---

### Task 5: Result cards, canonical highlights, details panel, and exact selection behavior

**Files:**
- Create: `lib/src/screens/canonical_highlight_text.dart`
- Create: `lib/src/screens/result_details_panel.dart`
- Modify: `lib/src/screens/conversation_result_card.dart`
- Modify: `lib/src/screens/conversation_screen.dart`
- Test: `test/result_card_details_widget_test.dart`

**Interfaces:**
- Consumes: `DocumentSearchHit.highlightSentence`, `highlightStartOffset`, `highlightEndOffset`, `ConversationFilterSet.subjectTerms`, existing `openStudyPassage(...)`, `ComparisonScreen`, printing and collection APIs.
- Produces:
  - `CanonicalHighlightText({required String text, required Iterable<String> terms, TextStyle? style, int maxLines = 0})`.
  - `ResultSelection({required int turnId, required String query, required ConversationFilterSet filters, required int rank, required DocumentSearchHit hit, required SearchExplanationV4 explanation, required double topScore})`.
  - `ResultDetailsPanel({required ResultSelection selection, required VoidCallback onClose})`.
  - `ConversationResultCard` gains `ValueChanged<ResultSelection>? onSelected` and visually matches the reference card hierarchy.

- [ ] **Step 1: Write failing card/highlight tests**

Assert rank badge, relevance badge, highlighted citation, reference metadata, and action labels:
`Développer`, `Ouvrir`, `Comparer`, `Passages similaires`, `Collection`, `Copier`, `Imprimer`, `Citer`.

Add Review Focus test `canonical_highlight_preserves_exact_text`: render text containing `l’amour`, `Église`, punctuation and accents; concatenate all `TextSpan.text` values and assert exact equality with the original string.

- [ ] **Step 2: Write failing selection/details tests**

At 1400 px, tapping/selecting a result must show the right detail pane with reference, page, relevance, context and print/export actions.

Add Review Focus test `details_panel_collapses_to_mobile_sheet_after_resize`: select a result at 1400 px, resize to 700 px, pump, assert no fixed `ResultDetailsPanel` remains in the row and a details action remains available to open the mobile surface.

- [ ] **Step 3: Run RED**

Run: `flutter test test/result_card_details_widget_test.dart`  
Expected: FAIL because highlighter/details/selection interfaces do not exist.

- [ ] **Step 4: Implement canonical highlighter**

Normalize only for matching. Build `TextSpan` segments from the original `text`; never rewrite characters. Use approved soft-yellow highlight colors from Task 1.

- [ ] **Step 5: Implement card hierarchy and details surfaces**

Desktop: selection updates a 300–350 px details pane.  
Mobile/compact: details open in a modal bottom sheet or full-width route.  
`Ouvrir` continues to pass exact canonical offsets to the reader.

`Citer` copies a formatted reference + exact citation.  
`Comparer` routes to Task 6 picker with current passage as passage A.

- [ ] **Step 6: Run GREEN**

Run: `flutter test test/result_card_details_widget_test.dart && flutter test test/passage_navigation_test.dart && flutter analyze`  
Expected: all PASS, analyzer clean.

- [ ] **Step 7: Commit**

```bash
git add lib/src/screens/canonical_highlight_text.dart lib/src/screens/result_details_panel.dart lib/src/screens/conversation_result_card.dart lib/src/screens/conversation_screen.dart test/result_card_details_widget_test.dart
git commit -m "feat: add reference result cards and detail pane"
```

---

### Task 6: Real advanced-navigation destinations: compare and scripture references

**Files:**
- Create: `lib/src/screens/comparison_picker_screen.dart`
- Create: `lib/src/screens/scripture_references_screen.dart`
- Modify: `lib/src/screens/comparison_screen.dart`
- Modify: `lib/src/screens/study_screen.dart`
- Modify: `lib/src/screens/conversation_shell_screen.dart`
- Modify: `lib/src/screens/conversation_result_card.dart`
- Test: `test/study_navigation_widget_test.dart`

**Interfaces:**
- Consumes: existing `SearchServiceV4`, `ComparisonScreen({required StudyPassage passageA, required StudyPassage passageB})`, `ScriptureReferenceEngine(CorpusRepository)`.
- Produces:
  - `ComparisonPickerScreen({StudyPassage? initialPassage})`; when `initialPassage == null`, user selects A then B; when present, user selects only B.
  - `ScriptureReferencesScreen()` with query field and canonical occurrence list.
  - Sidebar `Comparer` and `Références bibliques` become real functional destinations, not decorative items.

- [ ] **Step 1: Write failing compare tests**

Assert that opening with an initial passage shows it as passage A, search/selecting another result enables `Comparer`, and pressing it opens `ComparisonScreen`.

- [ ] **Step 2: Write failing scripture tests**

Assert a reference query can be submitted, occurrences are listed with canonical references, and tapping an occurrence calls/open routes via existing `openStudyPassage`.

- [ ] **Step 3: Run RED**

Run: `flutter test test/study_navigation_widget_test.dart`  
Expected: FAIL because the two destination screens do not exist.

- [ ] **Step 4: Implement compare picker and scripture screen**

Reuse existing engines; do not add a second search implementation. Keep mobile lists vertical and overflow-safe.

- [ ] **Step 5: Wire shell/sidebar/result-card actions**

`GrenierDestination.compare` → `ComparisonPickerScreen()`.  
`GrenierDestination.scripture` → `ScriptureReferencesScreen()`.  
Result-card `Comparer` → `ComparisonPickerScreen(initialPassage: hit.studyPassage)`.

- [ ] **Step 6: Run GREEN**

Run: `flutter test test/study_navigation_widget_test.dart && flutter analyze`  
Expected: PASS, analyzer clean.

- [ ] **Step 7: Commit**

```bash
git add lib/src/screens/comparison_picker_screen.dart lib/src/screens/scripture_references_screen.dart lib/src/screens/comparison_screen.dart lib/src/screens/study_screen.dart lib/src/screens/conversation_shell_screen.dart lib/src/screens/conversation_result_card.dart test/study_navigation_widget_test.dart
git commit -m "feat: add compare and scripture navigation destinations"
```

---

### Task 7: Restyle secondary screens without changing their domain logic

**Files:**
- Modify: `lib/src/screens/library_screen.dart`
- Modify: `lib/src/screens/personal_search_screen.dart`
- Modify: `lib/src/screens/concordance_screen.dart`
- Modify: `lib/src/screens/timeline_screen.dart`
- Modify: `lib/src/screens/collections_screen.dart`
- Modify: `lib/src/screens/settings_screen.dart`
- Modify: `lib/src/screens/study_screen.dart`
- Test: extend `test/study_navigation_widget_test.dart`

**Interfaces:**
- Consumes: Task 1 design tokens and existing domain methods exactly as-is.
- Produces: no new domain interface; all screens share consistent title spacing, cards, fields, chips, action-blue accents, and mobile-safe layouts.

- [ ] **Step 1: Add failing visual-contract widget assertions**

For each screen, assert common surface/background/input/card styling markers and no overflow at 390 px. Verify existing action labels and domain content still appear.

- [ ] **Step 2: Run RED**

Run: `flutter test test/study_navigation_widget_test.dart`  
Expected: FAIL on new design-system assertions.

- [ ] **Step 3: Apply shared visual system**

Only change layout/presentation. Preserve calls to repository, personal library, concordance, timeline, collections and settings controllers.

- [ ] **Step 4: Run GREEN plus existing study tests**

Run: `flutter test test/study_navigation_widget_test.dart test/study_engine_test.dart && flutter analyze`  
Expected: PASS, analyzer clean.

- [ ] **Step 5: Commit**

```bash
git add lib/src/screens/library_screen.dart lib/src/screens/personal_search_screen.dart lib/src/screens/concordance_screen.dart lib/src/screens/timeline_screen.dart lib/src/screens/collections_screen.dart lib/src/screens/settings_screen.dart lib/src/screens/study_screen.dart test/study_navigation_widget_test.dart
git commit -m "feat: align secondary screens with Grenier design"
```

---

### Task 8: PDF/printing identity, dark mode, accessibility, and responsive hardening

**Files:**
- Modify: `lib/src/printing/print_document_builder.dart`
- Modify: `lib/src/printing/print_service.dart`
- Modify: `lib/src/theme/grenier_theme.dart`
- Modify: relevant new presentation widgets from Tasks 2–5 for semantics/focus.
- Test: `test/print_branding_test.dart`
- Test: `test/grenier_accessibility_responsive_test.dart`

**Interfaces:**
- Consumes: `GrenierBrand`, existing `PrintableTurn`, `PrintableResult`, existing `PrintService`.
- Produces:
  - PDF header title `Le Grenier du Message`;
  - PDF includes query, filters, result count, rank, qualitative relevance, citation, canonical reference, page number, and existing required author/contact footer;
  - `PrintService` default filename changes to `Le_Grenier_du_Message.pdf` without changing its method signatures.

- [ ] **Step 1: Write failing PDF branding test**

Build a turn PDF and assert `debugPlainText`/debug sections contain `Le Grenier du Message`, the query, result rank, canonical citation/reference, and no visible `Message Bot` branding.

- [ ] **Step 2: Write failing accessibility/responsive tests**

Assert:
- icon-only important actions have tooltip/semantic labels;
- mobile controls meet minimum practical height where measurable;
- focusable desktop controls expose visible Material focus behavior;
- no overflow at 360×800, 760×900, 1180×800, 1440×900.

Add Review Focus test `dark_theme_highlight_and_focus_remain_readable`: pump the result-card/highlighter in dark theme and assert highlight background differs from both surface and foreground, and focused action remains visually distinct.

- [ ] **Step 3: Run RED**

Run: `flutter test test/print_branding_test.dart test/grenier_accessibility_responsive_test.dart`  
Expected: FAIL on branding/accessibility/reference-layout assertions.

- [ ] **Step 4: Implement PDF and accessibility hardening**

Keep printing fully offline. Preserve exact canonical citation text. Add semantics/tooltips only where needed; do not add decorative interactions.

- [ ] **Step 5: Run GREEN**

Run: `flutter test test/print_branding_test.dart test/grenier_accessibility_responsive_test.dart && flutter analyze`  
Expected: PASS, analyzer clean.

- [ ] **Step 6: Commit**

```bash
git add lib/src/printing/print_document_builder.dart lib/src/printing/print_service.dart lib/src/theme/grenier_theme.dart lib/src/screens test/print_branding_test.dart test/grenier_accessibility_responsive_test.dart
git commit -m "feat: finalize Grenier PDF accessibility and responsive polish"
```

---

### Task 9: Full regression, identity scan, Android/Windows builds, and release evidence

**Files:**
- Modify only if verification finds a real defect.
- Test: all `test/*.dart`.
- Validate: `tools/validate_v4_release.py`, existing Android compatibility workflow, Windows workflow.

**Interfaces:**
- Consumes: every prior task.
- Produces: verified release artifacts only; no new product interface.

- [ ] **Step 1: Scan visible branding**

Run a repository search for user-visible `Message Bot` strings in `lib/` and printing code.  
Expected: no remaining visible product branding except intentionally technical/internal compatibility comments or tests that explicitly assert absence.

- [ ] **Step 2: Run full analyzer and test suite**

Run:

```bash
flutter analyze
flutter test
python tools/validate_v4_release.py
```

Expected:
- analyzer: `No issues found!`;
- tests: 100% PASS;
- validation: `V4_RELEASE_VALIDATION: OK`.

- [ ] **Step 3: Verify original regression suites explicitly**

Run:

```bash
flutter test test/passage_navigation_test.dart test/v4_ir_contract_test.dart test/corpus_installer_contract_test.dart test/personal_library_test.dart
```

Expected: PASS; exact navigation, IR, corpus installation and user DB behavior unchanged.

- [ ] **Step 4: Push and inspect GitHub Actions**

Android job must complete:
- Android 15 target configuration;
- ARM64 release APK;
- APK signature verification;
- 16 KB alignment verification;
- zero warning-like log hits.

Windows job must complete:
- Windows x64 release;
- artifact upload;
- zero warning-like log hits.

- [ ] **Step 5: Compare artifact UI against the approved reference checklist**

Manual acceptance checklist at minimum:
- desktop banner/sidebar/workspace/details pane recognizable;
- mobile home recognizable;
- mobile conversation/result-expanded layout recognizable;
- filters visible;
- yellow canonical term highlighting visible;
- no horizontal overflow;
- PDF preview branded `Le Grenier du Message`.

Record any discrepancy as a defect before completion; do not waive reference-critical differences silently.

- [ ] **Step 6: Commit verification-only fixes if any**

If verification required no code changes, do not create an empty commit. If fixes were required, commit only after their RED→GREEN regression test.

