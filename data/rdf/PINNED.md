# Pinned RDF Vocabulary

`data/rdf/transactions.ttl` is vendored from `lambdasistemi/cardano-ledger-rdf`.
That repository now owns the `cardano:` transaction vocabulary; this repository
consumes it as a pinned downstream copy for the graph browser and validation
gates.

## Source

- Repository: `lambdasistemi/cardano-ledger-rdf`
- Source path: `vocab/cardano/transactions.ttl`
- Source commit: `27b68fc0f8eda2f8b2f66db7728781888e60bbea`
- Published IRI namespace: `https://lambdasistemi.github.io/cardano-ledger-rdf/vocab/cardano#`

## Refresh

Refresh from a reviewed ledger-rdf tag or commit, then run this repository's
validation gate before committing:

```sh
REF=27b68fc0f8eda2f8b2f66db7728781888e60bbea
curl -fsSL \
  "https://raw.githubusercontent.com/lambdasistemi/cardano-ledger-rdf/${REF}/vocab/cardano/transactions.ttl" \
  -o data/rdf/transactions.ttl
nix develop --quiet -c just ci
```
