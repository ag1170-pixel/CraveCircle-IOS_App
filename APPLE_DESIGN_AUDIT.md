# Apple Design Audit: CraveCircle (AICookBook iOS)

> Conducted using the **Apple Design Skill** grounded in Apple's Human Interface Guidelines (123 official HIG pages) and design-craft review principles.
> Date: November 6, 2026  
> Platform: iOS 26+ (SwiftUI + UIKit)  
> Scope: Entire CraveCircle iOS codebase with deep inspection of Navigation, Recipe Detail, Cooking Modes, Grocery, and Design System tokens.

---

## 1. Summary

**Overall Rating: Good (with specific actionable improvements)**  
**The Design's Thesis:** *An editorial, living cookbook where full-bleed food photography leads, cooking is hands-free, and cooking with friends is social and seamless.*  
**The Signature Element:** The stretchy parallax food-photography hero paired with a floating, responsive customization dial (`slider.horizontal.3`) that unfolds into preparation actions (Plan, Scale, Grocery).

CraveCircle demonstrates remarkable design maturity: it respects Reduce Motion and Reduce Transparency across nearly all custom transitions, uses purposeful haptics, maintains strict separation between brand identity (`#EA5A38`) and interactive UI accents (`#1B1A17` / `#F2EFE8`), and avoids generic AI-chat interfaces in favor of structured, recipe-first surfaces.

However, the audit identified **1 Critical accessibility restriction** (a 1.35× Dynamic Type cap), **3 High-severity convention and responsive layout gaps** (icon-only tab bar items, unpadded 28pt touch targets, and `UIScreen.main` dependencies that hinder iPad/foldable adaptation), and several **Medium polish items** detailed below.

---

## 2. Lens 1: Accessibility (Failures are Critical)

### 🔴 Critical: Dynamic Type Scaling Artificially Capped at 1.35×
- **What**: In `DesignSystem.swift:101`, `AppFont.scaled(_:)` caps font growth at `min(scaled, size * 1.35)`.
- **Why**: `accessibility.md › Vision` & `typography.md › Supporting Dynamic Type`:
  > *"Make sure people can adjust the size of your text or icons to make them more legible, visible, and comfortable to read. Ideally, give people the option to enlarge text by at least 200 percent."*
  Capping scaling at 135% prevents users who rely on Apple's Accessibility Sizes (`AX1` through `AX5`) from reading comfortably.
- **Fix**: Replace rigid container heights with flexible, content-driven layouts (`ViewThatFits`, `ScrollView`, and adaptive `GridItem`) so the UI flexes naturally under large type, and remove the `1.35` multiplier cap.

```swift
// DesignSystem.swift
private static func scaled(_ size: CGFloat) -> CGFloat {
    let metrics = UIFontMetrics(forTextStyle: textStyle(for: size))
    let traits = UITraitCollection(preferredContentSizeCategory: contentSizeCategory)
    return metrics.scaledValue(for: size, compatibleWith: traits) // Remove 1.35x cap
}
```

---

### 🟠 High: Undersized Touch Target on Hero Follow Pill
- **What**: In `RecipeDetailScreen.swift:395`, the Follow button has `.frame(height: 28)` without an expanded minimum tap area.
- **Why**: `accessibility.md › Controls` & `buttons.md › Best practices`:
  > *"As a general rule, a button needs a hit region of at least 44x44 pt to ensure that people can select it easily, whether they use a fingertip, a pointer, their eyes, or a remote."*
- **Fix**: Keep the visual capsule at 28pt height, but expand the hit target to 44×44 pt using `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` (just like `GlassIconButton` already does).

```swift
// RecipeDetailScreen.swift
.frame(height: 28)
.frame(minWidth: 44, minHeight: 44)
.contentShape(Rectangle())
```

---

### 🟡 Medium: Brand Color Contrast for Small Captions
- **What**: White text on Brand Coral (`#EA5A38`) yields a contrast ratio of **4.1:1**.
- **Why**: `accessibility.md › Vision`:
  > *"Up to 17 pts: 4.5:1 minimum contrast ratio. 18 pts or bold: 3:1."*
  While primary buttons with 15–16pt bold typography meet the 3:1 bold threshold, smaller badges (such as 11pt tags or unbold text) fail WCAG AA (4.5:1).
- **Fix**: Ensure all white text placed on `#EA5A38` is styled bold (`.bold`), or provide an accessible high-contrast variant (`#D94825`, 4.8:1) when the user enables *Increase Contrast*.

---

### 🟡 Medium: Missing `accessibilityReduceTransparency` Branches on Secondary Badges
- **What**: In `RecipeDetailScreen.swift:424, 466, 516`, `.background(.ultraThinMaterial, in: Capsule())` is used directly without checking `reduceTransparency`.
- **Why**: `materials.md` & `code-audit.md › Liquid Glass in code`:
  > *"No branch on accessibilityReduceTransparency around custom glass or blur."*
- **Fix**: Use the established project convention:
```swift
.background(
    reduceTransparency ? AnyShapeStyle(AppTheme.surfaceElevated) : AnyShapeStyle(.ultraThinMaterial),
    in: Capsule()
)
```

---

## 3. Lens 2: Platform Conventions (Findings are High / Medium)

### 🟠 High: System Tab Bar Omits Text Labels
- **What**: In `RootView.swift:350-375`, tabs specify icons only (`Image(systemName: AppTab.home.icon)`) with no text label view.
- **Why**: `tab-bars.md › Best practices`:
  > *"In iOS and iPadOS, a tab bar item displays an icon and a text title... Include a short text label with each tab item to clarify its purpose."*
- **Fix**: Supply a standard `Label` with both title and system symbol for each tab:

