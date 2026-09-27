---
name: google-style
description: Google developer documentation style for prose in this repo — read docs/agents/writing-style.md and edit the draft against it. Use when writing or editing README.md or a page under docs/, when drafting a PR description or issue comment, or when asked to copy-edit, tighten, or style-check existing prose.
---

Read `docs/agents/writing-style.md`. It is the rule set — the Google
developer documentation style guide, the rules that drafts break by default,
the swap table, and this repo's overrides.

Settle what the page is before you edit it. `README.md` and
`docs/fleet-design.md` are explanation. `docs/operations.md` and
`docs/join-the-fleet.md` are how-to. A rule that fits a how-to is
wrong in explanation — most of all the rule against *we*, which
explanation is the place for.

Two passes over the draft, in this order:

1. **Cut.** Sweep once per swap-table row and once per banned word. A
   sentence that loses nothing when the word goes loses the word.
2. **Rebuild.** Passive to active with a named actor. Trailing conditions to
   leading conditions. A sentence carrying a second idea split in two. *We*
   to the named actor where the code is the actor, Title Case headings to
   sentence case.

Done when every rule in `writing-style.md` has been applied to the whole
draft, not to its first paragraph. Close by naming the rules you applied,
one line each, and any you skipped and why — a silently rewritten draft
hides what changed.
