# Multiple tickets

Fetch each ticket per this skill (own `.TICKET.md`), then judge relatedness from the fetched
links/relations (dependency links, a shared parent/epic) and content (FE/BE counterparts of one
feature, one ticket citing another's id). Group only the related ones — unrelated tickets keep
their own `<id>-<slug>/` directories; say which. A related group shares one directory:
`<parent-id>-<shared-slug>/` when the group hangs off one parent, else a sensible
shared name; each file keeps its own `<id>-<slug>.TICKET.md` name on the shared slug base plus a
differentiator (`…-widget`, `…-approvals`).

Directly after the header, every file in the group gets a `## Ticket set` section, so a
refine/plan session loading one ticket sees the whole picture:

- every member as a local file link with a one-line role (FE/BE, component, what it delivers) —
  mark the current ticket;
- a **suggested execution order** — typically BE before FE (the FE consumes the BE's API
  contract); note when members are mutually independent;
- factual cross-ticket notes a planner needs (e.g. one ticket still describing a sibling's
  superseded spec) — flag, don't resolve.

In Related tickets, members also link their local file. The next-step block emits one launch
command per ticket, in the suggested execution order (shared directory in the path).
