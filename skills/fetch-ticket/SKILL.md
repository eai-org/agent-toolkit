---
name: fetch-ticket
description: Fetch one or more tickets/issues from their tracker (Azure DevOps, Jira, GitHub, …) and save each as a self-contained markdown ticket file. Fetch only — no analysis or planning.
license: MIT
metadata:
  version: "1.13"
---

# Ticket Fetcher

**Fetch only** — no analysis, requirements, or planning. Output is a self-contained `.TICKET.md`.

## Source & access

Identify the tracker from the input (URL host, or id shape) and fetch through the matching MCP
server — e.g. **Azure DevOps MCP** for ADO work items, **Atlassian MCP** for Jira issues, **GitHub
MCP / `gh`** for GitHub issues. Use whichever equivalent tools are connected; tool name prefixes
vary by config. Resolve once any handle the MCP needs (e.g. Atlassian `cloudId`, ADO project) and
reuse it. If the input is ambiguous, ask the user — don't guess. If no matching MCP is connected:
a public ticket may be scraped from its URL as a fallback (you may still suggest installing the
matching MCP when it would do the job better); a private one can't — the URL returns a login page,
not the ticket — so stop and tell the user to install and authenticate the matching MCP server,
then re-run.

## Your task

1. **Resolve the input.** Accept a full ticket URL or a bare id/key; extract the identifier. If the
   tracker uses a key prefix (e.g. `XX-1234`), keep it; otherwise use the bare number. If the input
   is unrecognizable, ask.
2. **Fetch the ticket.** Get the work item/issue with its full field set, comments inline, and
   related links/relations expanded. Capture **everything** the ticket carries — don't pre-filter to
   a fixed set of fields. Convert whatever rich-text form you get (HTML, ADF, …) to clean Markdown.
3. **Pick a slug.** Short kebab-case slug, 3–5 words, from the title/summary — greppable, don't
   overthink it.
4. **Decide the output directory.** First resolve the project's **planning directory** (e.g.
   `.agents/plans/`) — follow the project's/user's convention for where plans live. Inside it,
   first match wins:
   1. **Re-fetch** — the ticket already has a plan directory or flat `.TICKET.md`: suggest the
      next `<id>-<slug>-v2`, `-v3`, … name beside it (directory or filename alike) — **never
      overwrite**; history per re-fetch is kept on purpose.
   2. **Existing family** — an ancestor (parent/epic, nearest first) has a plan directory
      (`<ancestor-id>-*`, hyphen included; confirm via its `.TICKET.md` that it's really that
      ancestor's; latest `-vN` when several), or a group directory's `## Ticket set` lists this
      ticket or a sibling: write flat into it (`<dir>/<id>-<slug>.TICKET.md`) and update the
      `## Ticket set` sections per [multiple-tickets.md](multiple-tickets.md).
   3. **Otherwise** — a new `<id>-<slug>/` subdirectory.

   In doubt at any point (no convention defined, unsure a directory is really the family's, …):
   ask the user. **Never guess** — better one extra question than a potential mistake.
5. **Write the ticket file** at `<output-dir>/<id>-<slug>.TICKET.md`.
6. **Download attachments** — if the ticket carries attachments, inline images, external linked
   assets, or design-tool links, read [attachments.md](attachments.md) first, then download into
   the output directory; warn on any that fail.
7. **Print the result** — project-relative paths and the next-step line (see Next step).

## Multiple tickets

The input may list several tickets — before picking slugs and directories, read
[multiple-tickets.md](multiple-tickets.md): it governs grouping into shared directories, the
`## Ticket set` section, and per-ticket launch commands.

## Ticket file structure

Must stand on its own: a complete, readable version of the ticket with enough metadata that a fresh
session can identify the source without re-fetching.

### Header

Plain markdown header with source metadata; omit any line whose value is absent. Include whatever
the tracker provides. Example:

```markdown
# <title / summary>

> **Source** [<id>](<url>)
> **Type** {type}
> **Status** {status}
> **Assignee** {display name or "—"}
> **Reporter / Created by** {display name}
> **Labels / Tags** {joined or "—"}
> **Fetched** {today YYYY-MM-DD}
```

### Body sections

Emit in this order, **only if present and non-empty**:

1. `## Description`
2. `## Acceptance criteria` — if the tracker has a dedicated AC field populated
3. `## <Other fields>` — one section per other populated field carrying real content (technical
   notes, custom fields, …), headed by the field's display name. Capture everything the ticket
   holds.
4. `## Comments` — oldest first, each `### <author> — <date>` then the body. Best-effort: if
   comments aren't returned, note it briefly or omit the section.
5. `## Related tickets` — see below
6. `## Attachments` — see [attachments.md](attachments.md)
7. `## Design references` — see [attachments.md](attachments.md)

Preserve heading hierarchy, bullet structure, emphasis, and code blocks; map in-field subheadings to
`####`. Omit empty sections. Quote user-facing strings, code identifiers, file paths, i18n keys, and
URLs **verbatim** — never alter or translate them.

### Related tickets

From the response's links/relations (and any remote-link tool), for each unique linked ticket
(excluding this one) fetch **only** title + status + type via a cheap call — **not** the full body.
The main goal is that there is a trace of all related tickets, so they can be fetched later if
needed. One bullet each, with the relationship if available:

```markdown
- [<id>](<url>) — (<type>, <status>) <title>
```

For non-ticket remote links (e.g. a wiki/Confluence page), emit the title and URL as a plain bullet.
If a fetch fails, list the link with `(unable to fetch)` rather than failing the whole run.

### Attachments & design references

The full protocol — numbering, cross-MCP fetching, auth, fallback recipes, integrity checks, and
entry templates — lives in [attachments.md](attachments.md). Three rules always hold:

1. Attachments include inline images in the description/fields, external linked assets, and
   design-tool links — not just tracker-hosted files.
2. Download each straight to disk (e.g. `curl -fSL <url> -o <file>`); never route one as inline
   base64 through the model — output caps truncate it silently.
3. A file you cannot fetch is still referenced with its source URL and added to the warn list —
   never block.

## Boundaries

- **Do not** analyze, plan, or explore the codebase for context — this does not exempt files the
  ticket explicitly links, which you still fetch (see [attachments.md](attachments.md)).
- **Do not** modify the ticket in its tracker — fetching is **read-only** (no comments, transitions,
  edits, worklogs).
- The only files you create: the `.TICKET.md`, its attachments, and any linked docs you fetched.

## Next step

State clearly when done, using **project-relative paths** (never absolute): the output directory,
the ticket file, and any attachments. If any attachment or design preview could not be
downloaded, **first emit a clear warning** listing each missing file's name and its source URL,
instructing the user to download it and save it under that exact name so the embeds resolve — or,
with `/attach-to-ticket` installed, to paste it (or its saved path) and run that skill. Then hand
off the next phase as a **single copy-pasteable launch command** — session name and prompt
combined, so one paste starts the session. Use the launch syntax of the agent tool in use
(vendor-agnostic — `claude` below is only the example), naming the session `refine-<slug>`:

```
claude --name refine-<slug> "/refine-ticket <output-dir>/<id>-<slug>.TICKET.md"
```

Then offer the alternative — clearing the current session instead (vendor-agnostic — `/clear` below
is only the example; use the clear command of the agent tool in use):

OR /clear and run:

```
/refine-ticket <output-dir>/<id>-<slug>.TICKET.md
```
