---
name: Fixing UI Issues
description: Best practices and guidelines for AI models when diagnosing and fixing UI issues in this Flutter project.
---

# UI Issue Resolution Guidelines

When asked to fix or debug UI issues (such as overflows, layout constraints, clipping, or styling bugs) in this Flutter application, follow these steps and principles to ensure high-quality, maintainable, and responsive solutions.

## 1. Diagnose First, Fix Second
- **Understand the Layout Tree:** Do not blindly wrap widgets in `Expanded` or `SingleChildScrollView`. Analyze the widget tree to understand *why* the constraints are failing (e.g., an unbounded height constraint inside a `Column`).
- **Constraint Fundamentals:** Remember that in Flutter, constraints go down, sizes go up, and parents set positions. Identify which widget is passing infinite constraints to a child that expects bounded ones.

## 2. Common Flutter UI Pitfalls
- **RenderFlex Overflows (Yellow/Black Striped Tape):**
  - If a `Row` or `Column` child overflows, determine if it should scale down (use `Flexible` or `Expanded`), or if the parent should allow scrolling (`SingleChildScrollView`).
  - Be careful with nested ListViews or ScrollViews. If necessary, use `shrinkWrap: true` and `physics: NeverScrollableScrollPhysics()` for inner scrollables.
- **Text Truncation:**
  - Ensure text elements gracefully degrade by using `overflow: TextOverflow.ellipsis`, `maxLines`, or wrapping them in flexible widgets.
- **Responsiveness:**
  - Avoid hardcoding specific pixel sizes (`width: 300`, `height: 800`) unless explicitly required by a design system.
  - Rely on Flex layouts (`Expanded`, `Flexible`), `LayoutBuilder`, or `MediaQuery` to accommodate various screen sizes across mobile and desktop.

## 3. Making the Fix
- **Minimal Interference:** Apply the narrowest fix needed to solve the issue. Avoid rewriting an entire screen's layout unless the existing hierarchy is fundamentally broken.
- **Use the Theme:** When altering padding, text styles, or colors, use the existing design system (`Theme.of(context)`, standardized padding constants, or centralized color definitions). Do not introduce arbitrary numbers or hardcoded hex colors.
- **Widget Extraction:** If fixing the UI requires excessive nesting, extract the updated segment into a separate, focused Widget class.

## 4. Documentation and Intent
- When committing your changes, follow the repository's `Commit Message Guidelines`. 
- Use the `fix(ui): <description>` format.
- Critically, explain *why* the overflow or layout bug occurred in the commit body (e.g., *"The Column parent was passing infinite width to the Row, so I wrapped the text in Expanded to bound it."*).
