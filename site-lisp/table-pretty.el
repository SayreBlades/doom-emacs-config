;;; table-pretty.el --- Display-only pretty rendering of pipe tables -*- lexical-binding: t; -*-

;; Copyright (C) 2026 SayreBlades
;; SPDX-License-Identifier: GPL-3.0-or-later

;; Author: SayreBlades
;; Keywords: convenience, wp, markdown, org, tables

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Display-only pretty rendering of markdown/org pipe tables, with an
;; in-place toggle between a read-only pretty view and the canonical
;; raw pipe text — like inline images or `org-latex-preview': the
;; buffer text is always the canonical source; a display overlay shows
;; a wrapped, box-drawing rendering on top; one command toggles it off
;; to reveal/edit the raw source.
;;
;; Why display-only (not buffer mutation): `markdown-table-wrap' wraps
;; a long cell into multiple `| ... |' rows, but pipe-table syntax has
;; no row-spanning, so any real renderer (cmark-gfm, pandoc, GitHub,
;; org HTML export) sees N independent data rows, not one wrapped cell.
;; Mutating the buffer looks right in Emacs but is semantically broken
;; the moment it leaves Emacs (export, copy-paste, push, send-to-LLM).
;; This library keeps the buffer canonical — export/copy/share always
;; see real tables — and makes the pretty rendering a disposable
;; display layer.
;;
;; Model (mirrors `org-latex-preview', `C-c C-x C-l'):
;;   - One display overlay per raw line (so `C-n' walks raw lines and
;;     big tables scroll naturally; the toggle is still whole-table).
;;   - Pretty = a view; editing reveals the raw source automatically
;;     (via `modification-hooks' that remove the overlays on edit —
;;     same pattern `org-latex-preview' uses, NOT `read-only', which
;;     would break undo).  Toggle back to re-render from canonical.
;;   - State = overlay presence (no bookkeeping): "is this table
;;     pretty?" = "does it have `table-pretty-display' overlays?".
;;   - Resize re-renders pretty tables losslessly (regenerate from
;;     canonical; never unwrap).  Tables toggled to raw stay raw.
;;
;; Toggle command (`table-pretty-toggle') — point-aware, like
;; `org-latex-preview':
;;   - Point on a table      → toggle that table.
;;   - Point off-table        → toggle all tables in the buffer.
;;   - Active region          → toggle tables overlapping the region.
;;   - `C-u'                  → force pretty on all tables in the buffer.
;;   - `C-u C-u'              → force raw on all tables in the buffer.
;;
;; Keybindings: this library ships NO default key (it has no
;; major-mode map of its own).  A consistent cross-mode key is the
;; user's to choose.  The documented recommendation is `C-c C-x C-k'
;; (the only free, non-surprising `C-c C-x C-<letter>' slot in both
;; `markdown-mode' and `org-mode').  See the doom config example in
;; the accompanying plan (`.scratch/PRETTY-TOGGLE.md').  Example:
;;
;;   (define-key markdown-mode-map (kbd "C-c C-x C-k") #'table-pretty-toggle)
;;   (define-key org-mode-map       (kbd "C-c C-x C-k") #'table-pretty-toggle)
;;
;; Detection is universal line-based (`^[ \t]*|' runs, code-fence
;; guarded for markdown flavors, `org-in-src-block-p' for org) — no
;; tree-sitter dependency, so it works in `markdown-mode', `gfm-mode',
;; `md-ts-mode', and `org-mode'.  NOTE: upstream `markdown-table-wrap'
;; PR #2 (`helper-table-inspection') adds
;; `markdown-table-wrap-table-bounds'/`markdown-table-wrap-table-regions'
;; which do exactly this detection; once that PR merges, replace
;; `table-pretty--table-bounds'/`table-pretty--table-regions' here
;; with the upstream functions and delete the vendored copies.
;;
;; Org: `|---+---|' hlines and width cookies `<[lrc]?[0-9]*>' are
;; stripped for *rendering only*; the raw buffer keeps them.  A
;; trailing `#+TBLFM:' line is outside the table region and stays
;; visible/unchanged (formulas are inert while pretty, live when raw).
;; We do NOT refuse `#+TBLFM' tables (unlike the abandoned in-buffer
;; predecessor).
;;
;; Depends only on `markdown-table-wrap' (public API: `markdown-table-wrap',
;; `markdown-table-wrap-cell', `markdown-table-wrap-compute-widths',
;; `markdown-table-wrap--split-table-row', `markdown-table-wrap-inside-code-fence-p',
;; `markdown-table-wrap-visible-width').  No pi/doom deps.  Designed to
;; later merge into `markdown-table-wrap' as
;; `markdown-table-wrap-pretty.el'.

;;; Code:

(require 'cl-lib)
(require 'markdown-table-wrap)

(declare-function org-at-table-p "org" (&optional pos))
(declare-function org-in-src-block-p "org" (&optional inside))

;;;; Customization

(defgroup table-pretty nil
  "Display-only pretty rendering of pipe tables."
  :group 'text
  :group 'convenience)

(defcustom table-pretty-prettify t
  "Non-nil means render pretty tables with Unicode box-drawing characters.
Nil means use plain markdown pipes (`|').  Mirrors pi's
`pi-coding-agent-prettify-tables'."
  :type 'boolean
  :group 'table-pretty)

(defcustom table-pretty-auto-rewrap-on-resize t
  "Non-nil means re-render pretty tables when the window is resized.
Re-rendering is lossless (regenerate overlays from canonical source).
Tables toggled to raw stay raw.  Nil disables the resize hook."
  :type 'boolean
  :group 'table-pretty)

(defcustom table-pretty-max-cell-height nil
  "Maximum number of visual lines per cell, or nil for unlimited.
When non-nil, taller cells are truncated with an ellipsis."
  :type '(choice (const :tag "Unlimited" nil) integer)
  :group 'table-pretty)

(defcustom table-pretty-default-on-major-modes nil
  "Major modes where tables default to pretty when `table-pretty-mode' is on.
