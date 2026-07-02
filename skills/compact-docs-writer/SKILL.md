---
name: compact-docs-writer
description: Rewrite or refine a doc for maximum token economy without losing any rule or intent. Use for docs kept in version control and regularly re-read by agents; skip throwaway docs like plans.
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
license: MIT
metadata:
  author: Francesco Borzì
  version: "1.1"
---

# Compact docs writer

Rewrite a doc — or draft a new one — for **token economy**: carry **all** its rules and intent in
the **least text possible**, because the doc loads into agent context and is paid for on every
read. Then prove nothing was lost: present the change with a word delta measured from the files,
and apply only on approval.

## Core principle

Write each piece of information with the least text that still preserves every rule, constraint,
edge case, and intent. Two directions, equally binding:

- Cut duplication, filler, and anything restatable more briefly.
- **Never** drop text whose removal loses information or instruction, just to be shorter.

Recurring reflex: *"Can this exact rule be said in fewer words?"* — if yes, do it.

Compaction counts words and information density, not whitespace. Blank lines between distinct chunks
cost effectively nothing and aid the human reader, so keep them where they help; never collapse a
long passage into one dense block to look shorter.

## Workflow

1. **Compact.** Rewrite the target to meet the core principle in one pass — a first draft already
   meets the standard; don't ship a loose draft expecting a later pass to tighten it. If a chunk is
   needed only in a sub-case and is big enough to tax every read, you *may* suggest extracting it
   into a referenced file — never force it; the enforced standard is compact text, not splitting.
2. **Self-review** before presenting (terse yes/no):
   - Every original rule, instruction, edge case, and intent still present?
   - Every surviving rule in the fewest words — tight phrasing, not just free of redundancy?
   - Removal audit against the **rendered diff, not memory**: read every removed line — and every
     reordered or merged one, which count as removals — and confirm each drops only duplication or
     filler, never a rule, instruction, edge case, or nuance. After a merge, re-verify the result
     still carries every item from both sources.
3. **Present & confirm.** Show the change as a diff with a word/token delta **measured from the
   files, never estimated**: write the not-yet-applied draft to a scratch file (in the session's
   temp/scratch dir, never the working tree) and `wc -w` it against the original. Label it not yet
   applied and awaiting approval; apply only on approval; after applying, say so plainly.
