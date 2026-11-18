#!/usr/bin/env bash
# Run the refactor ERT suite in an isolated emacs -Q --batch process.
# No GUI, no live Doom session, no doom sync; fixtures live in temp dirs.
set -euo pipefail

DOOM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DOOM_DIR"

# Optional baseline override for the preservation tests:
#   DOOM_REFACTOR_BASELINE_DIR=/path/to/backup/doom tests/run-refactor-tests.sh
exec "${EMACS:-emacs}" -Q --batch -l tests/refactor-tests.el -f ert-run-tests-batch-and-exit "$@"
