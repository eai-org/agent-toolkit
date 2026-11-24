---
name: assert-literal-expected-values
description: In tests, write the expected value as a literal and assert it where it leaves the code.
---

When a test checks a value the code picks itself (a default, a constant, a derived setting), write
the expected value as a literal, never as the constant or helper the code itself uses: that test
passes whatever the value is.

Assert it where it leaves the code (the frame sent, the request built, the value returned), not at
a mocked step before that point.
