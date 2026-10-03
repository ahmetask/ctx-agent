# {{PROJECT}} — agent map

<!-- Guide (feedforward). This file is a MAP, not an encyclopedia: ≤ ~120 lines,
     facts an agent cannot cheaply discover from the code. Details live in
     .harness/context/*.md and are read on demand. Kept true by /ctx-agent:harness-sync. -->

## What this is
{{ONE_OR_TWO_SENTENCES}}

## Layout
<!-- Only non-obvious dirs. `path/` — purpose -->

## Commands
<!-- The exact commands; mirror .harness/config sensors -->
- build: 
- test: 
- lint: 

## Rules (load-bearing only)
<!-- Imperative, one line each, ideally with the WHY. Delete habit, keep load-bearing.
     A rule a tool can check belongs in a sensor, not here. -->

## Ask a human when (don't assume — protocol: ctx-agent `references/ask-human.md`)
- requirements are ambiguous, or two readings lead to different code
- the fix changes public behaviour/APIs, schemas or stored data formats
- a sensor and a rule disagree, or a task contradicts a `(human)` line
- deleting files, adding dependencies, security, data migrations, anything irreversible

## More context (read only when relevant)
<!-- - `.harness/context/architecture.md` — when changing module boundaries -->
