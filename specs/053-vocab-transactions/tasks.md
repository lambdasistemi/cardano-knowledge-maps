# Tasks — Publish `transactions.ttl`

**Spec**: [`spec.md`](./spec.md) · **Plan**: [`plan.md`](./plan.md)

Each behaviour-changing task lists the slice it belongs to, its proof, and (for subagent tasks) the full brief used at dispatch. Orchestrator-direct tasks have no brief (no subagent runs them).

## Phase A — Synchronization point

### [X] T001 — Fix `just validate` so gate.sh actually validates Turtle

- **Slice**: A0 — `chore: fix just validate — parse all graphSources via rdflib`.
- **Owner**: Orchestrator (direct, mechanical edit).
- **Why this exists**: `main`'s `just validate` references the non-existent `data/rdf/graph.ttl` and tries to `require('oxigraph')` from a node shell with no `node_modules`. Every subagent's `./gate.sh` would fail before its real work begins.
- **Files**:
  - `flake.nix` — add a `devShells.default` exposing `python3 + python3Packages.rdflib`.
  - `justfile` — rewrite `validate` to call `python3 .specify/scripts/validate-graph-sources.py` (or inline equivalent).
  - `.specify/scripts/validate-graph-sources.py` — new helper: read `data/config.json`, iterate `graphSources`, parse each TTL via `rdflib`, exit non-zero on any failure.
- **Proof**: `nix develop --quiet -c just ci` exits 0 at HEAD with no other changes.
- **Commit subject**: `chore: validate every graphSources entry via rdflib in nix dev shell`
- **Commit body MUST include**: `Tasks: T001`.

### [X] T002 — Phase A vocab publication: declarations only

- **Slice**: A1 — `feat(vocab): publish transactions.ttl Phase A — class/property declarations`.
- **Owner**: Subagent.
- **Files (owned)**:
  - `data/rdf/transactions.ttl` (new).
  - `data/config.json` (add one `graphSources` entry).
- **Forbidden scope**:
  - `data/rdf/cardano.ontology.ttl`, `data/rdf/smart-contracts.ttl`, any existing TTL — additive-only invariant (FR-004).
  - `gate.sh`, `flake.nix`, `justfile`, `.specify/`, `specs/` — orchestrator-owned.
  - SKOS or OWL axioms — Phase B.
- **Proof**:
  - RED: `./gate.sh` fails *before* adding `data/rdf/transactions.ttl` to `graphSources` (rdflib reports missing file when the entry exists but file does not — observe this transient state).
  - GREEN: `./gate.sh` exits 0 with file in place; manual SPARQL `ASK { cardano:Transaction a rdfs:Class }` over the union graph succeeds (verifiable via rdflib in the dev shell).
- **Commit subject**: `feat(vocab): publish transactions.ttl Phase A — class/property declarations`
- **Commit body MUST include**: `Tasks: T002`.

#### Subagent brief (T002)

