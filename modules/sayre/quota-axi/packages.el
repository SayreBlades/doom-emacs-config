;; -*- lexical-binding: t; no-byte-compile: t; -*-
;;; modules/sayre/quota-axi/packages.el -*- lexical-binding: t; -*-
;;; quota-axi shares the emacs-world checkout with yank-rich and
;;; table-pretty (same +sayre-emacs-world-revision, see pins.el).
;;; transient comes with Magit, which Doom enables by default.

(load! "../pins")
(package! quota-axi
  :pin +sayre-emacs-world-revision
  :recipe (:host github
           :repo "SayreBlades/emacs-world"
           :protocol ssh
           :local-repo "emacs-world"
           :files ("quota-axi/*.el")))
