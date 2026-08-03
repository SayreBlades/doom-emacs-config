# doom-emacs-config

My personal [Doom Emacs](https://github.com/doomemacs/doomemacs) configuration.

It's tailored to my own workflow and shared in case it's useful —
primarily because it ships a small library, **table-pretty**, that may
be of independent interest.

## table-pretty — display-only pretty pipe tables

`site-lisp/table-pretty.el` renders markdown / GFM / `md-ts` / org pipe
tables as wrapped, Unicode box-drawing tables using disposable display
overlays. The canonical buffer text always stays valid source, so
export, copy, search, and version control still see the real table.
Think `org-latex-preview`, but for tables.

- `table-pretty-toggle` flips the table at point (or all tables) between
  the pretty view and the raw pipe source. Bound here to `C-c C-x C-k`
  and `SPC t t`.
- Editing a pretty table auto-reveals the raw source (via modification
  hooks, not `read-only`, so undo still works).
- Pretty tables re-render losslessly on window resize.

Inline markdown spans are folded with faces by the centralized
`table-pretty-render-inline-spans`:

| Span | Renders as |
|---|---|
| `\|` | `|` (GFM table-level unescape) |
| `[text](url)`, `![alt](url)` | label, `link` face |
| `**bold**`, `*italic*`, `***both***` | `bold` / `italic` / `bold-italic` |
| `~~strike~~` | strike-through |
| `` `code` `` | `table-pretty-code-face` |

Code spans are extracted first, so their content stays literal
(``` `**not bold**` ``` renders as `**not bold**`, not folded). Columns
size to the rendered text, not the raw markup.

## pi-coding-agent integration

[pi-coding-agent](https://github.com/dnouri/pi-coding-agent) chat tables
are styled by the same `table-pretty-render-inline-spans`, so tables
look identical in chat and in markdown/org file buffers.

It's a clean dependency inversion: pi exposes a
`pi-coding-agent-table-cell-render-function` slot (upstream PR
[#255](https://github.com/dnouri/pi-coding-agent/pull/255), default
`nil` = its own markdown fontification) and never references
table-pretty. `table-pretty` opts in via `with-eval-after-load` when
both are loaded. Disable with `table-pretty-style-pi-chat = nil`.

## Repo layout

```
config.el, init.el, packages.el   Doom configuration
site-lisp/table-pretty.el          the pretty-table library (this repo)
site-lisp/table-pretty.org         table-pretty design notes
site-lisp/markdown-table-wrap/     vendored fork — table wrapping engine
site-lisp/pi.el/                   vendored fork — pi-coding-agent
```

## Submodules

Two submodules point at my public forks (clone recursively to fetch
them):

- `site-lisp/markdown-table-wrap` — [SayreBlades/markdown-table-wrap](https://github.com/SayreBlades/markdown-table-wrap) (`fix/min-column-width`)
- `site-lisp/pi.el` — [SayreBlades/pi.el](https://github.com/SayreBlades/pi.el) (`feature/table-pretty-cell-styling`)

```sh
git clone --recursive https://github.com/SayreBlades/doom-emacs-config.git
```

## Notes

This is a personal config, not a distribution — expect opinionated
keybindings and assumptions. The vendored upstream packages
(`markdown-table-wrap`, `pi.el`) are GPL-3.0-or-later.