```text
Task: T002 — Phase A vocab publication.

Context:
- You are not alone in the codebase. Do not revert edits made by others.
- Make exactly ONE commit. Do not push.
- This commit must be bisect-safe and vertical. ./gate.sh must pass at HEAD.
- Conventional Commits: feat(vocab): ...
- Commit body MUST include `Tasks: T002`.
- Maintain ./WIP.md append-only with timestamped milestones (brief
  received, RED observed, GREEN observed, gate green, commit SHA).

Owned files:
- data/rdf/transactions.ttl (new file)
- data/config.json (add one graphSources entry; touch nothing else)

Forbidden scope:
- Any other data/rdf/*.ttl file (additive-only invariant)
- gate.sh, flake.nix, justfile
- specs/ tree, .specify/ tree

Orchestrator analysis already applied:
- The cardano: prefix is bound to
  <https://lambdasistemi.github.io/cardano-knowledge-maps/vocab/cardano#>
  in cardano.ontology.ttl. Use exactly that.
- Phase A is declarations only — no rdfs:domain, no rdfs:range,
  no owl:* axioms, no skos:* triples. Subclass relationships ARE
  allowed where the issue names them (PaymentCredential and
  StakeCredential are rdfs:subClassOf cardano:Credential).
- The graph-browser validate-action parses every file in
  data/config.json::graphSources; the new entry must appear there.

RED proof (observe before adding the file):
- Add the graphSources entry first, run ./gate.sh, observe rdflib
  reporting the missing file. Then add transactions.ttl with the
  declarations and rerun.

GREEN proof:
- ./gate.sh exits 0.

Required content of data/rdf/transactions.ttl:

Prefixes (use exactly these IRIs):
- cardano: https://lambdasistemi.github.io/cardano-knowledge-maps/vocab/cardano#
- rdf:    http://www.w3.org/1999/02/22-rdf-syntax-ns#
- rdfs:   http://www.w3.org/2000/01/rdf-schema#
- owl:    http://www.w3.org/2002/07/owl#
- dcterms: http://purl.org/dc/terms/

File header — an owl:Ontology stanza naming the file:

  <https://lambdasistemi.github.io/cardano-knowledge-maps/vocab/cardano/transactions>
    a owl:Ontology ;
    rdfs:label "Cardano Transaction Vocabulary (Phase A)" ;
    dcterms:description "..." ;
    owl:versionInfo "0.1.0-phaseA" ;
    owl:imports
      <https://lambdasistemi.github.io/cardano-knowledge-maps/vocab/cardano> .

Classes (each: `cardano:Foo a rdfs:Class ; rdfs:label "..." ;
dcterms:description "..." .`):
  Transaction, Input, Output, Address, Credential,
  PaymentCredential (rdfs:subClassOf cardano:Credential),
  StakeCredential   (rdfs:subClassOf cardano:Credential),
  Identifier, Entity, Asset, Datum, Redeemer, Script

Properties (each: `cardano:foo a rdf:Property ; rdfs:label "..." ;
dcterms:description "..." .`):
  Transaction-shape:
    hasInput, hasOutput, hasFee, hasValidityInterval,
    hasCertificate, hasWithdrawal, hasProposal, hasMint,
    hasCollateralInput, hasReferenceInput, hasWitnessSet
  Per-leaf:
    atAddress, hasPaymentCredential, hasStakeCredential,
    bytesHex, leafType, hasIdentifier, bech32
  Asset:
    hasPolicy, hasAssetName
  Datum/Redeemer/Script:
    hasDatum, hasReferenceScript, hasRawBytes, decodedAs,
    hasHash, hasVersion
  Resolved-input:
    resolvedTo, hasResolution

Each declaration MUST carry rdfs:label + dcterms:description. The
description is a short factual sentence (one or two clauses) describing
the term — see existing entries in cardano.ontology.ttl for style.

data/config.json edit:
- Insert ONE entry after "Cardano Domain":
    { "label": "Cardano Transactions (vocab)",
      "format": "text/turtle",
      "path": "data/rdf/transactions.ttl",
      "background": true }
- Do not reorder or modify other entries.
- Verify the JSON still parses.

Report back:
- changed files (exactly two)
- WIP.md path
- RED + GREEN evidence
- residual risks (none expected)
```

### [ ] T003 — Push Phase A and synchronize with epic

- **Slice**: orchestration glue (not a commit).
- **Owner**: Orchestrator.
- **Action**: `git push origin 53-vocab-transactions`; `gh pr comment 46 --repo lambdasistemi/cardano-tx-tools --body "kmaps#53 Phase A landed at <commit URL> — vocab foundation available for #45 to pin against"`.
- **Proof**: PR #54 shows the commit; epic #46 shows the comment.

## Phase B — Full vocabulary + reasoning

### [X] T004 — Package EYE reasoner via Nix