A list of major-mode symbols.  Default is nil (tables start raw
everywhere; toggle on demand).  Example:
  (setq table-pretty-default-on-major-modes \\='(markdown-mode org-mode))"
  :type '(repeat symbol)
  :group 'table-pretty)

(defcustom table-pretty-rewrap-idle-delay 0.3
  "Seconds to wait after a resize before re-rendering pretty tables.
0 means immediate.  Debounces window drag."
  :type 'number
  :group 'table-pretty)

;;;; Buffer-Local State

;; Forward declaration: `table-pretty-mode' is defined by `define-minor-mode'
;; below; referenced earlier by `table-pretty--schedule-refresh' and
;; `table-pretty--maybe-default-pretty'.
(defvar table-pretty-mode nil)

(defvar-local table-pretty--last-width nil
  "Last window width used for table rendering in this buffer.")

(defvar-local table-pretty--refresh-timer nil
  "Idle timer for debounced resize re-render in this buffer.")

;;;; Width

(defun table-pretty--display-window ()
  "Return a visible window showing the current buffer, or nil."
  (or (get-buffer-window (current-buffer) nil)
      (get-buffer-window (current-buffer) 'visible)))

(defun table-pretty--window-width ()
  "Return usable character columns for the current buffer's window.
Falls back to 80 when the buffer has no visible window.  NOTE: this is
the raw window capacity and does NOT account for per-line visual
prefixes such as `line-prefix'/`wrap-prefix' (set by `org-indent-mode').
Use `table-pretty--effective-width-at' for the width actually
available at a given buffer position."
  (if-let* ((win (table-pretty--display-window)))
      (or (window-max-chars-per-line win) 80)
    80))

(defun table-pretty--prefix-display-width (spec)
  "Return the display width of a `line-prefix'/`wrap-prefix' value SPEC.
SPEC may be nil, a string, or a display spec; only the string case is
measured (what `org-indent-mode' sets).  Returns 0 otherwise."
  (cond
   ((stringp spec)
    (if (= (length spec) (string-bytes spec))
        (length spec)                 ; ASCII fast path (spaces)
      (let ((w 0) (i 0) (n (length spec)))
        (while (< i n) (setq w (+ w (char-width (aref spec i))) i (1+ i)))
        w)))
   (t 0)))

(defun table-pretty--indent-width-at (pos)
  "Return the visual indent width consumed by text properties at POS.
Accounts for `line-prefix' and `wrap-prefix' (set by `org-indent-mode'
and other indentation minor modes), which eat columns that
`window-max-chars-per-line' does not see."
  (let ((line-pfx (get-text-property pos 'line-prefix))
        (wrap-pfx (get-text-property pos 'wrap-prefix)))
    (+ (table-pretty--prefix-display-width line-pfx)
       (table-pretty--prefix-display-width wrap-pfx))))

(defun table-pretty--effective-width-at (&optional pos)
  "Return the usable table width at POS (default: point).
Window capacity minus any visual indent prefix at POS (e.g. org-indent).
Never returns less than 1."
  (max 1 (- (table-pretty--window-width)
            (table-pretty--indent-width-at (or pos (point))))))

;;;; Detection

(defconst table-pretty--table-line-re "\\`[[:blank:]]*|"
  "Regexp matching the start of a pipe-table line.
The leading backtick anchors to the start of a line STRING (used via
`string-match-p'), not to `point-min'.  See `table-pretty--table-line-p'.")

(defun table-pretty--table-line-p (&optional line)
  "Return non-nil when LINE (or the current line) is a pipe-table line."
  (if line
      (string-match-p table-pretty--table-line-re line)
    ;; Operate on the line STRING so the regex backtick anchors to the
    ;; line start, not `point-min' (which `looking-at-p' would do).
    (save-excursion
      (beginning-of-line)
      (string-match-p
       table-pretty--table-line-re
       (buffer-substring-no-properties
        (point) (line-end-position))))))

(defun table-pretty--separator-line-p (line)
  "Return non-nil when LINE is a pipe-table separator row.
Accepts both GFM (`|---|---|') and org (`|---+---|') separators."
  (let ((trimmed (string-trim line)))
    (and (string-prefix-p "|" trimmed)
         (or (string-suffix-p "|" trimmed)
             (string-suffix-p "|" (substring trimmed 0 -1)))
         (string-match-p "\\`|[-: +]*[-: +|]*|?\\'"
                         (replace-regexp-in-string
                          "[[:blank:]]" "" trimmed)))))

(defun table-pretty--inside-code-fence-p (pos)
  "Return non-nil when POS is inside a code block (fence or org src)."
  (cond
   ((derived-mode-p 'org-mode)
    (and (fboundp 'org-in-src-block-p)
         (save-excursion (goto-char pos) (org-in-src-block-p))))
   ((or (derived-mode-p 'markdown-mode) (eq major-mode 'md-ts-mode))
    (markdown-table-wrap-inside-code-fence-p pos))
   (t nil)))

(defun table-pretty--block-has-separator-p (beg end)
  "Return non-nil when the line block BEG..END contains a separator row."
  (save-excursion
    (goto-char beg)
    (while (and (< (point) end)
                (not (table-pretty--separator-line-p
                      (buffer-substring-no-properties
                       (line-beginning-position)
                       (min end (line-end-position))))))
      (forward-line 1))
    (< (point) end)))

(defun table-pretty--table-bounds (&optional pos)
  "Return (BEG . END) for the pipe table at POS, or nil.
END is the start of the first line after the table.  Returns nil when
POS is not on a table line, the block has no separator row, or the
block is inside a code fence."
  (save-excursion
    (goto-char (or pos (point)))
    (beginning-of-line)
    (when (table-pretty--table-line-p)
      (while (and (not (bobp))
                  (save-excursion (forward-line -1) (table-pretty--table-line-p)))
        (forward-line -1))
      (let ((beg (line-beginning-position)))
        (while (and (not (eobp)) (table-pretty--table-line-p))
          (forward-line 1))
        (let ((end (point)))
          (and (table-pretty--block-has-separator-p beg end)
               (not (table-pretty--inside-code-fence-p beg))
               (cons beg end)))))))

(defun table-pretty--table-regions (beg end)
  "Return pipe-table regions overlapping BEG..END, in buffer order.
Each element is (TABLE-BEG . TABLE-END) as from `table-pretty--table-bounds'."
  (let ((start (min beg end))
        (limit (max beg end))
        (regions nil))
    (save-excursion
      (goto-char start)
      (beginning-of-line)
      (while (< (point) limit)
        (let ((bounds (table-pretty--table-bounds (point))))
          (if bounds
              (progn
                (when (> (cdr bounds) start)
                  (push bounds regions))
                (goto-char (cdr bounds)))
            (forward-line 1)))))
    (nreverse regions)))

;;;; Parsing

(defun table-pretty--normalize-org-line (line)
  "Normalize org table LINE for GFM-style parsing.
Strip org width cookies `<[lrc]?[0-9]*>'.  Convert org hline
separators (`|---+---|') to GFM form (`|---|---|')."
  (let ((stripped (replace-regexp-in-string "<[lrc]?[0-9]*>" "" line)))
    (if (and (derived-mode-p 'org-mode)
             (table-pretty--separator-line-p stripped))
        (replace-regexp-in-string "+" "|" stripped)
      stripped)))

(defun table-pretty--alignments (separator-line)
  "Return column alignment symbols parsed from SEPARATOR-LINE.
Detects GFM colons (`:---:', `:---', `---:'); org defaults to left (nil)."
  (mapcar (lambda (cell)
            (let ((trimmed (string-trim cell)))
              (cond
               ((and (string-prefix-p ":" trimmed)
                     (string-suffix-p ":" trimmed)) 'center)
               ((string-suffix-p ":" trimmed) 'right)
               ((string-prefix-p ":" trimmed) 'left)
               (t nil))))
          (markdown-table-wrap--split-table-row (string-trim separator-line))))

(defun table-pretty--parse-table (raw-lines)
  "Parse RAW-LINES into (HEADERS ALIGNS ROWS).
RAW-LINES is a list of pipe-table line strings (no trailing newlines).
Handles both GFM and org separators.  Org width cookies are stripped
for parsing only.  Returns nil when there is no separator or no header."
  (let* ((norm (mapcar #'table-pretty--normalize-org-line raw-lines))
         (sep-idx (cl-position-if #'table-pretty--separator-line-p norm)))
    (when (and sep-idx (> sep-idx 0))
      (let* ((header-line (car norm))
             (sep-line (nth sep-idx norm))
             (data-lines (cl-subseq norm (1+ sep-idx)))
             (headers (markdown-table-wrap--split-table-row
                       (string-trim header-line)))
             (aligns (table-pretty--alignments sep-line))
             (rows (mapcar (lambda (l)
                             (markdown-table-wrap--split-table-row
                              (string-trim l)))
                           data-lines)))
        (list headers aligns rows)))))

;;;; Rendering

(defun table-pretty--render-links-in-cell (cell)
  "Render markdown link/image spans in CELL to display form.
A link `[text](url)' becomes `text' with the `link' face and a
`help-echo' showing the url; an image `![alt](url)' becomes `alt'
likewise.  Other text is unchanged.  Returns a new propertized
string (the original CELL is not mutated).

No-op when `table-pretty-prettify' is nil: in the raw pipe view
(non-prettify) the canonical markdown syntax is shown verbatim so
the buffer reads as valid source.  Only the pretty box-drawing view
folds links to their underlined label, like a rendered markdown
preview.  Text properties survive `markdown-table-wrap-cell'
(`substring'/`concat' preserve them), so wrapping and padding keep
the underline attached to the label across wrapped continuation
lines.  Width measurement (`markdown-table-wrap-visible-width')
ignores text properties, so columns size to the visible label, not
the full `[label](url)' — giving wide-link columns their space back."
  (if (not table-pretty-prettify)
      cell
    (let ((s (replace-regexp-in-string
              "!\\[\\([^]]*\\)\\](\\([^)]*\\))"
              (lambda (m)
                (propertize (or (match-string 1 m) "")
                            'face 'link 'mouse-face 'highlight
                            'help-echo (or (match-string 2 m) "")))
              cell t t)))
      (replace-regexp-in-string
       "\\[\\([^]]*\\)\\](\\([^)]*\\))"
       (lambda (m)
         (propertize (or (match-string 1 m) "")
                     'face 'link 'mouse-face 'highlight
                     'help-echo (or (match-string 2 m) "")))
       s t t))))

(defun table-pretty--render-row-lines (cells col-widths aligns)
  "Render table CELLS into display lines using COL-WIDTHS and ALIGNS.
When `table-pretty-prettify' is non-nil, emit Unicode box-drawing
verticals instead of markdown pipes.  Returns a list of display-line
strings (one per wrapped visual row)."
  (let* ((num-cols (length col-widths))
         (padded (append cells
                         (make-list (max 0 (- num-cols (length cells))) "")))
         (wrapped-cells
          (cl-mapcar (lambda (cell column-width)
                       (markdown-table-wrap-cell (or cell "") column-width))
                     padded col-widths))
         (max-height (apply #'max (mapcar #'length wrapped-cells)))
         (pretty table-pretty-prettify)
         (delim-open  (if pretty "│ " "| "))
         (delim-mid   (if pretty " │ " " | "))
         (delim-close (if pretty " │" " |")))
    (cl-loop for line-index below max-height
             collect
             (let ((acc (list delim-open)))
               (cl-loop for cell-lines in wrapped-cells
                        for column-width in col-widths
                        for align in aligns
                        for first = t then nil
                        do
                        (unless first (push delim-mid acc))
                        (let* ((cell (or (nth line-index cell-lines) ""))
                               (empty (string-empty-p cell))
                               (pad (if empty
                                        column-width
                                      (max 0 (- column-width
                                                 (markdown-table-wrap-visible-width cell))))))
                          (cond
                           (empty
                            (push (make-string column-width ?\s) acc))
                           ((eq align 'right)
                            (push (make-string pad ?\s) acc)
                            (push cell acc))
                           ((eq align 'center)
                            (let ((left-pad (/ pad 2)))
                              (push (make-string left-pad ?\s) acc)
                              (push cell acc)
                              (push (make-string (- pad left-pad) ?\s) acc)))
                           (t
                            (push cell acc)
                            (push (make-string pad ?\s) acc)))))
               (push delim-close acc)
               (apply #'concat (nreverse acc))))))

(defun table-pretty--render-separator-line (col-widths aligns)
  "Render the separator line for COL-WIDTHS and ALIGNS.
When `table-pretty-prettify' is non-nil, emit a box-drawing rule;
otherwise emit standard markdown separator syntax."
  (if table-pretty-prettify
      (concat "├─" (mapconcat (lambda (w) (make-string (max 1 w) ?─))
                              col-widths "─┼─")
              "─┤")
    (let ((parts
           (cl-mapcar
            (lambda (column-width align)
              (let ((dashes (make-string (max 1 column-width) ?-)))
                (pcase align
                  ('left
                   (if (>= column-width 2)
                       (concat ":" (substring dashes 1))
                     ":"))
                  ('right
                   (if (>= column-width 2)
                       (concat (substring dashes 1) ":")
                     ":"))
                  ('center
                   (if (>= column-width 3)
                       (concat ":" (substring dashes 2) ":")
                     (if (>= column-width 2) "::" ":")))
                  (_ dashes))))
            col-widths aligns)))
      (concat "| " (mapconcat #'identity parts " | ") " |"))))

;;;; Display Groups (per raw line)

(defun table-pretty--split-line-prefix (line)
  "Split table LINE into (PREFIX . BARE).
PREFIX is everything before the first `|'; BARE starts at the first `|'."
  (if-let* ((pipe-index (string-match-p "|" line)))
      (cons (substring line 0 pipe-index)
            (substring line pipe-index))
    (cons "" line)))

(defun table-pretty--table-display-groups (raw-lines width)
  "Return prefix-aware display groups for RAW-LINES at WIDTH.
Each result element corresponds to one raw source line and is a list of
the display lines for that logical table row.  Container prefixes
(blockquotes, indentation) are preserved on every visual continuation
line.  Plain tables (no prefix) take a fast path."
  (let* ((no-prefix (cl-every (lambda (l) (and (> (length l) 0)
                                                (= (aref l 0) ?|)))
                               raw-lines))
         (parts (unless no-prefix
                  (mapcar #'table-pretty--split-line-prefix raw-lines)))
         (prefixes (unless no-prefix (mapcar #'car parts)))
         (bare-lines (if no-prefix raw-lines (mapcar #'cdr parts)))
         (prefix-width (if no-prefix 0
                          (apply #'max 0 (mapcar #'string-width prefixes)))))
    (when (and (>= (length bare-lines) 2)
               (table-pretty--parse-table bare-lines))
      (pcase-let* ((`(,headers ,aligns ,rows)
                   (table-pretty--parse-table bare-lines))
                  ;; Fold link/image spans to their underlined label
                  ;; for the pretty view, so columns size and render
                  ;; to the visible label (e.g. `L1_aos_full') rather
                  ;; than the full `[label](url)'.  `table-pretty--render-links-in-cell'
                  ;; is a no-op when `table-pretty-prettify' is nil.
                  (disp-headers (mapcar #'table-pretty--render-links-in-cell
                                        headers))
                  (disp-rows (mapcar (lambda (r)
                                       (mapcar #'table-pretty--render-links-in-cell r))
                                     rows))
                  (num-cols (max (length disp-headers)
                                 (length aligns)
                                 (if disp-rows
                                     (apply #'max (mapcar #'length disp-rows))
                                   0)))
                  (content-width (max 1 (- width prefix-width)))
                  (col-widths
                   (markdown-table-wrap-compute-widths
                    disp-headers disp-rows content-width num-cols))
                  (header-lines
                   (table-pretty--render-row-lines disp-headers col-widths aligns))
                  (separator-line
                   (table-pretty--render-separator-line col-widths aligns))
                  (row-groups
                   (mapcar (lambda (row)
                             (table-pretty--render-row-lines
                              row col-widths aligns))
                           disp-rows)))
        (if no-prefix
            (append (list header-lines)
                    (list (list separator-line))
                    row-groups)
          (append
           (list (mapcar (lambda (l) (concat (car prefixes) l)) header-lines))
           (list (list (concat (nth 1 prefixes) separator-line)))
           (cl-mapcar (lambda (prefix row-lines)
                        (mapcar (lambda (l) (concat prefix l)) row-lines))
                      (nthcdr 2 prefixes)
                      row-groups)))))))

;;;; Overlay Management

(defun table-pretty--overlays-in (beg end)
  "Return the `table-pretty-display' overlays in BEG..END."
  (cl-remove-if-not
   (lambda (ov) (overlay-get ov 'table-pretty-display))
   (overlays-in beg end)))

(defun table-pretty--undecorate-table (beg end)
  "Remove all table-pretty display overlays in BEG..END."
  (dolist (ov (table-pretty--overlays-in beg end))
    (delete-overlay ov)))

(defun table-pretty--table-pretty-p (beg end)
  "Return non-nil when the table at BEG..END is currently pretty."
  (cl-some (lambda (ov) (overlay-get ov 'table-pretty-display))
           (overlays-in beg end)))

(defun table-pretty--on-modify (ov _flag _beg _end &optional _length)
  "Modification hook: reveal the whole table when OV's text is edited.
This auto-removes the pretty display on any edit (org-latex-preview
style), so the user sees and edits the raw source directly — no
`read-only' (which would break undo), no blind editing."
  (let ((inhibit-modification-hooks t))
    (when-let* ((markers (overlay-get ov 'table-pretty-markers))
                (mb (marker-position (car markers)))
                (me (marker-position (cdr markers))))
      ;; Drop the markers first so a re-entrant call is a no-op.
      (overlay-put ov 'table-pretty-markers nil)
      (table-pretty--undecorate-table mb me))))

(defun table-pretty--decorate-table (beg end &optional width)
  "Create per-line display overlays for the raw table BEG..END.
WIDTH defaults to the effective width at BEG (window capacity minus
any visual indent prefix from `org-indent-mode' and friends).  The raw
buffer text is preserved; each raw line gets its own overlay whose
`display' shows the wrapped/pretty output.  Returns t when overlays
were created, nil when the table needs no change (fits, no prettify)."
  (let* ((table-beg (save-excursion (goto-char beg) (line-beginning-position)))
         (width (or width (table-pretty--effective-width-at table-beg)))
         (raw (buffer-substring-no-properties table-beg end))
         (trimmed (string-trim-right raw "\n+"))
         (trailing (substring raw (length trimmed))))
    (when-let* ((raw-lines (split-string trimmed "\n"))
                (groups (table-pretty--table-display-groups raw-lines width)))
      ;; Skip when the display is identical to the raw (fits, no prettify).
      (unless (and (= (length groups) (length raw-lines))
                   (cl-every (lambda (raw-line group)
                               (and (= (length group) 1)
                                    (equal raw-line (car group))))
                             raw-lines groups))
        (let ((n (length raw-lines))
              (beg-marker (make-marker))
              (end-marker (make-marker)))
          (set-marker beg-marker table-beg)
          (set-marker end-marker end)
          (save-excursion
            (goto-char table-beg)
            (dotimes (i n)
              (let* ((line-beg (line-beginning-position))
                     (line-end (if (= i (1- n))
                                   end
                                 (min (1+ (line-end-position)) end)))
                     (group (nth i groups))
                     (display-str (concat (mapconcat #'identity group "\n")
                                          (if (= i (1- n)) trailing "\n")))
                     (ov (make-overlay line-beg line-end nil nil nil)))
                (overlay-put ov 'display display-str)
                (overlay-put ov 'face 'default)
                (overlay-put ov 'table-pretty-display t)
                (overlay-put ov 'table-pretty-markers
                              (cons beg-marker end-marker))
                (overlay-put ov 'evaporate t)
                (overlay-put ov 'modification-hooks
                              (list #'table-pretty--on-modify))
                (overlay-put ov 'insert-in-front-hooks
                              (list #'table-pretty--on-modify))
                (overlay-put ov 'insert-behind-hooks
                              (list #'table-pretty--on-modify)))
              (forward-line 1)))
          t)))))

(defun table-pretty--decorate-tables-in-region (beg end &optional width)
  "Decorate all tables in BEG..END.
WIDTH, when non-nil, overrides the per-table effective width; otherwise
each table uses the effective width at its own position (window capacity
minus any visual indent prefix).  Idempotent: existing table overlays are
removed first."
  (let ((gc-cons-threshold (max gc-cons-threshold (* 8 1024 1024))))
    (setq table-pretty--last-width (table-pretty--window-width))
    (dolist (region (table-pretty--table-regions beg end))
      (table-pretty--undecorate-table (car region) (cdr region))
      (let* ((rb (car region))
             (re (cdr region))
             (raw (buffer-substring-no-properties rb re)))
        (when (table-pretty--parse-table (split-string (string-trim-right raw "\n+") "\n"))
          (pcase-let* ((`(,_headers ,_aligns ,rows)
                       (table-pretty--parse-table
                        (split-string (string-trim-right raw "\n+") "\n"))))
            (when rows                    ; skip header-only tables
              (table-pretty--decorate-table rb re width))))))))

;;;; Resize

(defun table-pretty--refresh-visible ()
  "Re-render all currently-pretty tables at the current window width.
Tables toggled to raw (no overlays) are left alone.  Lossless:
regenerate from canonical source."
  (let ((width (table-pretty--window-width)))
    (unless (equal width table-pretty--last-width)
      (setq table-pretty--last-width width)
      (let ((gc-cons-threshold (max gc-cons-threshold (* 8 1024 1024))))
        (save-excursion
          (goto-char (point-min))
          (while (not (eobp))
            (let ((bounds (table-pretty--table-bounds (point))))
              (if bounds
                  (progn
                    (when (table-pretty--table-pretty-p
                           (car bounds) (cdr bounds))
                      (table-pretty--undecorate-table (car bounds) (cdr bounds))
                      ;; Let decorate compute the effective width at this
                      ;; table's position (accounts for org-indent prefix).
                      (table-pretty--decorate-table (car bounds) (cdr bounds)))
                    (goto-char (cdr bounds)))
                (forward-line 1)))))))))

(defun table-pretty--schedule-refresh ()
  "Schedule a debounced `table-pretty--refresh-visible'."
  (when (and table-pretty-mode table-pretty-auto-rewrap-on-resize)
    (when table-pretty--refresh-timer
      (cancel-timer table-pretty--refresh-timer))
    (setq table-pretty--refresh-timer
          (run-with-idle-timer table-pretty-rewrap-idle-delay nil
                               (lambda ()
                                 (when (buffer-live-p (current-buffer))
                                   (with-current-buffer (current-buffer)
                                     (table-pretty--refresh-visible))))))))

;;;; Minor Mode

(defun table-pretty--maybe-default-pretty ()
  "Decorate all tables if the current major mode defaults to pretty."
  (when (and table-pretty-mode
             (memq major-mode table-pretty-default-on-major-modes))
    (table-pretty--decorate-tables-in-region (point-min) (point-max))))

;;;###autoload
(define-minor-mode table-pretty-mode
  "Toggle display-only pretty rendering of pipe tables in this buffer.
When on, tables can be toggled between a pretty view and the
canonical raw pipe text with `table-pretty-toggle'.  Resize re-renders
pretty tables losslessly (when `table-pretty-auto-rewrap-on-resize' is on).
Tables start raw unless the major mode is in
`table-pretty-default-on-major-modes'.  Editing a pretty table
auto-reveals the raw source via `modification-hooks' (the
`org-latex-preview' pattern; not `read-only', which would break undo)."
  :lighter " TblPretty"
  :group 'table-pretty
  (if table-pretty-mode
      (progn
        ;; `window-configuration-change-hook' is a normal (no-arg) hook
        ;; and is buffer-local-correct; it fires on window size changes
        ;; as well as layout changes, which is what we need for re-wrap.
        ;; NOTE: do NOT use `window-size-change-functions' here: it is an
        ;; abnormal hook called with one arg (the frame), so a no-arg
        ;; function would error (silently, via `safe-run-hooks'); and it
        ;; is global, so a buffer-local registration is unreliable.
        (add-hook 'window-configuration-change-hook #'table-pretty--schedule-refresh nil t)
        (table-pretty--maybe-default-pretty))
    (remove-hook 'window-configuration-change-hook #'table-pretty--schedule-refresh t)
    (when table-pretty--refresh-timer
      (cancel-timer table-pretty--refresh-timer)
      (setq table-pretty--refresh-timer nil))
    (table-pretty--undecorate-table (point-min) (point-max))))

;;;; Public Commands

(defun table-pretty--force (state regions)
  "Apply STATE (`pretty' or `raw') to REGIONS.
Return the number of tables actually rendered (for `pretty') or
processed (for `raw').  A `pretty' table that already fits without
prettification (`table-pretty-prettify' is nil and the table is
narrower than the window) is not rendered and is not counted, so the
returned count reflects what the user actually sees change."
  (let ((count 0))
    (dolist (r regions)
      (let ((beg (car r)) (end (cdr r)))
        (if (eq state 'pretty)
            (progn
              (table-pretty--undecorate-table beg end)
              ;; Let decorate compute the effective width at beg.
              (when (table-pretty--decorate-table beg end)
                (setq count (1+ count))))
          (table-pretty--undecorate-table beg end)
          (setq count (1+ count)))))
    count))

;;;###autoload
(defun table-pretty-toggle (&optional arg)
  "Toggle the pretty rendering of the pipe table at point, or all tables.
Mirrors `org-latex-preview':
  - Point on a table  → toggle that table.
  - Point off-table    → toggle all tables in the buffer (if any are
    pretty, make all raw; otherwise make all pretty).
  - Active region      → toggle tables overlapping the region.
  - `C-u'              → force pretty on all tables in the buffer.
  - `C-u C-u'          → force raw on all tables in the buffer."
  (interactive "P")
  (cond
   ;; C-u C-u → force raw on all.
   ((equal arg '(16))
    (let ((all (table-pretty--table-regions (point-min) (point-max))))
      (table-pretty--force 'raw all)
      (message "Tables raw (%d)" (length all))))
   ;; C-u → force pretty on all.
   ((equal arg '(4))
    (let* ((all (table-pretty--table-regions (point-min) (point-max)))
           (n (table-pretty--force 'pretty all)))
      (message "Tables pretty (%d of %d)" n (length all))))
   ;; Active region → toggle tables overlapping the region.
   ((use-region-p)
    (let* ((rb (region-beginning))
           (re (region-end))
           (regs (table-pretty--table-regions rb re))
           (any-pretty (cl-some
                        (lambda (r)
                          (table-pretty--table-pretty-p (car r) (cdr r)))
                        regs))
           (state (if any-pretty 'raw 'pretty))
           (n (table-pretty--force state regs)))
      (message "Region tables %s (%d%s)"
               (if (eq state 'raw) "raw" "pretty")
               n
               (if (eq state 'raw) "" (format " of %d" (length regs))))
      ))
   ;; No region: point on a table → toggle it; else toggle all.
   (t
    (let ((bounds (table-pretty--table-bounds (point))))
      (cond
       ((null bounds)
        (let* ((all (table-pretty--table-regions (point-min) (point-max)))
               (any-pretty (cl-some
                            (lambda (r)
                              (table-pretty--table-pretty-p (car r) (cdr r)))
                            all))
               (state (if any-pretty 'raw 'pretty))
               (n (table-pretty--force state all)))
          (message "Tables %s (%d%s)"
                   (if (eq state 'raw) "raw" "pretty")
                   n
                   (if (eq state 'raw) "" (format " of %d" (length all))))
          ))
       ((table-pretty--table-pretty-p (car bounds) (cdr bounds))
        (table-pretty--undecorate-table (car bounds) (cdr bounds))
        (message "Table raw"))
       (t
        (table-pretty--decorate-table (car bounds) (cdr bounds))
        (message "Table pretty")))))))

;;;###autoload
(defun table-pretty-buffer ()
  "Force pretty rendering on all tables in the current buffer."
  (interactive)
  (let* ((all (table-pretty--table-regions (point-min) (point-max)))
         (n (table-pretty--force 'pretty all)))
    (message "Tables pretty (%d of %d)" n (length all))))

;;;###autoload
(defun table-pretty-region (beg end)
  "Force pretty rendering on all tables in BEG..END."
  (interactive "r")
  (let* ((regs (table-pretty--table-regions beg end))
         (n (table-pretty--force 'pretty regs)))
    (message "Region tables pretty (%d of %d)" n (length regs))))

(provide 'table-pretty)
;;; table-pretty.el ends here
