;; -*- lexical-binding: t; -*-
;;; modules/sayre/quota-axi/doctor.el -*- lexical-binding: t; -*-
;;; quota-axi runs `npx -y quota-axi', which needs Node.js 22.19 or newer.

(unless (executable-find "npx")
  (warn! "npx not found on exec-path. quota-axi needs Node.js >= 22.19."))
