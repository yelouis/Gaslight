---
name: Issue Resolution and Documentation Transition
description: A workflow for systematically implementing remediation paths for unresolved issues and transitioning them to the "Resolved" section of the documentation.
---

# Issue Resolution Skill

This skill allows Antigravity to execute an iterative implementation plan based on the unresolved bugs documented in the project. It focuses on taking a selected issue from the unresolved sections in [ongoing_general_errors.md](../../../docs/ongoing_general_errors.md), applying the fix to the codebase, verifying it, and updating the engineering history by moving the issue to the resolved section.

## 📋 Pre-requisites
1. Access to the target documentation file: [ongoing_general_errors.md](../../../docs/ongoing_general_errors.md).

## 🛠 Workflow Steps

### 1. Issue Selection & Prioritization
- Read the unresolved sections in [ongoing_general_errors.md](../../../docs/ongoing_general_errors.md):
  - `## 2. Unresolved Cross-Cutting Bugs (Current)`
  - `## 3. New Bugs Found — Full Code Review (April 2026)`
- Identify the issue to work on. If the user did not specify one, present the list of unresolved bugs and ask the user to select one or choose the highest priority/most critical bug first and ask for confirmation.
- Note the **Error Description**, **Impact**, and suggested **Fix** from the documentation.

### 2. Context Gathering
- Locate the relevant source files and code locations mentioned in the issue (e.g., "Root Files" or specific line ranges mentioned in the description).
- Search the codebase using `grep_search` to trace the related logic.

### 3. Implementation & Verification
- Implement the changes in the codebase.
- **Validation**:
  - Run the Flutter tests (e.g. using `flutter test`) to ensure no regressions.
  - Write targeted unit/widget tests or run a scratch script to verify that the specific bug is fixed.
- **Conflict Handling**:
  - If the suggested fix is technically impossible, introduces unwanted side effects, or is significantly more complex than anticipated, stop and consult the user. Update the issue documentation with the new findings if needed.

### 4. Documentation Transition
- Once the fix is verified, edit [ongoing_general_errors.md](../../../docs/ongoing_general_errors.md) to:
  - **Remove** the bug from the unresolved section (`## 2. Unresolved Cross-Cutting Bugs (Current)` or `## 3. New Bugs Found — Full Code Review (April 2026)`).
  - **Add** the bug to the resolved section (`## 1. Resolved Minor Errors (10-Player Simulation)`).
  - **Reformat** the bug description to follow the existing resolved issue style:
    - Change the header to: `### [Bug Title] (Resolved)`
    - Format as:
      - `- **Error Description**: [A brief description of what was wrong, matching or condensing the original error description]`
      - `- **Resolution**: [A summary of the actual code changes made to resolve it]`

### 5. Cleanup
- Remove any temporary scratch scripts or test artifacts created during implementation.

## 🏁 Success Criteria
- The codebase reflects the implementation of the selected bug fix.
- The documentation accurately transitions the issue from unresolved to resolved.
- All formatting matches the existing style in [ongoing_general_errors.md](../../../docs/ongoing_general_errors.md).