- **Slice**: B0 — `chore: package EYE reasoner via Nix`.
- **Owner**: Orchestrator (direct).
- **Files**: `flake.nix` (add `packages.eye` derivation + expose in `devShells.default`).
- **Approach**: SWI-Prolog comes from `pkgs.swi-prolog`. Fetch `eyereasoner/eye` at tag `v11.24.4` (SHA pre-fetched: `0rdig8gl1m498hcl3fi8hgbkhrcx6w0s136yglbaydqba6xlmahc`). Build steps:
  ```
  swipl -q -f $src/eye.pl -g main -- --quiet --image $out/lib/eye.pvm
  substitute $src/eye.sh.in $out/bin/eye --replace @PREFIX@ $out
  chmod +x $out/bin/eye
  ```
- **Proof**: `nix develop --quiet -c eye --version` reports `11.24.4`.
- **Commit subject**: `chore: package EYE reasoner via Nix for OWL 2 RL smoke`
- **Commit body MUST include**: `Tasks: T004`.

### [X] T005 — Extend gate.sh with OWL 2 RL inference harness

- **Slice**: B1 — `chore: extend gate.sh — OWL 2 RL inference smoke via EYE`.
- **Owner**: Orchestrator (direct).
- **Files**:
  - `justfile` — add `owl-smoke` recipe iterating `specs/053-vocab-transactions/smoke/*.n3`, merging with the published ontology + each fixture, running EYE, ASKing each companion `*.ask` file.
  - `specs/053-vocab-transactions/smoke/baseline.n3` — trivial fixture.
  - `specs/053-vocab-transactions/smoke/baseline.ask` — asserts no `?x a owl:Nothing` instance.
  - `gate.sh` — append `nix develop --quiet -c just owl-smoke` to the pipeline.
- **Proof**: `./gate.sh` exits 0 with the new step; the baseline ASK passes.
- **Commit subject**: `chore: extend gate.sh — OWL 2 RL inference smoke via EYE`
- **Commit body MUST include**: `Tasks: T005`.

### [X] T006 — Add `cardano:LeafType` SKOS ConceptScheme

- **Slice**: B2 — `feat(vocab): add cardano:LeafType ConceptScheme + SKOS role-class concepts`.
- **Owner**: Subagent.
- **Files (owned)**: `data/rdf/transactions.ttl` (append).
- **Forbidden scope**: every file outside `data/rdf/transactions.ttl`.
- **Proof**: `./gate.sh` green. Manual SPARQL `SELECT (COUNT(*) AS ?n) WHERE { ?c skos:inScheme cardano:LeafType }` over the union graph reports 9.
- **Commit subject**: `feat(vocab): add cardano:LeafType ConceptScheme + SKOS role-class concepts`
- **Commit body MUST include**: `Tasks: T006`.

#### Subagent brief (T006)

