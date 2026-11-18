;; -*- lexical-binding: t; no-byte-compile: t; -*-
;;; modules/sayre/pilish/packages.el -*- lexical-binding: t; -*-
;;; Manifest for the locally owned Pilish development checkout (sources/pilish
;;; submodule).  Fails before package installation if the source entry file is
;;; missing, so straight never receives a misleading path.
;;;
;;; The markdown-table-wrap and md-ts-mode declarations intentionally mirror
;;; modules/sayre/table-pretty/packages.el (same pins, same recipes) so this
;;; module can be enabled without the table module; keep both in the same
;;; commit when they change.  The local recipe is an evaluated `list' so the
;;; absolute source path is a value, not a quoted symbol.

(load! "../pins")
(load! "shared")
(let ((entry (expand-file-name "pilish.el" +sayre-pilish-source-dir)))
  (unless (file-readable-p entry)
    (error "Missing Pilish source: %s. Initialize sources/pilish with git submodule update --init --recursive before doom sync"
           entry)))
(package! pilish
  :recipe (list :type nil
                :local-repo +sayre-pilish-source-dir
                :files '("pilish*.el")
                :build '(:not compile native-compile)))
(package! markdown-table-wrap
  :pin +sayre-table-engine-revision
  :recipe (:host github
           :repo "dnouri/markdown-table-wrap"
           :branch "main"
           :files (:defaults
                   (:exclude "markdown-table-wrap-pretty.el"))))
(package! md-ts-mode
  :pin +sayre-md-ts-revision
  :recipe (:host github :repo "dnouri/md-ts-mode"))
