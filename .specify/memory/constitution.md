# Cardano Knowledge Maps Constitution

## Core Principles

### I. RDF-First
The graph is authored and stored as Turtle RDF, split by topic across several focused files (`governance.ttl`, `smart-contracts.ttl`, `cardano.ttl` for shared instance nodes, plus `budget-2026/*.ttl` per proposal). No JSON graph representation exists. All tooling reads Turtle. The domain ontology (`data/rdf/cardano.ontology.ttl`) grounds nodes in W3C standard vocabularies (PROV-O, ORG, SKOS, OWL-Time, FOAF, Dublin Core).

### II. Ontology Alignment
Every node must have a `cardano:` type defined in `cardano.ontology.ttl`. Every edge predicate must have a `cardano:` property definition and a `gbedge:` alignment. New nodes or edges without ontology coverage are incomplete.

### III. Data-Only Repository
This repo contains no application code. The viewer is provided by [graph-browser](https://github.com/lambdasistemi/graph-browser). Changes here are data changes: RDF triples, SPARQL queries, tutorial stops, and configuration.

### IV. Accuracy Over Coverage
Every node description and edge relationship must be verifiable against primary sources (CIP specifications, Cardano documentation, ledger source code). Do not add speculative or unverified content. Link to authoritative sources.

### V. Semantic Completeness
A node addition is not complete until it has:
1. Triples in the topic TTL whose subject the node belongs to (governance / smart-contracts / cardano shared / budget-2026/...)
2. `cardano:` typing in `cardano.ontology.ttl`
3. Edge predicate alignments in `cardano.ontology.ttl`
4. Inclusion in relevant SPARQL queries (`queries.json`)
5. Coverage in at least one guided tour (`tutorials/`)

A node referenced by ≥2 focused TTLs is promoted to `cardano.ttl` (the shared instance layer).

## Data Format Constraints

- Graph sources: topic-split Turtle under `data/rdf/` (loaded in order via `data/config.json::graphSources`)
- Domain ontology: `data/rdf/cardano.ontology.ttl` (hand-authored Turtle)
- Queries: `data/queries.json` (SPARQL SELECT returning `?node`)
- Tutorials: `data/tutorials/*.json` (stops reference node IDs from the graph)
- Config: `data/config.json` (kinds, colors, shapes for the viewer)

## Development Workflow

- All changes via PRs, never push to main
- CI validates RDF syntax and schema conformance
- Surge preview before merge for visual verification
- Linear git history (rebase merge)

## Quality Gates

- `just validate` passes (RDF parses via oxigraph)
- CI green (graph-browser validate-action + build-action)
- Tutorial stops reference valid node IDs
- SPARQL queries use `cardano:` vocabulary, not raw `gb:` where a domain property exists
