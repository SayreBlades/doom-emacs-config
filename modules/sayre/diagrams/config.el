;; -*- lexical-binding: t; -*-
;;; modules/sayre/diagrams/config.el -*- lexical-binding: t; -*-
;;; Diagram-specific settings moved from the root config.el.  General Org
;;; preferences (`org-element-use-cache' nil, `org-startup-with-inline-images'
;;; t) deliberately stay in the root config — they must not depend on this
;;; module being enabled.  This module expects :lang org and :lang plantuml
;;; to stay enabled (doctor.el warns if they are not).

(load! "shared")

;; ob-mermaid — org-babel execution for mermaid diagrams, via the exact
;; configured executable (shared.el), not a PATH-dependent name.
(after! org
  (require 'ob-mermaid)
  (setq ob-mermaid-cli-path +sayre-mermaid-command)

  ;; Auto-fold plantuml and mermaid source blocks on file open.
  (defun +org/fold-diagram-src-blocks ()
    "Fold all plantuml/mermaid src blocks in the current buffer."
    (org-babel-map-src-blocks nil
      (let ((lang (org-element-property :language (org-element-at-point))))
        (when (member lang '("plantuml" "mermaid"))
          (org-hide-block-toggle t)))))
  (add-hook 'org-mode-hook #'+org/fold-diagram-src-blocks 'append))

;; associate .puml files with plantuml-mode
(add-to-list 'auto-mode-alist '("\\.puml\\'" . plantuml-mode))

;; remove PLANTUML output from popups -> use full window instead
;;
;; NOTE: deliberately NOT wrapped in `(after! popup ...)'.  In this Doom
;; version (doom+ / v3 core) the :ui popup module is `doom-load'ed as a plain
;; file and never `(provide 'popup)'s, so an `after! popup' block silently
;; never runs.  The companion vterm exception lives in
;; modules/sayre/vterm/config.el.
(when (modulep! :ui popup)
  (set-popup-rule! "^\\*PLANTUML" :ignore t))
