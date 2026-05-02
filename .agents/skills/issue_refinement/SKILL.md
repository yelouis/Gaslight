---
name: Issue Refinement & Verification
description: A systematic process for analyzing, verifying, and refining GitHub issues before implementation.
---

# Issue Refinement & Verification

This skill provides a structured workflow for Antigravity to process GitHub issues. The goal is to enrich existing issues with technical context, root cause analysis, and reproduction steps, and then update the issue on GitHub. 

> [!IMPORTANT]
> The primary objective of this skill is to **rewrite and update the GitHub issue description**. 
> DO NOT create a local `implementation_plan.md` or start code changes as part of this skill.

## Workflow

### 1. Fetch Issue Context
- Use `gh issue view <ISSUE_ID>` to read the full description and any comments.
- Note the labels, author, and any linked pull requests or other issues.

### 2. Codebase Investigation
- Search for keywords from the issue title and description using `grep_search`.
- Identify the core files and components involved.
- Use `git log -p <FILE_PATH>` to see recent changes that might have introduced the bug or are relevant to the feature.

### 3. Verification (If Applicable)
- **For Bugs**: 
    - Attempt to reproduce the bug by creating a minimal reproduction script or a new unit test in the `test/` directory.
    - Check the logs or run the app (if possible) to confirm the unexpected behavior.
- **For Features/Refactors**:
    - Verify the current implementation of the affected components.
    - Identify any technical debt or architectural constraints.

### 4. Draft Refined Issue Content
Prepare a detailed draft for the GitHub issue description. This should focus on providing context and detail for whoever eventually implements the fix. The draft should include:

- **Revised Description**: A clear, structured version of the issue (Summary, Steps to Reproduce, Expected vs. Actual).
- **Technical Context/Root Cause**: A technical explanation of where the issue resides in the code and why it occurs.
- **Affected Components**: A list of specific files, classes, or functions involved.
- **Implementation Hints**: (Optional) Brief technical suggestions or pointers to relevant utilities/patterns.

### 5. Update GitHub Issue
Present the refined draft to the user. Once approved, update the GitHub issue description using:
`gh issue edit <ISSUE_ID> --body-file <PATH_TO_DRAFT_FILE>`

## Example Structure for Refined Issue Description

```markdown
## Summary
[Clear and concise summary of the issue]

## Technical Context
- **Affected Files**: `lib/widgets/example.dart`, `lib/models/data.dart`
- **Root Cause**: The `setState` call is missing in the asynchronous callback, leading to UI stale states.

## Steps to Reproduce
1. Open the lobby.
2. Click "Join" while the timer is at 1s.
3. Observe the crash.

## Technical Details & Hints
- The logic in `lib/utils/timer_controller.dart` handles the 1s edge case incorrectly.
- Suggest checking the `isMounted` property before calling the update.
```

