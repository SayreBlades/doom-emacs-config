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
;; `pi-coding-agent-visit-file' (strict file targets); this complements it
;; by handling external URLs and arbitrary markdown links.
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

(defun +my/find-file-at-point-other-window ()
  "Follow the thing at point, opening files in the other window.
If point is on a Markdown link, follow it (browse external URLs, open
local files).  If on a bare URL, browse it.  Otherwise treat it as a
file path (with optional `:line' or `:line:col') and open it in the
other window, jumping to the line."
  (interactive)
  ;; markdown-mode.el is NOT autoloaded for `markdown-link-p' /
  ;; `markdown-follow-link-at-point'; require it so links work even
  ;; before any `markdown-mode' buffer has been opened.
  (require 'markdown-mode nil t)
  ;; Redirect every local-file open to the other window so S-RET never
  ;; clobbers the current buffer (e.g. a pi chat buffer).  Use `defun!'
  ;; (cl-letf on the function cell), NOT `defun' (cl-flet, lexical):
  ;; both `markdown--browse-url' (local Markdown links) and
  ;; `evil-find-file-at-point-with-line' (ffap, plain paths) reach
  ;; `find-file' via (funcall ffap-file-finder ...), which a lexical
  ;; cl-flet can't intercept; the cl-letf binding can.  External URLs go
  ;; through `browse-url' and are unaffected.  `find-file-other-window'
  ;; calls `find-file-noselect' (not `find-file'), so there's no recursion.
  (letf! ((defun! find-file (filename &optional wildcards)
            (find-file-other-window filename wildcards)))
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
        (evil-find-file-at-point-with-line))))))

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
(after! popup
  (set-popup-rule! "^\\*compilation\\*" :ignore t)
  (set-popup-rule! "^\\*vterm\\*" :ignore t)
  (set-popup-rule! "^\\*PLANTUML" :ignore t))

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
  ;; system (pi-coding-agent-table.el); don't let this shadow it.
  ;; The chat toggle is handled by the dispatch wrapper below.
  (defun my/table-pretty-maybe-enable ()
    "Enable `table-pretty-mode' unless in a pi chat buffer."
    (unless (derived-mode-p 'pi-coding-agent-chat-mode)
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
  (with-eval-after-load 'pi-coding-agent-table
    (when (boundp 'pi-coding-agent-table-cell-render-function)
      (setq pi-coding-agent-table-cell-render-function
            #'table-pretty-render-inline-spans))))

;; Dispatch wrapper: in pi chat, delegate to pi's own toggle (which uses
;; pi's tree-sitter detection + overlay system); elsewhere, use
;; `markdown-table-wrap-pretty-toggle'.  Defined at top level (not inside a
;; `use-package' :config) so it is always available regardless of load
;; order between markdown-table-wrap-pretty and pi.
(defun my/table-pretty-toggle (&optional arg)
  "Toggle pretty table rendering, dispatching by major mode.
In `pi-coding-agent-chat-mode', use pi's own
\[pi-coding-agent-toggle-table-pretty] (pi's tree-sitter detection +
overlay system).  Otherwise use `table-pretty-toggle'.
ARG is the prefix arg: `C-u' forces pretty on all, `C-u C-u' forces raw."
  (interactive "P")
  (if (derived-mode-p 'pi-coding-agent-chat-mode)
      (pi-coding-agent-toggle-table-pretty arg)
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
;; Chat (pi): same vanilla key via the dispatch wrapper.  `pi-coding-agent-chat-mode-map'
;; is defined when `pi-coding-agent-ui' loads.
(map! :after pi-coding-agent :map pi-coding-agent-chat-mode-map
      "C-c C-x C-k" #'my/table-pretty-toggle)

;; ============================================================================
;; pi-coding-agent.el - Emacs frontend for pi coding agent
;; ============================================================================
(use-package! pi-coding-agent
  ;; Local development copy of pi.el lives in site-lisp
  :load-path "~/.config/doom/site-lisp/pi.el"
  ;; Defer loading until the `pi-coding-agent' command is invoked
  :commands (pi-coding-agent)
  :init
  ;; Bind SPC o p to launch the pi coding agent
  (map! :leader
        :desc "Pi coding agent" "o p" #'pi-coding-agent)
  ;; Copy messages as raw markdown instead of rendered text
  (setq pi-coding-agent-copy-raw-markdown t)
  ;; Start the input buffer in evil normal state
  (setq pi-coding-agent-evil-input-state 'normal)
  ;; Launch sessions chat-only and hide the input after each send;
  ;; reopen it with `i'/`a' (Evil) or M-x pi-coding-agent-open-input.
  ;; This subsumes the old `my/pi-send-close-input' advice.
  (setq pi-coding-agent-input-window-display 'hidden)
  :config
  ;; Mark only the chat buffer as "real" so Doom treats it like a
  ;; regular file buffer.  Leave the input buffer non-real (Doom's
  ;; default) so it behaves like an ephemeral/popup pane.
  (add-hook 'pi-coding-agent-chat-mode-hook (lambda () (setq doom-real-buffer-p t)))
  ;; Disable line numbers in chat and input buffers
  (add-hook 'pi-coding-agent-chat-mode-hook
            (lambda () (display-line-numbers-mode -1)))
  (add-hook 'pi-coding-agent-input-mode-hook
            (lambda () (display-line-numbers-mode -1)))
  ;; Show the agent's status header line in chat buffers
  (add-hook 'pi-coding-agent-chat-mode-hook
            (lambda () (setq-local header-line-format
                                   '(:eval (pi-coding-agent--header-line-string))))))

(defun pi-reload ()
  "Reload all pi-coding-agent modules from development directory."
  (interactive)
  (let ((dir "~/.config/doom/site-lisp/pi.el/"))
    (dolist (mod '("pi-coding-agent-core"
                   "pi-coding-agent-grammars"
                   "pi-coding-agent-ui"
                   "pi-coding-agent-table"
                   "pi-coding-agent-render"
                   "pi-coding-agent-input"
                   "pi-coding-agent-menu"
                   "pi-coding-agent"
                   "pi-coding-agent-evil"))
      (load (expand-file-name mod dir) nil t)))
  (message "Pi reloaded (all modules)"))
