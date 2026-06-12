---
name: cardano-knowledge-maps-guide
description: Orientation guide for the cardano-knowledge-maps repository — interactive RDF knowledge maps of the Cardano ecosystem rendered by graph-browser. Load when working with data/config.json, graphSources, data/rdf/*.ttl Turtle files (cardano.ontology.ttl, cardano.ttl, governance.ttl, smart-contracts.ttl, transactions.ttl, budget-2026/*.ttl), data/queries.json SPARQL queries, data/tutorials/ guided tours, the vendored cardano-ledger-rdf transaction vocabulary (data/rdf/PINNED.md), `just validate`, `just owl-smoke`, the EYE reasoner, rdflib validation, the GitHub Pages deployment, or when answering questions about Cardano governance (CIP-1694), Plutus smart contracts, Conway transactions, or Budget 2026 proposals as modeled in this graph.
---

# cardano-knowledge-maps guide

## Repository map

- `data/config.json` — viewer entry point: title, node kinds (colors/shapes), and the ordered `graphSources` list (19 Turtle files). Sources with `"background": true` are always loaded and hidden from the viewer's Sources toggle.
- `data/rdf/cardano.ontology.ttl` — hand-authored OWL domain ontology grounding all nodes in W3C vocabularies (PROV-O, ORG, SKOS, OWL-Time, FOAF, Dublin Core). Published as a dereferenceable document at `<site>/vocab/cardano`.
- `data/rdf/cardano.ttl` — shared instance nodes referenced by multiple topic files.
- `data/rdf/transactions.ttl` — Conway transaction vocabulary, **vendored** from `lambdasistemi/cardano-ledger-rdf` (do not edit; see `data/rdf/PINNED.md` for the pinned commit and refresh procedure).
- `data/rdf/governance.ttl` — CIP-1694 governance instance graph.
- `data/rdf/smart-contracts.ttl` — Plutus stack, languages, dApps, Vasil features, Hydra.
- `data/rdf/budget-2026/*.ttl` — one file per Budget 2026 proposal, plus shared `proposers.ttl`.
- `data/rdf/core-ontology.{ttl,mmd}`, `data/rdf/application-ontology.{ttl,mmd}` — legacy graph-browser vocabulary exports; **not** listed in `graphSources`, not loaded by the viewer.
- `data/queries.json` — 35 named SPARQL queries; entries tagged `"view"` become the viewer's Views menu.
- `data/tutorials/` — 19 guided tours; `index.json` is the catalog.
- `.specify/` — speckit scaffolding; `memory/constitution.md` holds the data-authoring principles, `scripts/validate-graph-sources.py` and `scripts/owl-smoke.py` are the local validation gates.
- `specs/` — spec/plan/tasks records of past features, including the OWL 2 RL smoke fixtures under `specs/053-vocab-transactions/smoke/`.
- `flake.nix` + `nix/eye.nix` — dev shell (Python+rdflib, just, jq, EYE reasoner) and site package; `justfile` — task runner.
- `.github/workflows/` — `ci.yml` (validate + PR preview), `pages.yml` (validate + build + vocab publish + deploy).

## Build, test, run

All commands run from the repo root:

```sh
nix develop                              # dev shell: python3+rdflib, just, jq, eye
nix develop --quiet -c just validate     # parse all 19 graphSources TTLs via rdflib
nix develop --quiet -c just owl-smoke    # EYE OWL 2 RL inference smoke fixtures
nix develop --quiet -c just ci           # build + validate + owl-smoke
nix build                                # assemble viewer + data into ./result
npx serve result -p 10001                # serve locally (or: just serve)
```

## Navigating the code

There is no application code. The "logic" lives in the data layer:

- Which graphs load, and in what order: `data/config.json::graphSources`.
- What a node *is* (class, label, description): the topic TTL that owns it; its `cardano:` type is declared in `data/rdf/cardano.ontology.ttl`.
- Why an edge renders with a given label: the `gbedge:` predicate alignment in `cardano.ontology.ttl`.
- What the Views menu shows: `data/queries.json` entries tagged `"view"`.
- What a guided tour says: the matching `data/tutorials/<id>.json` stops and narratives.
- How validation works: `.specify/scripts/validate-graph-sources.py` (syntax) and `.specify/scripts/owl-smoke.py` (inference); CI additionally runs graph-browser's `validate-action` (JSON schemas + referential integrity).

To find a concept, grep the TTLs for its label or IRI: node IRIs use the `n:` prefix (`https://github.com/lambdasistemi/cardano-knowledge-maps/rdf/node/`), vocabulary terms use `cardano:` (`https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#`).

## Using the knowledge maps

- Browse: <https://lambdasistemi.github.io/cardano-knowledge-maps/> — Views to switch topic, click to re-center, hover edges for rationale, depth buttons (1/2/3/All), Guided Tours for narratives.
- Load through the universal viewer: `https://lambdasistemi.github.io/graph-browser/?repo=lambdasistemi/cardano-knowledge-maps` (add `&branch=<ref>` to preview a non-main ref).
- Query outside the viewer: every TTL parses with any RDF toolchain, e.g. in the dev shell:

  ```sh
  python3 -c "import rdflib; g = rdflib.Graph(); g.parse('data/rdf/governance.ttl'); print(len(g))"
  ```

To add a node: add triples to the owning topic TTL, type it in `cardano.ontology.ttl`, align new edge predicates there too, include it in relevant `queries.json` queries and at least one tour, then run `just ci`. Promote nodes referenced by two or more topic files to `cardano.ttl`.

## Answering questions

- "What is this project?" — README **What is this**; one-line answer: interactive, ontology-grounded knowledge maps of the Cardano ecosystem, rendered by graph-browser, deployed on GitHub Pages.
- "How do I run/see it?" — README **Quickstart** (live site, universal viewer, `nix build` + serve).
- "How do I add a node/edge/tour?" — README **Contributing** plus `.specify/memory/constitution.md` (the semantic-completeness checklist).
- "Where does the transaction vocabulary come from?" — `data/rdf/PINNED.md` (vendored from cardano-ledger-rdf at a pinned commit).
- "How is the site built/deployed?" — README **Architecture** diagram; the source of truth is `.github/workflows/pages.yml` and `flake.nix`.
- "Is the graph content authoritative?" — No: README **Disclaimer** — AI-generated from public documentation, verify against CIP-1694 and docs.cardano.org.
