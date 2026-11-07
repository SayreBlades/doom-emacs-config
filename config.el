;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
(setq doom-font (font-spec :family "Fira Code" :size 15 :weight 'semi-light)
      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 15)
      doom-symbol-font (font-spec :family "Apple Symbols"))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;; (setq doom-theme 'doom-earl-grey)
;;(setq doom-theme 'doom-one)
(setq doom-theme 'doom-nord-light)
;; (setq doom-theme 'doom-nord)
;; (setq doom-theme 'doom-zenburn)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; Fix org-modern fold stars: replace Level 3 chars (⯈/⯆ U+2BC8/2BC6) which
;; are missing from nearly all installed fonts, with glyphs Apple Symbols has.
(after! org-modern
  (setq org-modern-fold-stars
        '(("▶" . "▼") ("▷" . "▽") ("▸" . "▾") ("▹" . "▿") ("▸" . "▾"))))

;; ob-mermaid — org-babel execution for mermaid diagrams
;; Requires: npm install -g @mermaid-js/mermaid-cli (provides mmdc)
(after! org
  (require 'ob-mermaid)
  (setq ob-mermaid-cli-path "/opt/homebrew/bin/mmdc")
  ;; Disable org-element cache — avoids intermittent parser errors
  ;; (wrong-type-argument integer-or-marker-p nil) on large files.
  (setq org-element-use-cache nil)

  ;; Show inline images by default when opening org files.
  (setq org-startup-with-inline-images t)

  ;; Auto-fold plantuml and mermaid source blocks on file open.
  (defun +org/fold-diagram-src-blocks ()
    "Fold all plantuml/mermaid src blocks in the current buffer."
    (org-babel-map-src-blocks nil
      (let ((lang (org-element-property :language (org-element-at-point))))
        (when (member lang '("plantuml" "mermaid"))
          (org-hide-block-toggle t)))))
  (add-hook 'org-mode-hook #'+org/fold-diagram-src-blocks 'append))


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;; Remap modifier keys for macOS:
;;   - Set Command (⌘) key to function as Control key for Emacs shortcuts
;;   - Physical Control (⌃) key remains as Control key by default
;;
;; This makes common Emacs shortcuts (like C-c/C-v) accessible via Command key.
;; Uncomment the second line to make Control key function as Meta/Alt instead.
(setq
 ns-command-modifier 'control    ; Command key → Control
 ;; ns-control-modifier 'meta   ; Uncomment to make Control key → Meta
 )

;; kill evil snipe mode
(remove-hook 'doom-first-input-hook #'evil-snipe-mode)

;; Configure Evil to treat symbols as words for movement and search operations.
;;
;; This changes the behavior of:
;;   - Word movements (w, b, e) to move by symbol boundaries
;;   - Word searches (*, #) to match entire symbols
;;
;; Symbols include any non-whitespace characters (letters, numbers, underscores, etc.)
;; Example: "foo_bar" is treated as a single word rather than two separate words.
;;
;; References:
;;   https://emacs.stackexchange.com/questions/9583/how-to-treat-underscore-as-part-of-the-word
;;   :help evil-symbol-word-search
(with-eval-after-load 'evil
  ;; Alias forward-evil-word to forward-evil-symbol so word movements use symbol boundaries
  (defalias #'forward-evil-word #'forward-evil-symbol)
  ;; Enable symbol-based word searching so */# match entire symbols
  (setq-default evil-symbol-word-search t))

;; ============================================================================
;; Follow thing at point in other window: Markdown links, URLs, or file:line
;; ============================================================================
;; `S-RET' follows the thing at point:
;;   - a Markdown link `[text](url)`  → browse (external) / open file (local)
;;   - a bare URL                      → browse in browser
;;   - a file path (with optional :line or :line:col) → open in other window
;; Useful in pi chat buffers (md-ts-mode) where RET is pi's own
;; `pilish-visit-file' (strict file targets); this complements it
;; by handling external URLs and arbitrary markdown links.
;;
;; File targets navigate ONLY the other window: the current window keeps
;; its buffer, point, AND selection (`find-file-other-window' would display
;; in the other window but also SELECT it, dragging the cursor along, which
;; is why both windows appeared to "navigate").  `C-u S-RET' opts back into
;; following the cursor into the target window.
(defun +my--url-at-point ()
  "Return a URL at point, stripping surrounding Markdown emphasis.
`thing-at-point' fails to recognize a URL wrapped in emphasis markers
like **URL** (e.g. in a pi chat buffer), so when it returns nothing --
or returns the URL with stray Markdown emphasis / backticks attached -- fall back to
scanning the current line and trimming leading/trailing emphasis chars."
  (let ((url (thing-at-point 'url t)))
    (cond
     ((and url (string-match-p "\\`https?://" url))
      (string-trim url "[*_~`]+" "[*_~`]+"))
     (t
      (let ((line (buffer-substring-no-properties
                   (line-beginning-position) (line-end-position))))
        (save-match-data
          (if (string-match
               (rx "http" (? "s") "://"
                   (one-or-more (not (in " \t\r\n\f"))))
               line)
              (string-trim (match-string 0 line) "[*_~`]+" "[*_~`]+"))))))))

(defun +my--markdown-bracket-link-p ()
  "Return non-nil if point is on a genuine Markdown *bracketed* link.
Covers `[text](url)', `[text][ref]', reference-only `[ref]', and
angle-bracket `<url>'.  Deliberately EXCLUDES bare URIs:
`markdown-link-p' also matches a plain URI via `markdown-regex-uri',
whose character class `[^]\t\n\r<>; ]+' admits `*', so for
emphasis-wrapped text like `**http://host/x**' it captures the
trailing `**' and opens a bogus URL.  Bare URIs are instead handled
by `+my--url-at-point', which strips surrounding emphasis."
  (and (fboundp 'markdown-link-p)
       (boundp 'markdown-regex-link-inline)
       (save-excursion
         (or (thing-at-point-looking-at markdown-regex-link-inline)
             (thing-at-point-looking-at markdown-regex-link-reference)
             (thing-at-point-looking-at markdown-regex-angle-uri)))))

(defvar +my--target-window nil
  "Window last navigated to by `+my/find-file-at-point-other-window'.")

(defvar ffap-string-at-point-region)   ; set by `ffap-file-at-point'

(defun +my--display-in-other-window (buffer)
  "Display BUFFER in the other window WITHOUT selecting it.
Reuses the next window on the selected frame; splits the selected window
if it is the only one.  Return the window now showing BUFFER.  Unlike
`switch-to-buffer-other-window', the selected window is left alone, so
point stays where it is (this is the crux of the S-RET behavior)."
  (let ((window (next-window)))
    (if (not (eq window (selected-window)))
        (if (window-dedicated-p window)
            ;; Dedicated windows (side windows, popups) refuse a plain
            ;; `set-window-buffer'; let `display-buffer' find another home.
            (display-buffer buffer '((display-buffer-pop-up-window
                                      display-buffer-use-some-window)
                                     (inhibit-same-window . t)))
          (set-window-buffer window buffer)
          window)
      ;; Single window: pop a new one up on the right.
      (setq window (split-window-right))
      (set-window-buffer window buffer)
      window)))

(defun +my/find-file-at-point-with-line ()
  "Open the file at point in the other window, keeping point where it is.
Supports positions in the formats `path:line', `path:line:col',
`path(line)' and `path(line,col)', mirroring
`evil-find-file-at-point-with-line' -- but jumps to the line/column in the
TARGET window instead of the current buffer.  Must run inside
`+my/find-file-at-point-other-window', whose `find-file' redirect records
the target window in `+my--target-window' (we can't reuse evil's command
directly: with focus left in the chat window, its post-`find-file' goto
would run in the CHAT buffer and stomp the chat's point)."
  (require 'ffap)
  (let ((fname (ffap-file-at-point)))
    (unless fname
      (user-error "File does not exist."))
    (let* (;; Same `ffap-string-at-point-region' trick evil uses: after the
           ;; file name, look for trailing line/column specs around it.
           (get-number
            (lambda (pattern match-number backward)
              (save-excursion
                (goto-char (cadr ffap-string-at-point-region))
                (and (if backward
                         (re-search-backward pattern (line-beginning-position) t)
                       (re-search-forward pattern (line-end-position) t))
                     (string-to-number (match-string match-number))))))
           (line (or (funcall get-number ":\\([0-9]+\\):\\([0-9]+\\)\\=" 1 t)
                     (funcall get-number "\\=(\\([0-9]+\\),\\([0-9]+\\))" 1 nil)
                     (funcall get-number ":\\([0-9]+\\)\\=" 1 t)
                     (funcall get-number "\\=(\\([0-9]+\\))" 1 nil)))
           (column (or (funcall get-number ":\\([0-9]+\\):\\([0-9]+\\)\\=" 2 t)
                       (funcall get-number "\\=(\\([0-9]+\\),\\([0-9]+\\))" 2 nil))))
      (find-file fname)          ; redirected below: other window, no select
      (when +my--target-window
        ;; Jump to line/column inside the target window itself; the current
        ;; window's point is untouched.
        (with-selected-window +my--target-window
          (goto-char (point-min))
          (when line (forward-line (1- line)))
          (when column (move-to-column (1- column)))
          ;; Redisplay doesn't auto-scroll unselected windows whose point
          ;; moved out of view, so scroll explicitly when needed.
          (unless (pos-visible-in-window-p (point) nil t)
            (recenter)))))))

(defun +my/find-file-at-point-other-window (&optional focus)
  "Follow the thing at point, navigating ONLY the other window.
If point is on a Markdown link, follow it (browse external URLs, open
local files).  If on a bare URL, browse it.  Otherwise treat it as a
file path (with optional `:line' or `:line:col') and open it in the
other window, jumping to the line.  The current window keeps its buffer,
point, and selection; with prefix FOCUS (`C-u S-RET'), also select the
target window, following the cursor into it like the old behavior."
  (interactive "P")
  ;; markdown-mode.el is NOT autoloaded for `markdown-link-p' /
  ;; `markdown-follow-link-at-point'; require it so links work even
  ;; before any `markdown-mode' buffer has been opened.
  (require 'markdown-mode nil t)
  (setq +my--target-window nil)
  ;; Redirect every local-file open to the other window WITHOUT selecting
  ;; it, so S-RET neither clobbers the current buffer (e.g. a pi chat
  ;; buffer) nor drags the cursor out of it.  Use `defun!' (cl-letf on the
  ;; function cell), NOT `defun' (cl-flet, lexical): both
  ;; `markdown--browse-url' (local Markdown links) and ffap (plain paths,
  ;; via `ffap-file-finder') reach `find-file' through its function cell,
  ;; which a lexical cl-flet can't intercept; the cl-letf binding can.
  ;; External URLs go through `browse-url' and are unaffected.
  ;; `find-file-noselect' is not redirected, so there's no recursion.
  (letf! ((defun! find-file (filename &optional wildcards)
            (let ((buffer (find-file-noselect filename nil nil wildcards)))
              (setq +my--target-window (+my--display-in-other-window buffer))
              buffer)))
    (let ((url (+my--url-at-point)))
      (cond
       ;; Genuine Markdown bracket/angle link (`[t](u)', `[ref]', `<uri>'):
       ;; delegate -- markdown's own parsing is authoritative here, and the
       ;; emphasis-stripping in `url' is unnecessary.  Bare URIs do NOT go
       ;; through this branch (see `+my--markdown-bracket-link-p').
       ((+my--markdown-bracket-link-p)
        (markdown-follow-link-at-point))
       ;; Plain URL (incl. one wrapped in Markdown emphasis like **url**,
       ;; which `thing-at-point' / `markdown-link-p' would otherwise capture
       ;; raw).  `+my--url-at-point' has already stripped the emphasis.
       (url
        (browse-url url))
       ;; File path (with optional :line / :line:col)
       (t
        (+my/find-file-at-point-with-line))))
    ;; `C-u S-RET': opt back into following the cursor into the target.
    (when (and focus +my--target-window)
      (select-window +my--target-window))))

;; Bind S-RET globally to this function.
(map! "S-<return>" #'+my/find-file-at-point-other-window)

;; vterm captures all keys; re-bind S-RET there too.
(after! vterm
  (map! :map vterm-mode-map
        "S-<return>" #'+my/find-file-at-point-other-window))


;; dired-mode configs
;;
;; turn off dired-omit-mode by default, to display '.' and '..' files
;; https://emacs.stackexchange.com/questions/51046/how-to-use-recover-session-and-dired-omit-mode-in-emacs-26-and-lower
;; https://github.com/doomemacs/doomemacs/issues/1568
(remove-hook 'dired-mode-hook #'dired-omit-mode)
(after! dired
  (setq insert-directory-program "gls"
        dired-listing-switches "-Al --group-directories-first"))

(after! dirvish
  ;; Indent expanded subdirectories (TAB) more visibly.
  ;; The prefix is repeated once per nesting depth, using spaces only.
  (setq dirvish-subtree-prefix "   │  "))

;; turn off the "really quit emacs" prompt when closing emacs
(setq confirm-kill-emacs nil)

;; remove compile output from popups (SPC c c) -> use full window instead
;;
;; NOTE: deliberately NOT wrapped in `(after! popup ...)'.  In this Doom
;; version (doom+ / v3 core) the :ui popup module is `doom-load'ed as a plain
;; file and never `(provide 'popup)'s, so an `after! popup' block silently
;; never runs -- these :ignore rules were dead code until now.  $DOOMDIR's
;; config.el is loaded after all module configs, so top-level calls land
;; after the popup module's own rules (and take precedence, since
;; `set-popup-rule!' pushes to the front of `+popup--display-buffer-alist').
(when (modulep! :ui popup)
  (set-popup-rule! "^\\*compilation\\*" :ignore t)
  (set-popup-rule! "^\\*vterm\\*" :ignore t)
  (set-popup-rule! "^\\*PLANTUML" :ignore t))

;; switch-to-buffer / persp-switch-to-buffer (SPC < and SPC ,): never popups.
;; The chosen buffer should behave like find-file: take over the current
;; window.  Two things defeat that:
;;   1. A popup rule matching the buffer's name captures it into a side
;;      window via the display-buffer machinery.
;;   2. A buffer last seen in a popup still carries buffer-local
;;      `+popup-buffer-mode' (hidden modeline, q/C-g close it), so it keeps
;;      "popup mode" even in a normal window.
;; Voiding `display-buffer-alist' for the duration is the same trick
;; `+popup/raise' uses; advising `switch-to-buffer' alone covers both
;; commands because `persp-switch-to-buffer' calls it internally.
(defun my/switch-to-buffer-no-popup-a (fn &rest args)
  "Call switch-buffer command FN with Doom's popup system neutralized.
The target buffer displays in the current window rather than a popup
side window, and any lingering `+popup-buffer-mode' is cleared from it
afterwards.

Also never land the buffer in a dedicated helper window (Doom popup
windows, pilish's input window, which is soft-dedicated to 'side).
When switching from one, first select the largest regular window so
the chosen buffer gets a full window."
  (unless (window-minibuffer-p)
    (when (window-dedicated-p (selected-window))
      (when-let* ((better
                   (car (cl-sort
                         (cl-remove-if
                          (lambda (w) (or (window-dedicated-p w)
                                          (window-minibuffer-p w)))
                          (window-list (selected-frame)))
                         #'> :key (lambda (w) (* (window-total-width w)
                                                 (window-total-height w)))))))
        (select-window better))))
  (let (display-buffer-alist)
    (apply fn args))
  ;; Only demote buffers not actually sitting in a popup window (so popup
  ;; restores/workspace loads are unaffected).
  (when (and (bound-and-true-p +popup-buffer-mode)
             (not (+popup-window-p)))
    (+popup-buffer-mode -1)))

;; NOT `(after! popup ...)': as noted above, the popup module never provides
;; the `popup' feature in this Doom version, so that block never fires (only
;; the unrelated MELPA `popup.el' package provides it).  config.el already
;; loads after the popup module, so register the advice at top level.
(when (modulep! :ui popup)
  (advice-add #'switch-to-buffer :around #'my/switch-to-buffer-no-popup-a))

;; find-file / buffer-switch pickers as full windows (ivy-style), not the
;; small minibuffer strip at the bottom.  vertico-multiform switches just
;; these commands to vertico-buffer-mode, and the candidates buffer is
;; displayed in the selected window; the prompt is drawn inside it
;; (`vertico-buffer-hide-prompt' defaults to t).  Picking or aborting
;; restores the window, then the chosen file/buffer takes it over.
;;
;; NOTE: the `switch-to-buffer'/`persp-switch-to-buffer' entries only apply
;; when those commands run directly.  Doom's vertico module REMAPS them
;; (SPC < actually runs `consult-buffer', SPC , runs
;; `+vertico/switch-workspace-buffer'), so those real commands must be
;; registered too.
(after! vertico
  (require 'vertico-buffer)
  (setq vertico-buffer-display-action '(display-buffer-same-window))
  (dolist (cmd '(find-file projectile-find-file
                 switch-to-buffer persp-switch-to-buffer
                 consult-buffer consult-buffer-other-window
                 +vertico/switch-workspace-buffer))
    (add-to-list 'vertico-multiform-commands (list cmd 'buffer))))

;; associate .puml files with plantuml-mode
(add-to-list 'auto-mode-alist '("\\.puml\\'" . plantuml-mode))

;; maximize emacs on startup
(add-to-list 'initial-frame-alist '(fullscreen . maximized))

;; ============================================================================
;; yank-rich: multi-format yank — rich (RTF), plain (stripped)
;; Visual select text, then `gy r` for rich or `gy p` for plain.
;; Normal `y`/`Y` are undisturbed (raw markdown / default yank).
;; ============================================================================
(use-package! yank-rich
  :load-path "~/.config/doom/site-lisp"
  :commands (yank-rich yank-plain)
  :init
  ;; `gy` prefix with which-key labels; works as evil operators (visual + motions)
  (map! :nv "gy" nil)  ; clear Doom's default gy (yank-unindented)
  (map! :nv "gyr" #'yank-rich
        :nv "gyp" #'yank-plain)
  (which-key-add-key-based-replacements
    "gy"  "yank-as…"
    "gyr" "rich (RTF)"
    "gyp" "plain (stripped)"))

;; ============================================================================
;; markdown-table-wrap-pretty — display-only pretty rendering of pipe tables
;; with toggle (markdown / gfm / md-ts / org).  Display companion shipped in
;; the vendored markdown-table-wrap submodule (branch feat/pretty-display).
;; Mirrors `org-latex-preview': canonical buffer text stays valid; a display
;; overlay renders a wrapped, box-drawing view; toggle reveals raw to edit.
;; ============================================================================
(use-package! table-pretty
  ;; Local display companion — lives alongside the vendored
  ;; markdown-table-wrap engine that it depends on.
  :load-path ("~/.config/doom/site-lisp" "~/.config/doom/site-lisp/markdown-table-wrap")
  :demand t
  :init
  ;; pi chat buffers derive from md-ts-mode but have their own overlay
  ;; system (pilish-table.el); don't let this shadow it.
  ;; The chat toggle is handled by the dispatch wrapper below.
  (defun my/table-pretty-maybe-enable ()
    "Enable `table-pretty-mode' unless in a pi chat buffer."
    (unless (derived-mode-p 'pilish-chat-mode)
      (table-pretty-mode 1)))
  :hook (markdown-mode . table-pretty-mode)
  :hook (md-ts-mode    . my/table-pretty-maybe-enable)
  :hook (org-mode      . table-pretty-mode)
  :config
  ;; Default tables to pretty on buffer open in markdown + org.
  (setq table-pretty-default-on-major-modes
        '(markdown-mode gfm-mode org-mode md-ts-mode))
  ;; Keep pi chat tables styled consistently: plug the centralized inline-
  ;; span styler into pi's cell-render hook (one-way opt-in; pi itself
  ;; never references this package).  table-pretty.el does this
  ;; automatically via `with-eval-after-load', but be explicit here.
  (with-eval-after-load 'pilish-table
    (when (boundp 'pilish-table-cell-render-function)
      (setq pilish-table-cell-render-function
            #'table-pretty-render-inline-spans))))

;; Dispatch wrapper: in pi chat, delegate to pi's own toggle (which uses
;; pi's tree-sitter detection + overlay system); elsewhere, use
;; `markdown-table-wrap-pretty-toggle'.  Defined at top level (not inside a
;; `use-package' :config) so it is always available regardless of load
;; order between markdown-table-wrap-pretty and pi.
(defun my/table-pretty-toggle (&optional arg)
  "Toggle pretty table rendering, dispatching by major mode.
In `pilish-chat-mode', use pi's own
\[pilish-toggle-table-pretty] (pi's tree-sitter detection +
overlay system).  Otherwise use `table-pretty-toggle'.
ARG is the prefix arg: `C-u' forces pretty on all, `C-u C-u' forces raw."
  (interactive "P")
  (if (derived-mode-p 'pilish-chat-mode)
      (pilish-toggle-table-pretty arg)
    (table-pretty-toggle arg)))

;; One consistent cross-mode doom key: SPC t t (point-aware toggle).
(map! :leader :prefix "t"
      :desc "Table pretty"  "t" #'my/table-pretty-toggle)

;; Per-mode local-leader aliases (which-key bonuses):
(map! :after markdown-mode :map markdown-mode-map :localleader
      (:prefix ("t" . "toggle")
       :desc "Table pretty"  "t" #'my/table-pretty-toggle))
(map! :after org :map org-mode-map :localleader
      (:prefix ("b" . "tables")
               (:prefix ("t" . "toggle")
                :desc "Pretty"  "t" #'my/table-pretty-toggle)))

;; Vanilla key (documented recommendation; free in both org + markdown):
(map! :after markdown-mode :map markdown-mode-map "C-c C-x C-k" #'my/table-pretty-toggle)
(map! :after org           :map org-mode-map       "C-c C-x C-k" #'my/table-pretty-toggle)
;; Chat (pi): same vanilla key via the dispatch wrapper.  `pilish-chat-mode-map'
;; is defined when `pilish-ui' loads.
(map! :after pilish :map pilish-chat-mode-map
      "C-c C-x C-k" #'my/table-pretty-toggle)

;; ============================================================================
;; pilish.el - Emacs frontend for pi coding agent
;; ============================================================================
(use-package! pilish
  ;; Local development copy of Pilish lives in site-lisp
  :load-path "~/.config/doom/site-lisp/pilish"
  ;; Defer loading until the `pilish' command is invoked
  :commands (pilish)
  :init
  ;; Bind SPC o p to launch the pi coding agent
  (map! :leader
        :desc "Pi coding agent" "o p" #'pilish)
  ;; Copy messages as raw markdown instead of rendered text
  (setq pilish-copy-raw-markdown t)
  ;; Start the input buffer in evil normal state
  (setq pilish-evil-input-state 'normal)
  ;; Launch sessions chat-only and hide the input after each send;
  ;; reopen it with `i'/`a' (Evil) or M-x pilish-open-input.
  ;; This subsumes the old `my/pi-send-close-input' advice.
  (setq pilish-input-window-display 'hidden)
  ;; --- omp backend trial (Phase 0, see .scratch/PILISH-OMP-PLAN.md) ---
  ;; omp has no --approve/--no-approve flags; pi's flag would kill the
  ;; process at startup (exit 2).  `default' passes no trust flag.
  ;; NOTE: omp has no project-trust gate at all - project-local omp
  ;; resources are always active (behavioral difference vs pi --approve).
  (setq pilish-project-trust-policy 'default)
  ;; Use omp ("Oh My Pi", a pi-lineage fork) as the RPC backend.
  ;; Known gaps on omp: model picker (C-c C-m) fails, slash-command menu
  ;; empty, fork unsupported, session browser needs Phase 1 root fix.
  ;;(setq pilish-executable '("omp"))
  (setq pilish-executable '("pi"))
  :config
  ;; Mark only the chat buffer as "real" so Doom treats it like a
  ;; regular file buffer.  Leave the input buffer non-real (Doom's
  ;; default) so it behaves like an ephemeral/popup pane.
  (add-hook 'pilish-chat-mode-hook (lambda () (setq doom-real-buffer-p t)))
  ;; Disable line numbers in chat and input buffers
  (add-hook 'pilish-chat-mode-hook
            (lambda () (display-line-numbers-mode -1)))
  (add-hook 'pilish-input-mode-hook
            (lambda () (display-line-numbers-mode -1)))
  ;; Show the agent's status header line in chat buffers
  (add-hook 'pilish-chat-mode-hook
            (lambda () (setq-local header-line-format
                                   '(:eval (pilish--header-line-string))))))

(defun pi-reload ()
  "Reload all pilish modules from development directory."
  (interactive)
  (let ((dir "~/.config/doom/site-lisp/pilish/"))
    (dolist (mod '("pilish-core"
                   "pilish-grammars"
                   "pilish-ui"
                   "pilish-table"
                   "pilish-render"
                   "pilish-input"
                   "pilish-menu"
                   "pilish"
                   "pilish-evil"))
      (load (expand-file-name mod dir) nil t)))
  (message "Pi reloaded (all modules)"))

(defun my/pilish-toggle-backend (&optional arg)
  "Toggle the pilish RPC backend between omp and pi.
With prefix ARG, force pi.  New sessions pick up the change; running
sessions keep their current process.  See .scratch/PILISH-OMP-PLAN.md."
  (interactive "P")
  (setq pilish-executable
        (if arg '("pi")
          (if (equal (car pilish-executable) "omp") '("pi") '("omp"))))
  ;; pi supports --approve, omp does not; keep the policy compatible
  ;; with whichever backend is active.
  (setq pilish-project-trust-policy
        (if (equal (car pilish-executable) "omp") 'default 'approve))
  (message "pilish backend: %s (trust policy: %s)"
           (car pilish-executable) pilish-project-trust-policy))

;; ============================================================================
;; vterm: SPC o T reuses an existing undisplayed vterm buffer
;; ============================================================================
;; Everything here is default Doom behavior, except: `+vterm/here' (SPC o T)
;; normally spawns a brand-new vterm every time.  Instead, if a full (non-popup)
;; vterm buffer already exists but isn't displayed in any window, switch to it.

(defun my/vterm-here (&optional arg)
  "Like `+vterm/here', but reuse an existing undisplayed vterm buffer.

With no prefix ARG: if a vterm buffer (created by SPC o T, i.e. not a
SPC o t popup) exists and no window is displaying it, switch to it in
the current window.  Otherwise, exactly `+vterm/here' behavior."
  (interactive "P")
  (if-let* ((buf (and (not arg)
                      (cl-loop for buf in (doom-buffers-in-mode 'vterm-mode)
                               unless (string-prefix-p "*doom:" (buffer-name buf))
                               unless (get-buffer-window-list buf nil t)
                               return buf))))
      ;; `display-buffer-alist' must be nil'd, else Doom's "^\*vterm" popup
      ;; rule hijacks the buffer into a side window (same trick +vterm/here
      ;; uses internally).
      (let (display-buffer-alist)
        (pop-to-buffer-same-window buf))
    (call-interactively #'+vterm/here)))

(map! :leader
      :desc "Open vterm here (reuse if hidden)" "oT" #'my/vterm-here)
