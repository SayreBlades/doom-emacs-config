;; -*- no-byte-compile: t; -*-
;;; modules/sayre/yank-rich/packages.el -*- lexical-binding: t; -*-
;;; Personal rich/plain yank module.  yank-rich and table-pretty share one
;;; checkout (SayreBlades/emacs-world), pinned by modules/sayre/pins.el —
;;; both packages must always reference the same +sayre-emacs-world-revision.

(load! "../pins")
(package! yank-rich
  :pin +sayre-emacs-world-revision
  :recipe (:host github
           :repo "SayreBlades/emacs-world"
           :protocol ssh
           :local-repo "emacs-world"
           :files ("yank-rich/*.el")))
(package! htmlize)
(package! ox-clip)
