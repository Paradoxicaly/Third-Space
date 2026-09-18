# Phase 2 Git Skills Check

This evidence is part of the Third Space Capstone repository.

## Branch and merge

- Created `phase2/git-skills-check`.
- Added this evidence document on the feature branch.
- Merged the branch into `main` with a merge commit.

## Conflict resolution

- Created a controlled conflict in `conflict-exercise.txt` by changing the same line on two branches.
- Resolved the conflict by combining both useful requirements: reviews should be kind, constructive, and specific.
- Committed the resolved result on `main`.

## Safe recovery

- Made an unwanted uncommitted edit to `README.md`.
- Used `git status` to identify the modified file.
- Used `git diff` to inspect the unwanted line.
- Used `git restore README.md` to discard only that uncommitted edit.
- Confirmed the working tree was clean afterward.

## Command explanations

- `git restore` replaces working-tree content with a known version and is useful for discarding uncommitted edits.
- `git reset --soft` moves the branch pointer while keeping changes staged for a new commit.
- `git reset --hard` moves the branch pointer and discards staged and unstaged changes, so it is dangerous.
- `git revert` creates a new commit that reverses an earlier commit while preserving the existing history.
