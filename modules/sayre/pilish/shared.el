;; -*- lexical-binding: t; no-byte-compile: t; -*-
;;; modules/sayre/pilish/shared.el -*- lexical-binding: t; -*-
;;; Shared definitions for the Pilish development checkout.
;;;
;;; The absolute source directory is derived from `doom-user-dir' so the
;;; manifest (packages.el), the config, pi-reload, and diagnostics all agree
;;; on one path regardless of where the Doom configuration lives.  Loaded
;;; from config.el, packages.el, and doctor.el alike.

(defconst +sayre-pilish-source-dir
  (file-name-as-directory
   (expand-file-name "sources/pilish" doom-user-dir)))

(defconst +sayre-pilish-default-command '("pi"))
