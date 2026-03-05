---
name: Iterating on UX and Design
description: Best practices and guidelines for AI models when responding to subjective UX/UI design requests and visual tweaks in this Flutter project.
---

# UX and Design Iteration Guidelines

When asked to update, tweak, or redesign UI elements based on subjective user preferences (e.g., "make this look cleaner," "improve the padding," "add more visual hierarchy"), follow these principles to ensure high-quality, beautiful, and consistent design.

## 1. Request and Analyze Visual Context First
- **Request a Screenshot:** Before diving into complex layout changes or visual overhauls, it is highly recommended to ask the user to provide a screenshot or screen recording of the current UI. Understanding the starting point visually is incredibly helpful for subjective design tasks.
- **Analyze the Screenshot:** When provided with visual context, observe the following:
  - Current spacing, typography hierarchy, and alignment.
  - Color contrast and how elements stand out against the background.
  - Overall visual balance and areas that feel cluttered or disconnected.

## 2. Adhere to the Established Design System
- **Use Theme context:** Always leverage `Theme.of(context)` for colors, text styles, and shaping. Do not introduce arbitrary hardcoded hex colors or non-standard font sizes unless explicitly requested.
- **Maintain Consistency:** If the app uses a specific style (e.g., rounded corners of `12.0`, elevated cards with subtle shadows), ensure your new designs match this established aesthetic. Look at surrounding widgets to infer the design language.

## 3. Principles for Subjective Design
- **Improve Spacing and Grouping:** Often, making something "look better" involves adding appropriate whitespace. Use `SizedBox` for explicit gaps or standardize padding (e.g., `EdgeInsets.all(16.0)`) to let elements breathe and clearly group related items.
- **Visual Hierarchy:** Guide the user's eye by varying font weights, sizes, and opacities (e.g., using `Theme.of(context).textTheme.bodySmall` with a muted color for secondary text). 
- **Subtle Polish:** Consider adding subtle touches that elevate the feel of the app, such as slight border radiuses, gentle entry animations, or improved interactive states (InkWell splashes, hover effects if applicable).

## 4. Iterative Collaboration
- **Explain Design Choices:** When you propose a UI change, explain *why* it improves the UX. (e.g., *"I increased the padding and darkened the title color to create a clearer visual hierarchy between the header and the body text."*)
- **Provide Options (If Ambiguous):** If the user's request is very broad, consider suggesting a couple of different approaches (e.g., a card-based layout vs. a flat list) and implementing the preferred one.

## 5. Documentation and Intent
- When committing your changes, follow the repository's `Commit Message Guidelines`. 
- Use the `style:` or `feat(ui):` commit types appropriately.
- Ensure the commit message body reflects the design intent behind the changes.
