;; -*- lexical-binding: t; -*-
;;; modules/sayre/yank-rich/config.el -*- lexical-binding: t; -*-
;;; Rich/plain yank bindings.
;;;
;;; The core `yank-rich' package stays load-order independent: its region
;;; commands (`yank-rich-rich'/`yank-rich-plain') are available through
;;; normal package autoloads without Evil.  The Evil operators live in the
;;; optional `yank-rich-evil' adapter, which this module requires explicitly
;;; after Evil so both operators are ready right after Doom/Evil setup.
;;; A vanilla Evil user opts in with:
;;;
;;;   (with-eval-after-load 'evil (require 'yank-rich-evil))
;;;
;;; Preserve the existing Unicode ellipsis in the which-key label ("yank-as…").

(when (modulep! :editor evil)
  (after! evil
    (require 'yank-rich-evil)
    (map! :nv "gy" nil)
    (map! :nv "gyr" #'yank-rich
          :nv "gyp" #'yank-plain)
    (which-key-add-key-based-replacements
      "gy"  "yank-as…"
      "gyr" "rich (RTF)"
      "gyp" "plain (stripped)")))
