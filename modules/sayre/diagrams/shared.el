;; -*- lexical-binding: t; no-byte-compile: t; -*-
;;; modules/sayre/diagrams/shared.el -*- lexical-binding: t; -*-
;;; Single source of truth for the Mermaid executable.
;;;
;;; This is the currently configured absolute executable, not a PATH lookup
;;; result — runtime and doctor must agree on the exact program.  If the
;;; executable ever changes, change this one setting; nothing else references
;;; a Mermaid command.

(defconst +sayre-mermaid-command "/opt/homebrew/bin/mmdc")
