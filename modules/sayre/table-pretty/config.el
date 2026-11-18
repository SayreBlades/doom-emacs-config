;; -*- lexical-binding: t; -*-
;;; modules/sayre/table-pretty/config.el -*- lexical-binding: t; -*-
;;; Complete table block moved from the root config.el.  Only stale
;;; commentary was corrected (the engine is no longer a vendored submodule
;;; and the dispatch no longer references markdown-table-wrap-pretty);
;;; rendering logic, hooks, defaults, and all SIX `map!' forms are unchanged.

;; ============================================================================
;; table-pretty — display-only pretty rendering of pipe tables with toggle
;; (markdown / gfm / md-ts / org).  Installed from the pinned
;; SayreBlades/emacs-world checkout (see packages.el).  Its rendering engine
;; is the pinned markdown-table-wrap straight package (dnouri/markdown-table-wrap,
;; branch main; the local display fix is included in the pinned revision),
;; and the recipe deliberately excludes upstream's `markdown-table-wrap-pretty'
;; renderer — this package replaces it.
;; Mirrors `org-latex-preview': canonical buffer text stays valid; a display
;; overlay renders a wrapped, box-drawing view; toggle reveals raw to edit.
;; ============================================================================
(use-package! table-pretty
  ;; Provided by the pinned emacs-world checkout declared in packages.el;
  ;; no :load-path needed.
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
;; `table-pretty-toggle'.  Defined at top level (not inside a
;; `use-package' :config) so it is always available regardless of load
;; order between table-pretty and pilish.
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
