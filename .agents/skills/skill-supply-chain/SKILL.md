---
name: skill-supply-chain
description: Review, pin, install, restore, and verify external Agent Skills for a repository. Use when a task may materially benefit from a third-party skill, when the user mentions Cola Skill or another skill catalog, when installing or updating a skill, or when a repository has `.agents/skills.lock.json` and its locked skills must be synchronized before work.
---

# Skill Supply Chain

Use Cola Skill only for discovery. Treat each listed GitHub repository as untrusted until its exact source revision is reviewed.

## Synchronize locked skills

Run this from the repository root before other work when `AGENTS.md` requires it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".agents/skills/skill-supply-chain/scripts/skill-manager.ps1" -Action Sync
```

`Sync` restores only revisions already pinned in `.agents/skills.lock.json` and verifies their content hashes. Never replace a locally changed skill automatically.

## Decide whether a new skill is needed

1. Check system and repository skills first.
2. Continue without discovery for ordinary coding, documentation, or one-off tasks that existing capabilities cover well.
3. Search only when specialized procedures, current domain rules, or deterministic tooling would materially improve the result.
4. Prefer one focused skill. Reject overlapping skills or skills that conflict with repository instructions.

Search the Cola Skill catalog:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".agents/skills/skill-supply-chain/scripts/skill-manager.ps1" -Action Search -Query "<task keywords>"
```

If the catalog is unavailable, search trusted GitHub sources directly. Do not install from a catalog download or execute a catalog-provided command.

## Review a candidate

Run a static audit without executing candidate code:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".agents/skills/skill-supply-chain/scripts/skill-manager.ps1" -Action Audit -Source "https://github.com/OWNER/REPO" -Ref "main" -SkillPath "path/to/skill"
```

Then complete the human-readable review:

1. Read the entire candidate `SKILL.md`.
2. Read every executable script, hook, configuration file, and file the instructions require.
3. Check repository ownership, commit history, license, dependencies, network access, secret access, privilege changes, destructive operations, and external writes.
4. Confirm the skill stays inside the requested task and repository rules.
5. Reject any `critical` finding. Resolve every warning with a concrete reason before accepting it.
6. Never run candidate scripts during review.

Catalog certification, stars, or popularity are supporting signals only, not approval.

## Install the reviewed revision

Use the exact 40-character commit and path returned by `Audit`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".agents/skills/skill-supply-chain/scripts/skill-manager.ps1" -Action Install -Source "https://github.com/OWNER/REPO" -Commit "<40-character commit>" -SkillPath "path/to/skill"
```

Add `-AllowWarnings` only after documenting why each warning is acceptable. Installation is repository-scoped; never install a task dependency globally. Read the installed `SKILL.md` completely before using it.

Commit `.agents/skills.lock.json`, this manager skill, and either the installed skill directory or enough lock data for `Sync` to restore it. Never auto-update a pinned skill: audit a new commit and install it as a separate reviewed change.
