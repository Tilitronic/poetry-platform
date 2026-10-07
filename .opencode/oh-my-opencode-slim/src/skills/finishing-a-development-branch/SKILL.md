---
name: finishing-a-development-branch
description: Use when implementation is complete, all tests pass, and you need to decide how to integrate the work
---

# Finishing a Development Branch

## Overview

Guide completion of development work by presenting clear options and handling chosen workflow.

**Core principle:** Verify tests → Detect environment → Present options → Execute choice → Clean up.

## The Process

### Step 1: Verify Tests
Run project's test suite. If tests fail, stop. Cannot proceed until tests pass.

### Step 2: Detect Environment
Determine workspace state (normal repo, named branch worktree, detached HEAD).

### Step 3: Determine Base Branch
Try common base branches (main, master).

### Step 4: Present Options

**Normal repo / named branch — 4 options:**
1. Merge back to base branch locally
2. Push and create a Pull Request
3. Keep the branch as-is
4. Discard this work

**Detached HEAD — 3 options:**
1. Push as new branch and create a Pull Request
2. Keep as-is
3. Discard this work

### Step 5: Execute Choice
Follow the selected option's steps exactly.

### Step 6: Cleanup Workspace
Only for Options 1 and 4. Options 2 and 3 preserve the worktree.

## Red Flags

**Never:**
- Proceed with failing tests
- Delete work without confirmation
- Clean up worktree for Option 2
- Run `git worktree remove` from inside the worktree

**Always:**
- Verify tests before offering options
- Get typed confirmation for discard
- `cd` to main repo root before worktree removal
