# Feature Specification: Publish `transactions.ttl` — Cardano transaction vocabulary

**Feature Branch**: `53-vocab-transactions`
**Issue**: [lambdasistemi/cardano-knowledge-maps#53](https://github.com/lambdasistemi/cardano-knowledge-maps/issues/53)
**Parent epic**: [lambdasistemi/cardano-tx-tools#46](https://github.com/lambdasistemi/cardano-tx-tools/issues/46) (Phase 0)
**Created**: 2026-05-19
**Status**: Draft

## Background

The parent epic re-targets `cardano-tx-tools` from an in-memory ADT + text renderer to **"Conway tx → RDF graph"**. The emitter, the operator rule format, and every reviewer-facing view all bind to a vocabulary of `cardano:` class and property URIs. Once any third tool reads or writes those URIs, the vocabulary is public API: a wrong name is a versioning event.

This ticket publishes that vocabulary under the existing `cardano-knowledge-maps` namespace (`https://lambdasistemi.github.io/cardano-knowledge-maps/vocab/cardano#`), as a new file `data/rdf/transactions.ttl`, so the emitter ticket ([#47](https://github.com/lambdasistemi/cardano-tx-tools/issues/47)) and the harness ticket ([#45](https://github.com/lambdasistemi/cardano-tx-tools/issues/45)) can pin against stable URIs.

## Two-phase delivery

The work ships in two phases inside this PR, separated by Conventional-Commit slices. Phase A is the **synchronization point** for the parallel `#45` harness worker: as soon as it lands, the URIs are frozen for downstream pinning.

| Phase | Content | Why split |
|---|---|---|
| **A** (ship first) | Plain `rdfs:Class` + `rdf:Property` declarations for every class and property the emitter mints. No SKOS, no OWL axioms. Existing gate.sh (Turtle parse only) is sufficient. | `#45` is hand-authoring `expected.ttl` files in parallel and needs stable URIs before adding axioms could rename or restructure anything. |
| **B** (same PR) | `cardano:LeafType` `skos:ConceptScheme` + concepts + SKOS related/broader links; OWL 2 RL reasoning axioms (notably `cardano:hasIdentifier owl:hasKey (cardano:leafType cardano:bytesHex)`, `cardano:resolvedTo owl:inverseOf cardano:hasResolution`); gate.sh extension with an OWL 2 RL consistency smoke. | Adds semantic load without renaming URIs. Reasoning needs validation tooling (EYE) which is Phase B work. |

## User Scenarios & Testing

### User Story 1 — Emitter pins to stable class + property URIs (Priority: P1, Phase A)

A `cardano-tx-tools` developer (epic ticket [#47](https://github.com/lambdasistemi/cardano-tx-tools/issues/47)) is writing the Conway-tx → RDF emitter. Their Haskell module declares typed constants for every URI the emitter will mint:

```haskell
hasInput   = mkURI cardano "hasInput"
hasOutput  = mkURI cardano "hasOutput"
bytesHex   = mkURI cardano "bytesHex"
-- ...
```

They need every name to resolve against a published ontology so the emitter, the harness's hand-authored `expected.ttl` golden files, and downstream SPARQL view queries all agree on URIs.

**Why this priority**: P1 because every other story builds on this. Without it the emitter cannot be implemented and `#45`'s expected-graph goldens cannot be authored.

**Independent Test**: Open `data/rdf/transactions.ttl` and verify the scoped set of `cardano:` class and property URIs are declared. The graph-browser CI's Turtle parser confirms well-formed syntax.

**Acceptance Scenarios**:

1. **Given** `data/rdf/transactions.ttl` is wired into `data/config.json::graphSources`, **When** the graph-browser validate-action runs in CI, **Then** the file parses as well-formed Turtle and the union graph contains every class and property URI listed in the issue's Phase A scope (see Requirements FR-001..FR-002 below).
2. **Given** the same file, **When** a downstream consumer reads it via `nix` flake input (parent epic's plan), **Then** the URIs resolve under `https://lambdasistemi.github.io/cardano-knowledge-maps/vocab/cardano#`, matching the prefix used elsewhere in the knowledge-maps ontology.

---

### User Story 2 — Reasoner deduces cross-leaf identity via `owl:hasKey` (Priority: P1, Phase B)

A reviewer loads the union of `cardano.ontology.ttl + smart-contracts.ttl + transactions.ttl` plus a tiny instance fixture containing two `cardano:Identifier` blank nodes, each carrying the **same** `cardano:leafType` (e.g. `cardano:PaymentScript`) and the **same** `cardano:bytesHex`. They run an OWL 2 RL reasoner (`eye --nope --quiet --pass`) over the union. The reasoner deduces `owl:sameAs` between the two identifiers — by virtue of the `cardano:hasIdentifier owl:hasKey (cardano:leafType cardano:bytesHex)` axiom in `transactions.ttl`.

**Why this priority**: P1 because this is the load-bearing semantic property the parent epic relies on. The emitter does not engineer cross-leaf identity at render time; OWL deduction does. The vocabulary must carry the axiom.

**Independent Test**: A smoke fixture `specs/053-vocab-transactions/contracts/sameas-key.smoke.n3` declares two identifier blank nodes with matching `leafType` + `bytesHex`. `gate.sh` runs `eye --nope --quiet --pass` against `(ontology union) + smoke`, then SPARQL-ASKs for `?a owl:sameAs ?b` between the two identifiers. ASK returns true.

**Acceptance Scenarios**:

1. **Given** the smoke fixture and the published ontology, **When** EYE infers the closure, **Then** the inferred graph contains `?id1 owl:sameAs ?id2` for the two identifier blank nodes.
2. **Given** the same fixture **but with the OWL axiom removed from `transactions.ttl`**, **When** the smoke runs, **Then** the ASK returns false (the test only passes because of the axiom — Negative-control variant kept in gate.sh's `verify-axiom` mode is optional, see plan).

---

### User Story 3 — Operator picks role-class from `cardano:LeafType` SKOS scheme (Priority: P2, Phase B)

When an operator writes a Turtle rule declaring an entity, they refer to a role class by name:

```turtle
:network_compliance a cardano:Entity ;
  cardano:hasIdentifier [
    a cardano:PaymentScript ;
    cardano:bytesHex "32201dc1..." ] .
```

`cardano:PaymentScript` must be a member of the published `cardano:LeafType` `skos:ConceptScheme`, alongside `PaymentKey`, `StakeKey`, `StakeScript`, `DRepKey`, `DRepScript`, `PoolId`, `Policy`, `AssetClass`. SKOS `related` / `broader` edges document kin relationships (key vs. script of the same role, `Hash28`-shaped super-concept).

**Why this priority**: P2 because the role-class vocabulary lets operators and tools enumerate the valid leaf types without parsing ontology axioms. SKOS is the standard way to publish a curated taxonomy alongside the OWL class hierarchy.

**Independent Test**: Load the ontology, SPARQL `SELECT ?concept WHERE { ?concept skos:inScheme cardano:LeafType }`, assert the result lists nine concepts.

**Acceptance Scenarios**:

1. **Given** `transactions.ttl` Phase B, **When** the graph is loaded into oxigraph, **Then** `cardano:LeafType` is a `skos:ConceptScheme` and the nine role-class concepts each declare `skos:inScheme cardano:LeafType`.
2. **Given** the same graph, **When** SPARQL navigates `skos:related` between `cardano:PaymentKey` and `cardano:PaymentScript`, **Then** the edge is present (and symmetric per SKOS semantics).

---

### Edge Cases

- **Existing terms collide with new ones**: every Phase A URI MUST be checked against `cardano.ontology.ttl` and `smart-contracts.ttl` before introduction; a name reuse must be intentional (and recorded), not accidental. Acceptance criterion 3 below.
- **Operator declares an `cardano:Entity` with no `cardano:hasIdentifier`**: Phase A vocabulary alone cannot reject this (no axiom). Phase B's plan documents that loader-side validation (in `cardano-tx-tools`) catches it; the ontology itself remains schema-only.
- **Smoke fixture references a class or property not in Phase A scope**: gate.sh smoke fails loudly. The fixture is the proof that the axiom + the named terms exist together.
- **Existing `just validate` is broken in main** (references non-existent `data/rdf/graph.ttl`, no `oxigraph` reachable through the nix shell): a tiny orchestrator-direct `chore: fix just validate` commit precedes Phase A so that every subagent's `./gate.sh` invocation is meaningful. The fix matches what the graph-browser CI action does: parse every file listed in `data/config.json::graphSources`.

## Requirements

### Functional Requirements

**Phase A (synchronization point)**

- **FR-001** — `data/rdf/transactions.ttl` MUST declare the following classes as `rdfs:Class`:
  `cardano:Transaction`, `cardano:Input`, `cardano:Output`, `cardano:Address`,
  `cardano:Credential`, `cardano:PaymentCredential` (subClassOf `Credential`),
  `cardano:StakeCredential` (subClassOf `Credential`), `cardano:Identifier`,
  `cardano:Entity`, `cardano:Asset`, `cardano:Datum`, `cardano:Redeemer`,
  `cardano:Script`.
- **FR-002** — `data/rdf/transactions.ttl` MUST declare the following properties as `rdf:Property` (no `rdfs:domain` / `rdfs:range` axioms in Phase A):
  - Transaction shape: `hasInput`, `hasOutput`, `hasFee`, `hasValidityInterval`, `hasCertificate`, `hasWithdrawal`, `hasProposal`, `hasMint`, `hasCollateralInput`, `hasReferenceInput`, `hasWitnessSet`.
  - Per-leaf: `atAddress`, `hasPaymentCredential`, `hasStakeCredential`, `bytesHex`, `leafType`, `hasIdentifier`, `bech32`.
  - Asset: `hasPolicy`, `hasAssetName`.
  - Datum / Redeemer / Script: `hasDatum`, `hasReferenceScript`, `hasRawBytes`, `decodedAs`, `hasHash`, `hasVersion`.
  - Resolved-input: `resolvedTo`, `hasResolution` (declared as a property in Phase A so the Phase B `owl:inverseOf` axiom has both subjects already defined; named in the issue's reasoning-axioms list).
- **FR-003** — `data/rdf/transactions.ttl` MUST use the `cardano:` prefix `<https://lambdasistemi.github.io/cardano-knowledge-maps/vocab/cardano#>` exactly as bound in `cardano.ontology.ttl` (Constitution: ontology grounded in W3C standard vocabularies; same prefix means one unified namespace).
- **FR-004** — Every existing `cardano:` subject defined in `cardano.ontology.ttl` and `smart-contracts.ttl` MUST remain byte-identical after the PR (additive-only invariant). The diff against `origin/main` for those two files MUST be empty.
- **FR-005** — `data/rdf/transactions.ttl` MUST appear as a `graphSources` entry in `data/config.json` (background: true), so the existing CI validate-action exercises it under the same parse rules as the rest of the ontology.

**Phase B (semantic load)**

- **FR-006** — `data/rdf/transactions.ttl` MUST declare `cardano:LeafType` as a `skos:ConceptScheme` and the nine role-class concepts (PaymentKey, PaymentScript, StakeKey, StakeScript, DRepKey, DRepScript, PoolId, Policy, AssetClass) as `skos:Concept` instances with `skos:inScheme cardano:LeafType`.
- **FR-007** — The role-class concepts MUST also be declared as `owl:Class` / `rdfs:Class` (their dual role as classes is what lets a triple like `_:cred1 a cardano:PaymentScript` express role-class typing).
- **FR-008** — SKOS `skos:related` links MUST be declared between key/script siblings (PaymentKey ↔ PaymentScript, StakeKey ↔ StakeScript, DRepKey ↔ DRepScript).
- **FR-009** — `data/rdf/transactions.ttl` MUST declare `cardano:hasIdentifier owl:hasKey (cardano:leafType cardano:bytesHex)`.
- **FR-010** — `data/rdf/transactions.ttl` MUST declare `cardano:resolvedTo owl:inverseOf cardano:hasResolution`.
- **FR-011** — `gate.sh` MUST run an OWL 2 RL inference smoke over the union of the published ontology + a small fixture, and SPARQL-ASK that the expected `owl:sameAs` is deduced (per User Story 2). The reasoner used is EYE (parent epic's choice), packaged via this repo's flake.
- **FR-012** — Property chain axioms named in the issue ("TBD in PR refinement") are NOT in scope for this PR. They are tracked as a follow-up; the current PR adds only the named-by-issue load-bearing axioms (FR-009, FR-010).

### Out of Scope

- Engine consumption of the vocabulary (parent epic child ticket [#47](https://github.com/lambdasistemi/cardano-tx-tools/issues/47)).
- SHACL shapes for blueprint extensibility (Phase C of the parent epic).
- CIP submission (later; namespace stays under `lambdasistemi.github.io`).
- Property chain axioms beyond the two named in the issue (`hasInput / resolvedTo / atAddress → hasSpenderAddress`, etc.) — explicitly deferred to a follow-up.

## Success Criteria

- **SC-001** — Phase A commit lands on PR #54 with a green gate, and the epic synchronization comment is posted on `lambdasistemi/cardano-tx-tools#46` naming the commit SHA. (Binary, pass/fail.)
- **SC-002** — Existing `cardano:` terms are byte-identical pre/post PR (additive invariant). `git diff origin/main -- data/rdf/cardano.ontology.ttl data/rdf/smart-contracts.ttl` MUST be empty at finalization.
- **SC-003** — Every Phase A class/property URI is parseable, dereferenceable (resolves under the published prefix), and appears in the union graph the graph-browser validate-action loads.
- **SC-004** — Phase B smoke (`gate.sh` mode `owl-smoke`) ASK-deduces `owl:sameAs` between two identifier blank nodes sharing `leafType` + `bytesHex`; without the axiom the ASK returns false.
- **SC-005** — `gate.sh` runs green at HEAD before the PR is marked ready.

## Assumptions

- The cardano-tx-tools epic's choice of EYE as reasoner stands; this PR packages EYE in Phase B (SHA pre-fetched: `0rdig8gl1m498hcl3fi8hgbkhrcx6w0s136yglbaydqba6xlmahc` for v11.24.4).
- The graph-browser validate-action (`v1.1.0`) is the authoritative CI parser; gate.sh's local validator MUST agree with it on the parse-or-not verdict for every TTL file in `graphSources`.
- The current main branch's `just validate` is broken (verified locally — references non-existent `data/rdf/graph.ttl`, no `oxigraph` reachable). A small orchestrator chore commit fixes it before any feat lands; the fix is part of this PR's scope because the gate didn't work in main either.
- Phase A URIs are frozen the moment Phase A pushes. Phase B may add `rdfs:domain` / `rdfs:range` / `owl:hasKey` / `skos:inScheme` triples mentioning those URIs but MUST NOT rename them.
