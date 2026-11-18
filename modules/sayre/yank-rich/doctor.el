;; -*- lexical-binding: t; -*-
;;; modules/sayre/yank-rich/doctor.el -*- lexical-binding: t; -*-
;;; External-tool diagnostics for the rich/plain yank pipeline.
;;;
;;; IMPORTANT: `doom doctor' does NOT load the user's config.el, so a custom
;;; value assigned there is NOT visible to this file.  A variable is only
;;; readable here if some shared module source already bound it.  Therefore
;;; each check uses the variable's value when it is bound, and falls back to
;;; the package default otherwise — this doctor can never claim to have
;;; validated a runtime custom value it cannot see.
;;;
;;; Org rich copy deliberately takes a different path (`ox-clip' and its own
;;; platform clipboard configuration), not the RTF pipeline checked below;
;;; the presence of the ox-clip/htmlize packages is covered by doom doctor's
;;; generic missing-package check for this module.  A manual Org rich-copy
;;; test remains part of acceptance testing (plan A16).

(defconst +sayre-yank-rich-default-rtf-command
  "textutil -inputencoding UTF-8 -stdin -format html -convert rtf -stdout | pbcopy"
  "The package's default HTML→RTF clipboard pipeline (macOS textutil + pbcopy).")

;; pandoc: used for plain copy and for the markdown→HTML stage of rich copy.
(let ((pandoc (if (boundp 'yank-rich-pandoc-executable)
                  yank-rich-pandoc-executable
                ;; Unbound here ⇒ the package default applies at runtime.
                "pandoc")))
  (cond
   ((not (stringp pandoc))
    (warn! "yank-rich-pandoc-executable is not a string: %S" pandoc))
   ((not (executable-find pandoc))
    (warn! "yank-rich pandoc program is unavailable: %s (needed for plain copy and the markdown rich-copy path)"
           pandoc))))

;; RTF pipeline: validate the default textutil/pbcopy pipeline.  A custom
;; pipeline is NOT assumed to need the macOS defaults, and its shell string
;; is not parsed for executables (that would be guesswork); instead the
;; operator is asked to validate it manually.
(let ((rtf (if (boundp 'yank-rich-rtf-command)
               yank-rich-rtf-command
             +sayre-yank-rich-default-rtf-command)))
  (cond
   ((not (stringp rtf))
    (warn! "yank-rich-rtf-command is not a string: %S" rtf))
   ((string-equal rtf +sayre-yank-rich-default-rtf-command)
    (unless (executable-find "textutil")
      (warn! "Default yank-rich RTF pipeline needs `textutil' (macOS); not found on PATH"))
    (unless (executable-find "pbcopy")
      (warn! "Default yank-rich RTF pipeline needs `pbcopy' (macOS); not found on PATH")))
   (t
    (warn! "A custom yank-rich-rtf-command is configured; this doctor cannot validate a custom pipeline automatically. Verify it by hand — HTML on stdin must land RTF on the clipboard: %S"
           rtf))))
