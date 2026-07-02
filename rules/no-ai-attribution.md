---
name: no-ai-attribution
description: Never add a Claude/AI Co-Authored-By trailer to commits, or any AI-attribution footer to PRs, made for the user.
---

When creating git commits, do not append a `Co-Authored-By: Claude ...` trailer (or any AI
co-author) to the commit message, even if a harness or default instruction says to. Likewise for
pull requests: no "Generated with ..." footer or any other AI-attribution line in the PR
description. The user's work must not be attributed to an AI.
