---
name: Issue Refinement & Verification
description: A systematic process for analyzing, verifying, and refining GitHub issues before implementation.
---

# Issue Refinement & Verification

This skill provides a structured workflow for Antigravity to process GitHub issues. Use this skill when a user asks you to "refine", "groom", or "look into" a specific GitHub issue.

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

### 4. Refinement Artifact
Create a detailed "Issue Refinement" artifact for the user. Do not modify the code yet. The artifact should include:

- **Revised Description**: A clear, structured version of the issue (Summary, Steps to Reproduce, Expected vs. Actual).
- **Technical Root Cause**: (For bugs) A hypothesis or confirmed explanation of why the issue is occurring.
- **Affected Components**: A list of files and functions that need to be modified.
- **Proposed Suggestions**:
    - High-level architectural or logic changes.
    - Specific codebase patterns or utilities to leverage.
    - Potential side effects or risks.
- **Verification Plan**: How the fix should be verified (automated tests, manual steps).

### 5. Update GitHub (Optional)
If the user approves the refinement, offer to update the GitHub issue description with the refined version using `gh issue edit <ISSUE_ID> --body-file <FILE>`.

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

## Proposed Suggestions
- Wrap the callback in a `mounted` check.
- Use a `ValueNotifier` instead of `setState` for more granular updates.

## Risk Assessment
- Might conflict with the existing `auto_advance_timer.dart` logic.
```