```text
Task: T006 — SKOS role-class taxonomy.

Context:
- One commit. Do not push. Bisect-safe. ./gate.sh must be green at HEAD.
- Conventional Commits: feat(vocab): ...
- Commit body MUST include `Tasks: T006`.
- Maintain ./WIP.md (append-only).

Owned files:
- data/rdf/transactions.ttl (append only; do not edit existing lines)

Forbidden scope:
- Any file outside data/rdf/transactions.ttl
- Existing class/property declarations from T002 (they are frozen URIs)

Orchestrator analysis already applied:
- Phase A URIs are frozen; this slice only ADDS triples (skos:inScheme
  membership, skos:related links, role-class concept declarations).
- The nine role-class concepts are DUAL-ROLE: each is both a
  skos:Concept (member of cardano:LeafType) and an rdfs:Class /
  owl:Class (so `_:leaf a cardano:PaymentScript` is valid as a
  role-class typing assertion).
- The `cardano:Identifier` class from T002 is the carrier of bytesHex
  + leafType; the role-class concepts are what `cardano:leafType`
  ranges over.

Required additions to data/rdf/transactions.ttl (append):

1. ConceptScheme declaration:
   cardano:LeafType a skos:ConceptScheme ;
     rdfs:label "Cardano Leaf Type" ;
     dcterms:description "Role classes for typed-leaf identifiers
     (credentials, script hashes, pool IDs, policy IDs, asset
     classes). Each member is both a SKOS concept (taxonomy) and
     an OWL class (typing of an identifier instance)." .

2. The nine concepts, each shaped:
   cardano:PaymentKey a skos:Concept , rdfs:Class ;
     skos:inScheme cardano:LeafType ;
     skos:prefLabel "Payment Key" ;
     dcterms:description "..." .

   The nine names (use exactly these spellings):
   PaymentKey, PaymentScript, StakeKey, StakeScript,
   DRepKey, DRepScript, PoolId, Policy, AssetClass

3. skos:related links between kin (key vs script of the same role):
   cardano:PaymentKey skos:related cardano:PaymentScript .
   cardano:StakeKey   skos:related cardano:StakeScript .
   cardano:DRepKey    skos:related cardano:DRepScript .
   (SKOS treats skos:related as symmetric; declare each pair once.)

Do NOT add owl:hasKey or owl:inverseOf — those belong to T007.

GREEN proof:
- ./gate.sh exits 0.
- The smoke harness (just owl-smoke) reports no new inconsistencies.

Report back:
- changed files (exactly one: data/rdf/transactions.ttl)
- WIP.md path
- diff stats (added-lines only; deletion count = 0)
```

### [X] T007 — Add OWL 2 RL reasoning axioms + smoke fixture

- **Slice**: B3 — `feat(vocab): add OWL 2 RL reasoning axioms (hasKey, inverseOf)`.
- **Owner**: Subagent. **This is the live-boundary slice.**
- **Files (owned)**:
  - `data/rdf/transactions.ttl` (append).
  - `specs/053-vocab-transactions/smoke/sameas-key.n3` (new).
  - `specs/053-vocab-transactions/smoke/sameas-key.ask` (new).
- **Forbidden scope**: every other file.
- **Proof**:
  - RED: with the smoke fixture + ASK files added but the OWL axioms commented out / absent, the ASK returns false (gate.sh exits non-zero). The subagent observes this transient state.
  - GREEN: with the OWL axioms added, EYE deduces `owl:sameAs` between the two identifier blank nodes; the ASK returns true; gate.sh exits 0.
- **Commit subject**: `feat(vocab): add OWL 2 RL reasoning axioms (hasKey, inverseOf)`
- **Commit body MUST include**: `Tasks: T007`.

#### Subagent brief (T007) — to be authored at dispatch time

The brief is written by the orchestrator just before dispatch, once T005's harness path is concrete.

### [ ] T008 — Run Analyzer pass

- **Owner**: Orchestrator (dispatches Analyzer Subagent per resolve-ticket).
- **When**: after T002 (Phase A) lands; rerun after T007 (before finalization).
- **Output**: `specs/053-vocab-transactions/analysis.md` committed as `docs:`.

### [ ] T009 — Finalization

- **Owner**: Orchestrator (direct).
- **Steps**: finalization audit; `chore: drop gate.sh (ready for review)`; `gh pr ready 54 --repo lambdasistemi/cardano-knowledge-maps`.
- **Proof**: PR shows Ready; `gh pr view 54` shows green CI; epic comment exists.

## Task graph

```text
T001 (chore A0, orch) ──► T002 (feat A1, subagent) ──► T003 (push + epic sync, orch)
                                                            │
                                                            ▼
                                  T008a (Analyzer pass, orch — Phase A snapshot)
                                                            │
                                                            ▼
T004 (chore B0, orch) ──► T005 (chore B1, orch) ──► T006 (feat B2, subagent) ──► T007 (feat B3, subagent)
                                                                                            │
                                                                                            ▼
                                                                          T008b (Analyzer pass) ──► T009 (finalization)
```
