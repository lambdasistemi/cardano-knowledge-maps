# Cross-artifact analysis — `53-vocab-transactions`

Run after T007 landed, before finalization. Read-only Analyzer Subagent pass; orchestrator commits this record verbatim. Source artifacts: [`spec.md`](./spec.md), [`plan.md`](./plan.md), [`tasks.md`](./tasks.md), `data/rdf/transactions.ttl`, `specs/053-vocab-transactions/smoke/`, `.specify/memory/constitution.md`.

## Coverage — tasks ↔ commits

| Task | Slice | Commit | Status |
|---|---|---|---|
| T001 | A0 | `a963cf9 chore(053): validate every graphSources entry via rdflib in nix dev shell` | landed |
| T002 | A1 | `d76befe feat(vocab): publish transactions.ttl Phase A — class/property declarations` | landed |
| T003 | sync | (orchestrator action; epic comment posted) | landed |
| T004 | B0 | `d0db919 chore(053): package EYE reasoner via Nix for OWL 2 RL smoke` | landed |
| T005 | B1 | `b8d3a79 chore(053): extend gate with OWL 2 RL inference smoke harness via EYE` | landed |
| T006 | B2 | `184d7a7 feat(vocab): add cardano:LeafType ConceptScheme + SKOS role-class concepts` | landed |
| T007 | B3 | `8122822 feat(vocab): add OWL 2 RL reasoning axioms (hasKey, inverseOf)` | landed |
| T008 | analyzer | (this pass) | landed (this file) |
| T009 | finalization | — | pending |

Every behaviour-changing task is backed by a single commit; commit order matches plan.md's slice list.

## Spec alignment

- **FR-001 (13 classes)**: present at `transactions.ttl:24–76`.
- **FR-002 (properties)**: 26 `rdf:Property` declarations across Transaction-shape (11), Per-leaf (7), Asset (2), Datum/Redeemer/Script (6), Resolved-input (2). All names match the issue list.
- **FR-003 (prefix `cardano:`)**: exact match with `cardano.ontology.ttl`.
- **FR-004 (additive invariant)**: `git diff origin/main -- data/rdf/cardano.ontology.ttl data/rdf/smart-contracts.ttl data/rdf/cardano.ttl data/rdf/governance.ttl` is empty.
- **FR-005 (graphSources entry)**: present at `data/config.json:8`.
- **FR-006 (SKOS scheme)**: `cardano:LeafType a skos:ConceptScheme` plus nine concepts, each `skos:inScheme cardano:LeafType`.
- **FR-007 (dual `rdfs:Class`)**: each concept declared `a skos:Concept , rdfs:Class`.
- **FR-008 (`skos:related` kin pairs)**: three pairs declared (PaymentKey↔PaymentScript, StakeKey↔StakeScript, DRepKey↔DRepScript).
- **FR-009 (`owl:hasKey`)**: delivered with a deliberate, documented deviation — the issue and the parent epic spec write the axiom with subject `cardano:hasIdentifier` (a property); OWL 2 RL defines `owl:hasKey` on classes. The published axiom is therefore on `cardano:Identifier`. The deviation was cleared with the epic orchestrator via Q-001 before authoring and is recorded inline in `transactions.ttl` and in T007's commit body.
- **FR-010 (`owl:inverseOf`)**: present.
- **FR-011 (OWL 2 RL gate smoke)**: `gate.sh → just ci → just owl-smoke` runs EYE end-to-end with the bundled OWL 2 RL rule fragments and verifies the published axiom fires on a real fixture.
- **FR-012 (property chains deferred)**: honoured.

## Constitution alignment

- **I. RDF-First**, **III. Data-Only Repository**, **IV. Accuracy Over Coverage** — all honoured.
- **II. Ontology Alignment** — satisfied; `transactions.ttl` IS the predicate-definition file. No `gbedge:` alignment required because this PR adds no instance graph in this repo.
- **V. Semantic Completeness** — explicitly exempted in plan.md: the five-step rule applies to instance nodes, not vocabulary publication. Reviewers should be aware this is a vocabulary-only PR.

## Plan ↔ tasks drift

None. The slice list A0..B3 in plan.md maps 1:1 to commits `a963cf9..8122822`. Each `chore` slice is non-behaviour-changing; each `feat(vocab)` slice carries its proof inside the same commit (B3's smoke fixture + ASK + axioms are one atomic slice, matching the live-boundary slice the plan called for).

## Live-boundary diagnostic

`gate.sh` exercises the OWL 2 RL reasoner boundary. `.specify/scripts/owl-smoke.py` invokes the real EYE binary over `(cardano.ontology.ttl + smart-contracts.ttl + transactions.ttl + EYE OWL 2 RL rule fragments + fixture)`, parses the closure with rdflib, runs the ASK queries. EYE's bundled `owl-hasKey.n3` fragment is what fires the `owl:sameAs` deduction; a unit suite cannot fake this. The baseline fixture's transitive `subClassOf` ASK proves the harness wiring is honest before the axiom-bearing fixture exists.

## Risks (plan §"Risks") — outcome

- **R1 — EYE packaging**: did not materialise. `nix/eye.nix` builds clean; `installCheckPhase` verified `eye --version` reports `11.24.4`. Apache Jena fallback not needed.
- **R2 — rdflib vs oxigraph drift**: not exercised. CI parser remains canonical.
- **R3 — Phase A URI disagreement with `#45`**: partially materialised in a different shape than expected. The FR-009 axiom subject was reinterpreted (`hasIdentifier` → `Identifier`) for OWL 2 RL correctness, with epic-orchestrator clearance (Q-001). The published Phase A URIs themselves remain frozen as `#45` requires.
- **R4 — `cardano:hasResolution` absent**: mitigated as planned; declared in Phase A.

## Findings worth surfacing

- **G3 (medium)** — FR-009 was reinterpreted (axiom on `cardano:Identifier`, not on `cardano:hasIdentifier`). The reinterpretation is documented in-file and in T007's commit body but should also appear in the PR description so downstream consumers reading PR metadata see the rationale without re-deriving it. Tracked by an additional epic comment after Phase B push.
- **G5 (cosmetic)** — `spec.md` User Story 2 mentions a fixture path under `contracts/`; the file actually lives under `smoke/`. The path was refined during plan authoring. Small forward `docs:` commit corrects.
- **No duplications. No contradictions. No unmapped tasks.**

## Verdict

**Ready for finalization.** Apply the G5 spec.md path fix, refresh the PR body with the FR-009 reinterpretation note, then run the finalization audit, drop `gate.sh`, and mark the PR ready.
