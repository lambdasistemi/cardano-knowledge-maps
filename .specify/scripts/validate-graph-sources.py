#!/usr/bin/env python3
"""Validate every Turtle file listed in data/config.json::graphSources.

Mirrors what the graph-browser validate-action does in CI (parses each
TTL via oxigraph), but uses rdflib so we can run it through the local
nix dev shell without an npm install step.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import rdflib


def main() -> int:
    repo_root = Path(__file__).resolve().parents[2]
    config_path = repo_root / "data" / "config.json"
    config = json.loads(config_path.read_text())

    sources = config.get("graphSources") or []
    if not sources:
        print("error: data/config.json has no graphSources entries", file=sys.stderr)
        return 1

    failed = 0
    total_triples = 0
    for source in sources:
        path = source.get("path")
        fmt = source.get("format") or "text/turtle"
        if path is None:
            print(f"error: graphSources entry missing path: {source!r}", file=sys.stderr)
            failed += 1
            continue
        ttl_path = repo_root / path
        if not ttl_path.exists():
            print(f"error: {path}: file not found", file=sys.stderr)
            failed += 1
            continue
        graph = rdflib.Graph()
        try:
            graph.parse(source=str(ttl_path), format=fmt)
        except Exception as exc:  # rdflib raises BadSyntax / various
            print(f"error: {path}: {exc}", file=sys.stderr)
            failed += 1
            continue
        triples = len(graph)
        total_triples += triples
        print(f"ok: {path}: {triples} triples")

    if failed:
        print(f"\n{failed} source(s) failed to parse", file=sys.stderr)
        return 1
    print(f"\nall {len(sources)} graphSources parsed; {total_triples} triples total")
    return 0


if __name__ == "__main__":
    sys.exit(main())
