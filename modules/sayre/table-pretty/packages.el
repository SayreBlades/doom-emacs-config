;; -*- lexical-binding: t; no-byte-compile: t; -*-
;;; modules/sayre/table-pretty/packages.el -*- lexical-binding: t; -*-
;;; Pretty table rendering.  table-pretty shares the emacs-world checkout
;;; with yank-rich (same +sayre-emacs-world-revision, see pins.el); it owns
;;; the markdown-table-wrap engine and md-ts-mode recipes.  Pilish's
;;; manifest duplicates those two declarations intentionally — change both
;;; in the same commit.

(load! "../pins")
(package! table-pretty
  :pin +sayre-emacs-world-revision
  :recipe (:host github
           :repo "SayreBlades/emacs-world"
           :protocol ssh
           :local-repo "emacs-world"
           :files ("table-pretty/*.el")))
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