```swift
// RootView.swift
Tab(value: AppTab.home) {
    HomeScreen(showingImportSheet: importSheetBinding)
} label: {
    Label(AppTab.home.title, systemImage: tab == .home ? "house.fill" : "house")
}
```

---

### 🟠 High: `UIScreen.main.bounds` Breaks Split View, iPad & iPhone Duo
- **What**: In `HomeScreen.swift:1044` and `AddRecipeSheet.swift:33`, layout dimensions are derived from `UIScreen.main.bounds`.
- **Why**: `designing-for-iphone-duo.md › Best practices` & `code-audit.md`:
  > *"Avoid fixed widths and display-specific dependencies... UIScreen.main references the hardware screen, not the app window."*
- **Fix**: Compute card dimensions using `GeometryReader` container width or adaptive `LazyVGrid` columns (`GridItem(.adaptive(minimum: 160))`).

---

### 🟡 Medium: Tab Icons Missing Filled Variants on Selection
- **What**: All tabs use outline glyphs (`"house"`, `"safari"`, `"basket"`, `"person"`) regardless of active selection state.
- **Why**: `tab-bars.md › Best practices`:
  > *"Prefer filled symbols for tab bar items, or symbols that have filled variants for their selected state."*
- **Fix**: Toggle between standard outline and `.fill` symbols depending on `tab == selected`.

---

## 4. Lens 3: Visual Design and Craft

### Point of View & Identity
- **The Good**: CraveCircle has a distinct, memorable personality. Rather than feeling like a generic AI wrapper, the experience centers on food aesthetics:
  - Deep warm backgrounds (`#FAF8F3` in light mode, `#16130F` in dark mode).
  - Editorial New York serif title typography (`AppFont.serif`).
  - Warm coral brand presence (`#EA5A38`) used strictly as an identity accent, paired with charcoal UI actions (`#1B1A17`).
- **Signature Customization Dial**:
  - The new bottom-trailing customization dial (`slider.horizontal.3`) provides a dedicated, tactile control center for recipe prep without cluttering the main reading view.
  - Tapping cleanly springs open three essential prep flows: **Plan Recipe**, **Scale Recipe**, and **Add to Grocery**.
- **Removal of Decorative Glows**:
  - Removing artificial colored shadow glows (`AppTheme.brand.opacity(0.35)`) and replacing them with neutral Apple drop shadows (`.shadow(color: .black.opacity(0.14), radius: 6, y: 3)`) grounded the interface in physical materials.

---

## 5. Lens 4: Interaction & Modality

### Modality Structure (`sheets.md` & `modality.md`)
- **Detents & Dismissal**:
  - `ScaleRecipeSheet`, `AddToGrocerySheet`, and `MealPlanPickerSheet` all use `.presentationDetents([.medium, .large])` with `.presentationDragIndicator(.visible)`. This allows progressive disclosure: the user can make quick adjustments at half height or drag up to review long ingredient lists.
  - Modal sheets pair a leading "Cancel" with a prominent primary confirmation button at the bottom.
- **In-Context Toast over Intrusive Alerts**:
  - Adding ingredients to the grocery list triggers a floating capsule banner (`Added X items to Grocery List!`) rather than an alert dialog. This respects Apple's recommendation to keep confirmations unobtrusive and inline.

---

## 6. Lens 5: Content and Writing

### Consistency Audit
- **Capitalization**: Title-style capitalization is well-maintained across buttons and navigation ("Start Cooking", "Plan Recipe", "Scale Recipe", "Add to Grocery").
- **Clarity of Actions**:
  - "Apply to Recipe" in `ScaleRecipeSheet` explicitly communicates the outcome by including the target serving count: `Apply to Recipe (4 Servings)`.
  - "Add 6 Items to Grocery List" in `AddToGrocerySheet` clearly indicates the batch size.
- **One Minor Copy Inconsistency**:
  - The ellipsis menu in `RecipeDetailScreen.swift` has `"Add to Grocery List"`, whereas the bottom pop-out button is labeled `"Add to Grocery"`. Align both to `"Add to Grocery"`.

---

## 7. What Works (Keep & Protect)

1. **Reduce Motion Parity**: Every parallax header, double-tap burst, spring pop-out, and auto-playing reel properly respects `@Environment(\.accessibilityReduceMotion)`.
2. **Flashcard Cook Mode**: Hands-free voice commands ("Next", "Back", "Timer") and large typography solve a genuine physical problem (greasy hands in the kitchen).
3. **On-Device Machine Learning**: Using Apple's `FoundationModels` and `SpeechAnalyzer` guarantees privacy and instant offline functionality.
4. **Haptic Hierarchy**: Distinct feedback for taps (`.light`), selection toggles (`.selectionChanged`), and completed tasks (`.success`).

---

## 8. Summary Action Checklist

| Priority | Issue | Location | Recommended Action |
|:---|:---|:---|:---|
| **Critical** | 1.35× Dynamic Type Cap | `DesignSystem.swift:101` | Remove artificial cap and make cards flex adaptively. |
| **High** | Follow Button Touch Target | `RecipeDetailScreen.swift:395` | Add `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())`. |
| **High** | Missing Tab Bar Text Labels | `RootView.swift:352-375` | Use `Label(title, systemImage:)` with filled variant on selection. |
| **High** | `UIScreen.main.bounds` Usage | `HomeScreen.swift:1044` | Derive card width from `GeometryReader` / size classes. |
| **Medium** | Missing Transparency Branches | `RecipeDetailScreen.swift:424` | Branch on `reduceTransparency` for secondary pill backgrounds. |
| **Low** | Menu Copy Alignment | `RecipeDetailScreen.swift:626` | Align menu title to `"Add to Grocery"`. |

