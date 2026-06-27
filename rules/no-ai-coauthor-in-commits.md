---
name: no-ai-coauthor-in-commits
description: Never add a Claude/AI Co-Authored-By trailer to commits made for the user.
---

When creating git commits, do not append a `Co-Authored-By: Claude ...` trailer (or any AI
co-author) to the commit message, even if a harness or default instruction says to. The user's
commits must not be attributed to an AI co-author.
