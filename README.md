# doom-emacs-config

My personal [Doom Emacs](https://github.com/doomemacs/doomemacs)
configuration. This is an opinionated setup, not a distribution.

## Layout and ownership

```text
init.el, config.el, packages.el   module selection and general preferences
modules/sayre/pins.el             shared exact package revisions
modules/sayre/yank-rich/          copying packages, Evil keys, tool diagnostics
modules/sayre/table-pretty/       table packages, hooks and toggle bindings
modules/sayre/diagrams/           Org diagrams, .puml and diagram window rules
modules/sayre/pilish/             local development recipe, UI, reload, diagnostics
modules/sayre/vterm/              terminal reuse, window rules and navigation
sources/pilish/                  locally owned development submodule
tests/                           isolated fixture and cold-start checks
```

The personal `:sayre` modules load **after** `:config default`: Doom's default
prefix maps must exist before personal leader bindings are installed. Fonts,
theme, machine preferences, general Org cache/inline-image preferences,
Dired/Vertico tuning, shared Shift-Return navigation and the compilation popup
rule remain in root `config.el`.

The reusable **yank-rich** and **table-pretty** libraries live in private
[SayreBlades/emacs-world](https://github.com/SayreBlades/emacs-world), with their
own documentation, portable tests and GPL-3.0-or-later licensing. Straight
installs both from one checkout at one shared commit. Edit the separate
authoring clone, **not** Straight's downloaded checkout or generated builds.

## Bootstrap

Install Doom and its normal prerequisites first. Access to emacs-world requires
an authorized GitHub SSH key. Do not put credentials in recipes.

```sh
git clone https://github.com/SayreBlades/doom-emacs-config.git ~/.config/doom
cd ~/.config/doom
# Initialize the local development source BEFORE package installation.
git submodule update --init --recursive sources/pilish
GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
  git ls-remote git@github.com:SayreBlades/emacs-world.git
doom sync
# Fully restart Emacs; do not substitute reloading config.el.
```

A missing `sources/pilish/pilish.el` deliberately stops sync with an initialization
message. The source path is derived from `doom-user-dir` in
`modules/sayre/pilish/shared.el`, shared by the manifest, diagnostics and reload.
Straight does not update this checkout. Its branch, inner edits, refs and stashes
remain yours; a parent Git commit does not back up uncommitted child work.

This profile expects the existing Doom Evil, Markdown, Org, PlantUML, popup and
vterm modules. External programs include `pi`, `pandoc`, macOS `textutil`/`pbcopy`,
and `/opt/homebrew/bin/mmdc` (`npm install -g @mermaid-js/mermaid-cli`). Mermaid's
exact executable is shared by runtime and doctor in `diagrams/shared.el`.
Org rich copying uses ox-clip's separate platform clipboard configuration.

## Commands and behavior

- **`gyr` / `gyp`**: rich RTF / stripped plain copying, accepting visual selections
  and Evil motions (`gyrip`, `gypip`). Ordinary `y` is unchanged. Region commands
  `M-x yank-rich-rich` and `M-x yank-rich-plain` also work without Evil.
- **`SPC t t`** and **`C-c C-x C-k`**: toggle pretty tables. Markdown, GFM, md-ts and
  Org use table-pretty; Pilish chat dispatches to its own renderer. Localleader
  aliases are preserved. Display overlays never change canonical table text;
  edits reveal raw source and resize re-renders losslessly.
- **`SPC o p`**: Pilish. Default backend `("pi")`, initial trust policy `default`,
  normal-state input and chat-only display. `my/pilish-toggle-backend` retains the
  pi/omp policy transitions; prefix forces pi for new sessions.
- **`SPC o T`**: full-window vterm, reusing an existing hidden non-popup terminal.
  Prefix keeps Doom's original behavior. `SPC o t` keeps Doom's popup terminal.
- **Shift-Return**: shared other-window link/file navigation, including in vterm.

Pilish tables use `pilish-table-cell-render-function` to opt into table-pretty's
inline-span styler (links, bold/italic/strike/code). Pilish never depends on the
personal renderer. The engine is pinned separately and its upstream pretty
companion is excluded to avoid two active renderers.

### Pilish development loop

Edit `sources/pilish/`, then run `M-x pi-reload`. It reloads explicit absolute
`.el` files in dependency order, including optional Evil integration, so stale
`.elc` siblings cannot win. This replaces definitions; it does not tear down
running sessions/timers or remove obsolete definitions. Restart for package,
module, dependency, or startup-order changes.

## Controlled package updates

`modules/sayre/pins.el` holds full SHAs for emacs-world, md-ts-mode and the table
engine. Both world packages advance together because they share a Git checkout.

1. Edit the independent emacs-world authoring clone, run its tests, commit and push.
2. Change its **one shared pin** here.
3. Run plain `doom sync`, fully restart and verify checkout SHAs, loaded origins,
   keys and behavior; commit the tested pin change.

Do not use `doom sync -u` for this workflow: it updates all packages. `-U` skips
the pin-update pass and is also not the intended workflow. No Doom core upgrade
is implied. Check relevant profile lockfiles deliberately if a pin does not take
effect. The table module owns engine/md-ts recipe edits; the identical declarations
in the Pilish module must change in the same commit so either module works alone.

If a future world revision adds another package directory, first advance the pin
and sync with the existing packages, then enable the new package and sync again.
Sync ensures/builds packages before its update pass. The initial migration
published both library folders before either was enabled.

For non-Doom installation, declared Lisp/external dependencies, manual autoload
registration and explicit optional Evil adapter activation, see emacs-world's
README. Adding a directory to `load-path` alone does not execute autoload cookies.
The Evil adapter is intentionally source-only; the core/table libraries compile
normally. Local Pilish builds intentionally skip byte/native compilation.

## Validation

```sh
# Pure disposable fixtures: no Doom startup or terminal/backend processes.
tests/run-refactor-tests.sh
# Optional pre-refactor backup for exact preservation comparisons:
DOOM_REFACTOR_BASELINE_DIR=/private/backup/doom tests/run-refactor-tests.sh
# Real startup in a uniquely named temporary daemon, never the user's server:
tests/run-cold-start-check.sh
# Portable libraries, from the independent authoring clone:
/path/to/emacs-world/tests/run-tests.sh
```

Cold checks cover effective leader targets before/after Markdown and Org load,
package origins, source-only exceptions, table source preservation, shared Mermaid
settings and Pilish reload/backend policy. Fixtures cover missing sources,
selected-backend diagnostics, stale bytecode, recipe consistency and terminal
reuse/prefix logic. The real cold source-reload probe is
`tests/source-reload-check.el`; run it in `emacs -Q --batch` with Pilish's declared
dependency directories on `load-path` (without requiring Pilish first).

These do not replace live RTF application/clipboard, chat/UI, diagram-window and
terminal-focus checks. Keep those pending until actually exercised. Compare
`doom doctor` warnings against the baseline rather than attributing existing
machine/tool warnings to this refactor.

## Recovery

Keep independent private worktree **and actual Git-store** backups of development
submodules, including local refs/stashes/ignored files. During this migration,
the old engine Git store remains at `.git/modules/site-lisp/markdown-table-wrap`;
its removal is a separate decision, not part of sync or this refactor.

1. Preserve any new parent AND child work before restoring anything.
2. Choose the last tested configuration commit and its matching package pins.
   Revert on a safe recovery branch; do not reset the child to a revision from
   old prose.
3. Restore the engine worktree/entry from its retained Git store or independent
   backup if returning to the old layout. Restore Pilish's path, branch, refs,
   stashes and inner work from its own matching backup; never force-update a
   dirty child checkout. A moved Git store may need `core.worktree` repaired.
4. Sync, fully restart, and verify actual revisions, origins and feature behavior.

A configuration commit is only one part of a checkpoint. Keep dependency SHAs,
Doom/Emacs versions, build paths, inner source state, backup locations and test
results with it. Machine-private execution evidence is recorded separately in
`.scratch/refactor-checkpoints.md` and alongside the protected backups.
