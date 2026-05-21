#!/usr/bin/env bash
# Pre-push and pre-commit gate for PR backing issue #58
# (Phase A.4 vocab: declare cardano:decodeError predicate; companion to
#  lambdasistemi/cardano-tx-tools#50 / T106 in epic #46).
# Subagents MUST run ./gate.sh and observe success before returning a commit.
# Removed in the final `chore: drop gate.sh (ready for review)` commit before
# the PR is marked ready.
set -euo pipefail

git diff --check

nix develop --quiet -c just ci
