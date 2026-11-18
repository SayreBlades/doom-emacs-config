;; -*- lexical-binding: t; -*-
;;; modules/sayre/diagrams/doctor.el -*- lexical-binding: t; -*-
;;; Diagnose the exact executable the runtime will use (shared.el), not a
;;; different PATH result.  If the executable changes later, shared.el is
;;; the single place to update.

(load! "shared")
(unless (file-executable-p +sayre-mermaid-command)
  (warn! "Configured Mermaid executable is unavailable: %s"
         +sayre-mermaid-command))
(unless (and (modulep! :lang org) (modulep! :lang plantuml))
  (warn! "The personal diagrams module expects :lang org and :lang plantuml."))
