# Build the site via nix
build:
    nix build

# Validate every Turtle file listed in data/config.json::graphSources.
# Mirrors graph-browser's validate-action — parses each TTL via rdflib
# in the nix dev shell (no npm install needed for local gate).
validate:
    python3 .specify/scripts/validate-graph-sources.py

ci: build validate

# Serve locally
serve: build
    npx serve result -p 10001
