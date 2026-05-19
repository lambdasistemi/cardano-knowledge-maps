#!/usr/bin/env python3
"""OWL 2 RL inference smoke for `data/rdf/transactions.ttl`.

For each fixture in `specs/053-vocab-transactions/smoke/*.n3`:
  1. Run EYE over the union ontology + the curated OWL 2 RL rule subset
     + the fixture, capture the closure.
  2. Load the closure into rdflib.
  3. Execute each ASK query in the fixture's companion `<name>.ask`
     file. Each ASK is preceded by a `# EXPECT: true|false` comment;
     a mismatch fails the gate.

Exits 0 only if every ASK matched its expected outcome and no
`owl:Nothing` instance was inferred.
"""
from __future__ import annotations

import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import rdflib
from rdflib.namespace import OWL, RDF

REPO_ROOT = Path(__file__).resolve().parents[2]
SMOKE_DIR = REPO_ROOT / "specs" / "053-vocab-transactions" / "smoke"

# Files unioned into every smoke run — the published vocabulary.
ONTOLOGY_SOURCES = [
    REPO_ROOT / "data" / "rdf" / "cardano.ontology.ttl",
    REPO_ROOT / "data" / "rdf" / "smart-contracts.ttl",
    REPO_ROOT / "data" / "rdf" / "transactions.ttl",
]

# OWL 2 RL rule fragments bundled with EYE that we always load.
OWL_RULE_FRAGMENTS = [
    "owl-sameAs.n3",
    "owl-inverseOf.n3",
    "owl-hasKey.n3",
    "owl-Nothing.n3",
]


def find_eye_rule_dir() -> Path:
    eye_bin = shutil.which("eye")
    if eye_bin is None:
        raise SystemExit("error: `eye` not in PATH (are you inside `nix develop`?)")
    rule_dir = Path(eye_bin).resolve().parent.parent / "share" / "eye" / "rpo"
    if not rule_dir.is_dir():
        raise SystemExit(f"error: EYE rule directory not found at {rule_dir}")
    return rule_dir


def run_eye(closure_inputs: list[Path]) -> str:
    cmd = ["eye", "--nope", "--quiet", "--pass"] + [str(p) for p in closure_inputs]
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit(f"error: eye exited {result.returncode}; cmd: {shlex.join(cmd)}")
    return result.stdout


def parse_ask_file(text: str) -> list[tuple[bool, str]]:
    """Parse a `.ask` file into a list of (expected, query) pairs.

    Format:
      <optional shared PREFIX lines>
      # EXPECT: true
      ASK { ... }
      # EXPECT: false
      ASK { ... }
    """
    lines = text.splitlines()
    preamble: list[str] = []
    blocks: list[tuple[bool, str]] = []
    current: list[str] | None = None
    current_expected: bool | None = None
    in_preamble = True

    for raw in lines:
        stripped = raw.strip()
        if stripped.startswith("# EXPECT:"):
            if current is not None and current_expected is not None:
                blocks.append((current_expected, "\n".join(preamble + current).strip()))
            verdict = stripped.split(":", 1)[1].strip().lower()
            if verdict not in {"true", "false"}:
                raise SystemExit(f"error: bad EXPECT verdict: {stripped!r}")
            current_expected = verdict == "true"
            current = []
            in_preamble = False
            continue
        if in_preamble:
            preamble.append(raw)
        else:
            assert current is not None
            current.append(raw)
    if current is not None and current_expected is not None:
        blocks.append((current_expected, "\n".join(preamble + current).strip()))
    return blocks


def main() -> int:
    if not SMOKE_DIR.exists():
        print(f"warning: no smoke directory at {SMOKE_DIR}; nothing to check", file=sys.stderr)
        return 0

    rule_dir = find_eye_rule_dir()
    rule_paths = [rule_dir / name for name in OWL_RULE_FRAGMENTS]
    for rp in rule_paths:
        if not rp.exists():
            raise SystemExit(f"error: missing rule fragment {rp}")

    fixtures = sorted(SMOKE_DIR.glob("*.n3"))
    if not fixtures:
        print(f"warning: no .n3 fixtures under {SMOKE_DIR}", file=sys.stderr)
        return 0

    failures: list[str] = []
    for fixture in fixtures:
        ask_file = fixture.with_suffix(".ask")
        if not ask_file.exists():
            failures.append(f"{fixture.name}: companion .ask file missing")
            continue
        closure_inputs = ONTOLOGY_SOURCES + rule_paths + [fixture]
        closure_text = run_eye(closure_inputs)
        closure_graph = rdflib.Graph()
        closure_graph.parse(data=closure_text, format="n3")

        # Universal sanity check: no `owl:Nothing` instances inferred.
        for s in closure_graph.subjects(RDF.type, OWL.Nothing):
            failures.append(f"{fixture.name}: inconsistency — {s!r} a owl:Nothing")

        for idx, (expected, query) in enumerate(parse_ask_file(ask_file.read_text())):
            verdict = bool(closure_graph.query(query).askAnswer)
            status = "ok" if verdict == expected else "fail"
            print(f"{status}: {fixture.name} ask#{idx} expected={expected} got={verdict}")
            if verdict != expected:
                failures.append(
                    f"{fixture.name} ask#{idx}: expected {expected}, got {verdict}"
                )

    if failures:
        print("", file=sys.stderr)
        for f in failures:
            print(f"FAIL: {f}", file=sys.stderr)
        return 1
    print(f"\nall {len(fixtures)} smoke fixture(s) passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
