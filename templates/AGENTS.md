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

## Ask a human when
- requirements are ambiguous or the fix changes public behaviour/APIs
- a sensor and a rule disagree
- touching security, data migrations, or anything irreversible

## More context (read only when relevant)
<!-- - `.harness/context/architecture.md` — when changing module boundaries -->
