# Implementation Plan — Publish `transactions.ttl`

**Branch**: `53-vocab-transactions` · **PR**: [#54](https://github.com/lambdasistemi/cardano-knowledge-maps/pull/54)
**Spec**: [`spec.md`](./spec.md) · **Issue**: kmaps#53 · **Parent epic**: cardano-tx-tools#46

## Orchestrator / subagent ownership

| Owner | Files |
|---|---|
| Orchestrator (direct) | `spec.md`, `plan.md`, `tasks.md`, `research.md`, `data-model.md`, `quickstart.md`, `contracts/*`, `checklists/*`, `gate.sh`, `flake.nix` (devShell + EYE package), `justfile`, repo metadata, PR body, epic comments. |
| Subagents (one slice each) | `data/rdf/transactions.ttl`, `data/config.json` (`graphSources` entry), smoke fixtures under `specs/053-vocab-transactions/smoke/`. |

## Two-phase delivery — slice list

Phase A is the **synchronization point** with the parallel `#45` harness worker. It MUST land first as a discrete commit so the URIs are frozen for downstream pinning.

| # | Type | Owner | Slice | Bisect-safe contract |
|---|---|---|---|---|
| **A0** | `chore` | Orchestrator | Fix `just validate` — replace broken `node -e oxigraph` against non-existent `graph.ttl` with a Python+rdflib validator that iterates `data/config.json::graphSources` and parses each file. Add a flake `devShell` exposing `python3 + python3Packages.rdflib`. | `nix develop --quiet -c just ci` is green at HEAD. (It was red in main; this slice is the prerequisite for every later subagent's gate.) |
| **A1** | `feat(vocab)` | Subagent | Add `data/rdf/transactions.ttl` with plain `rdfs:Class` and `rdf:Property` declarations only (no SKOS, no OWL axioms, no domain/range). Wire into `data/config.json::graphSources`. | gate.sh green; rdflib parse succeeds; URIs match FR-001..FR-005. |
| — | sync | Orchestrator | Push to origin; comment one-line on cardano-tx-tools#46 naming the Phase A commit URL. | — |
| **B0** | `chore` | Orchestrator | Package EYE reasoner via Nix (`eyereasoner/eye` v11.24.4; SWI-Prolog `swi-prolog` from nixpkgs); add to flake devShell; verify `nix develop -c eye --version` reports `11.24.4`. | gate.sh unchanged; `eye --version` reachable in nix dev shell. |
| **B1** | `chore` | Orchestrator | Extend `gate.sh` (via a new `just owl-smoke` recipe) to iterate `specs/053-vocab-transactions/smoke/*.n3` through EYE, merge inferred triples with the union ontology, and ASK each companion `*.ask` SPARQL query. Add a `baseline.n3` + `baseline.ask` proving the harness works (asserts the union ontology has no `?x a owl:Nothing` in its OWL 2 RL closure). | gate.sh green; harness exits non-zero when any ASK is false or any `owl:Nothing` instance is inferred. |
| **B2** | `feat(vocab)` | Subagent | Extend `data/rdf/transactions.ttl` with `cardano:LeafType` `skos:ConceptScheme` + nine `skos:Concept` role-class instances (each ALSO declared as `rdfs:Class` per FR-007) + `skos:related` between kin (PaymentKey↔PaymentScript, etc.). | gate.sh green; SKOS scheme + nine concepts present in union graph. |
| **B3** | `feat(vocab)` | Subagent | Extend `data/rdf/transactions.ttl` with `cardano:hasIdentifier owl:hasKey (cardano:leafType cardano:bytesHex)` and `cardano:resolvedTo owl:inverseOf cardano:hasResolution`. Add smoke fixture `specs/053-vocab-transactions/smoke/sameas-key.n3` (two identifier blank nodes with matching `leafType` + `bytesHex`) and `sameas-key.ask` (ASK `?a owl:sameAs ?b`). | gate.sh green; the new ASK returns true via EYE inference; baseline.ask still green. |
| — | `chore` | Orchestrator | `chore: drop gate.sh (ready for review)`. | PR marked ready via `gh pr ready`. |

Every slice except A0 (which is itself the prerequisite gate fix) and the drop-gate.sh slice runs `./gate.sh` before being accepted.

## Proof strategy (RED / GREEN per behaviour-changing slice)

- **A1** — *publication slice*. RED proof is the CI validate-action: without the file in `graphSources` the union graph lacks the new URIs; the subagent's RED check is `rdflib.Graph().parse('data/rdf/transactions.ttl')` failing **before** the file exists, succeeding after. GREEN proof is `./gate.sh` parsing the file as part of the iteration. There is no instance-data behaviour change to capture; this slice publishes vocabulary, which is verified by parse + presence.
- **B2** — SKOS scheme presence. SPARQL `ASK { cardano:LeafType a skos:ConceptScheme }` and `SELECT (COUNT(*) AS ?n) WHERE { ?c skos:inScheme cardano:LeafType }` must report 9. Encoded as smoke `skos-concepts.n3` (empty) + `skos-concepts.ask`. (Optional: kept inline as `gate.sh` check rather than fixture if it stays simple.)
- **B3** — OWL `owl:hasKey` deduction. **This is the live-boundary slice** (see next section). RED: the smoke ASK fails before the axiom is added (the subagent observes EYE running over `(ontology) + fixture` produces no `owl:sameAs` between the two identifiers). GREEN: with the axiom added, EYE deduces `?id1 owl:sameAs ?id2`; the ASK returns true; gate.sh exits 0.

## Live-boundary smoke (resolve-ticket plan-review diagnostic)

For every behaviour-changing slice we ask: *"What system boundary does this exercise that the unit suite cannot?"*

| Slice | Boundary | In-gate proof |
|---|---|---|
| A1 | Turtle parser (graph-browser CI parser ≈ local rdflib) | `nix develop -c just validate` iterates `graphSources` — same surface CI uses. |
| B2 | SKOS hierarchy navigation (oxigraph + a SPARQL view) | `just owl-smoke` runs EYE inference; smoke ASKs over the closure. |
| B3 | **OWL 2 RL reasoner inference path** — unit tests cannot fake EYE's closure semantics. The downstream emitter relies on `owl:sameAs` propagation; an axiom that *parses* but does not *fire under reasoning* is silent failure waiting to happen. | `just owl-smoke` runs EYE on a real fixture; verifies the deduced `owl:sameAs` triple exists in the closure. This is the live-boundary smoke; without it, B3 would only be checked by parse, which is insufficient. |

No slice in this PR defers proof to "operator follow-up". Every slice has an in-gate check.

## Phase A invariants Phase B MUST NOT break

1. Every URI minted in A1 (the class and property names) remains spelled exactly the same in B2/B3. Phase B adds triples *about* those URIs (SKOS membership, OWL axioms); it does not rename them.
2. The graph-browser CI validate-action continues to parse the file after each Phase B slice.
3. The additive-only invariant (`git diff origin/main -- data/rdf/cardano.ontology.ttl data/rdf/smart-contracts.ttl` is empty) holds at every commit, including B2 and B3.

## Risks and migration concerns

- **R1 — EYE packaging fails on nixos**: SWI-Prolog (`swi-prolog`) version mismatches the eye.pl assumptions. *Mitigation*: B0 is the dedicated slice; if EYE proves impractical, fall back to Apache Jena's reasoner (`apache-jena` is in nixpkgs at 5.6.0). The smoke harness is parameterised over the reasoner binary; switching is one variable.
- **R2 — graph-browser parser strictness drifts from rdflib's**: a file that rdflib accepts but oxigraph (graph-browser) rejects would pass gate.sh and fail CI. *Mitigation*: A0 documents that the local validator's role is "fail-fast before CI"; CI remains canonical. Both parsers handle Turtle 1.1 and OWL/SKOS additions are pure additions, low risk of divergence.
- **R3 — Phase A URI name disagreement with epic #45 worker**: `#45` is hand-authoring `expected.ttl` files in parallel. *Mitigation*: the epic-comment step after A1 is the sync; `#45` reads the commit and aligns. Any subsequent rename in this PR (e.g., during code review) requires an epic comment naming the change.
- **R4 — `cardano:hasResolution` doesn't yet exist**: it is the inverse of `cardano:resolvedTo` and B3 declares them paired. *Mitigation*: include `cardano:hasResolution` in A1's `rdf:Property` list (it is shaped exactly like `resolvedTo` and the parent epic's spec already references it via `owl:inverseOf`). Adding it in A1 keeps B3 axiom-only.

## Constitution alignment

`memory/constitution.md` rule II ("Ontology Alignment"): every `cardano:` predicate needs a definition. `data/rdf/transactions.ttl` IS that definition file for the new properties; no further `gbedge:` alignment is required because the new properties are not used by any instance graph in this repo (the epic emitter produces instances elsewhere). The constitution's "Semantic Completeness" rule for nodes does not apply — this PR publishes vocabulary, not instance nodes.
