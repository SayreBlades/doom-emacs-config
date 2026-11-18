#!/usr/bin/env bash
# Start and stop only a uniquely named disposable daemon, not the user server.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOOM_REFACTOR_PHASE="${1:-5}"
export DOOMDIR="$root"
emacs="${EMACS:-emacs}"
client="${EMACSCLIENT:-emacsclient}"
emacsdir="${EMACSDIR:-$(dirname "$root")/emacs}"
if [[ ! -f "$emacsdir/early-init.el" ]]; then
  printf 'Set EMACSDIR to the Doom installation (missing %s/early-init.el)\n' "$emacsdir" >&2
  exit 1
fi
name="doom-refactor-$$"
cleanup() {
  "$client" --socket-name="$name" --eval '(let ((kill-emacs-hook nil)) (kill-emacs))' >/dev/null 2>&1 || true
}
trap cleanup EXIT
"$emacs" --init-directory="$emacsdir" --daemon="$name"
# Pass the path through a bound environment variable rather than Elisp quoting.
result="$("$client" --socket-name="$name" --eval \
  '(condition-case err (with-timeout (45 (error "Cold checks timed out; check for missing prerequisites or interactive prompts")) (load (expand-file-name "tests/cold-start-check.el" (getenv "DOOMDIR")) nil t t) :ok) (error (list :failed (error-message-string err))))')"
printf '%s\n' "$result"
# Keep loaded origins in the execution log, not just the existence of clones.
"$client" --socket-name="$name" --eval \
  '(mapcar (lambda (name) (list name (locate-library name))) (quote ("yank-rich" "yank-rich-evil" "table-pretty" "markdown-table-wrap" "md-ts-mode" "pilish")))'
if [[ "$result" != ':ok' ]]; then
  "$client" --socket-name="$name" --eval '(with-current-buffer "*Messages*" (buffer-string))'
  exit 1
fi
