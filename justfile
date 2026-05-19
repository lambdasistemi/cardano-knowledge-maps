# Build the site via nix
build:
    nix build

# Validate every Turtle file listed in data/config.json::graphSources.
# Mirrors graph-browser's validate-action — parses each TTL via rdflib
# in the nix dev shell (no npm install needed for local gate).
validate:
    python3 .specify/scripts/validate-graph-sources.py

# Run OWL 2 RL inference smoke fixtures via EYE; see
# specs/053-vocab-transactions/smoke/ for fixtures + companion .ask
# files. Skipped automatically if the smoke directory is absent.
owl-smoke:
    python3 .specify/scripts/owl-smoke.py

ci: build validate owl-smoke

# Serve locally
serve: build
    npx serve result -p 10001
