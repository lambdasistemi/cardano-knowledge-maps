#!/usr/bin/env bash
# Pre-push and pre-commit gate for PR backing issue #53
# (publish transactions.ttl vocabulary extending the cardano: namespace;
#  feeds lambdasistemi/cardano-tx-tools epic #46).
# Subagents MUST run ./gate.sh and observe success before returning a commit.
# Removed in the final `chore: drop gate.sh (ready for review)` commit before
# the PR is marked ready.
set -euo pipefail

git diff --check

nix develop --quiet -c just ci
