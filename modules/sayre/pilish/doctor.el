;; -*- lexical-binding: t; -*-
;;; modules/sayre/pilish/doctor.el -*- lexical-binding: t; -*-
;;; Diagnose the Pilish development checkout and the selected backend.
;;;
;;; `doom doctor' does not load the user's config.el, so a custom
;;; `pilish-executable' assigned there is invisible to this file; when the
;;; variable is unbound here, the shared default is what actually applies.

(load! "shared")
(unless (file-readable-p
         (expand-file-name "pilish.el" +sayre-pilish-source-dir))
  (warn! "Missing Pilish checkout at %s; initialize submodules before sync."
         +sayre-pilish-source-dir))
(let* ((command (if (boundp 'pilish-executable)
                    pilish-executable
                  +sayre-pilish-default-command))
       (program (car-safe command)))
  (cond
   ((not (and (stringp program) (> (length program) 0)))
    (warn! "Invalid configured pilish-executable: %S" command))
   ((not (executable-find program))
    (warn! "Selected Pilish backend is unavailable: %S. An alternate backend does not satisfy this configuration."
           command))))
