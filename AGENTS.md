# Repository Agent Guide

## What this repo is

Cardano Knowledge Maps is a **data-only** repository: Turtle RDF graph sources, a SPARQL query catalog, and guided tours describing the Cardano ecosystem (CIP-1694 governance, Plutus smart contracts, Conway transactions, Budget 2026 proposals). The viewer is [graph-browser](https://github.com/lambdasistemi/graph-browser); CI assembles and deploys the site to GitHub Pages at <https://lambdasistemi.github.io/cardano-knowledge-maps/>. There is no application code here — changes are RDF triples, SPARQL queries, tutorial stops, and viewer configuration.

## How to work here

- Enter the dev shell first: `nix develop` (provides Python with rdflib, `just`, `jq`, and the EYE reasoner)
- Validate all graph sources: `nix develop --quiet -c just validate`
- Run OWL 2 RL inference smoke: `nix develop --quiet -c just owl-smoke`
- Build the deployable site: `nix build` (output in `./result`)
- Full local gate: `nix develop --quiet -c just ci`
- Data-authoring rules live in `.specify/memory/constitution.md`: every node needs a `cardano:` type in `data/rdf/cardano.ontology.ttl`, every edge predicate needs a `cardano:` property definition and a `gbedge:` alignment, and nodes shared between topic files are promoted to `data/rdf/cardano.ttl`.
- `data/rdf/transactions.ttl` is vendored from cardano-ledger-rdf — never edit it here; refresh it per `data/rdf/PINNED.md`.
- All changes go through PRs; never push to main.

## Skills

Activatable procedures live under `skills/`. Load the one whose description matches your task:

- `skills/cardano-knowledge-maps-guide/` — repository map, verified build/test/run commands, how the data layer composes, and where answers live when users ask about the knowledge maps.
