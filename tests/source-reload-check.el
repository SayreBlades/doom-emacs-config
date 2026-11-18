;;; source-reload-check.el --- Cold source-only Pilish reload probe -*- lexical-binding: t; -*-

;; Run in emacs -Q --batch with Pilish's declared dependency dirs on load-path,
;; but WITHOUT requiring Pilish first. Never modifies the checkout or bytecode.
(require 'cl-lib)
(defvar doom-user-dir
  (file-name-as-directory
   (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name)))))
(load (expand-file-name "modules/sayre/pilish/shared.el" doom-user-dir) nil t t)
(with-temp-buffer
  (insert-file-contents (expand-file-name "modules/sayre/pilish/config.el" doom-user-dir))
  (goto-char (point-min))
  (catch 'found
    (while (< (point) (point-max))
      (let ((form (read (current-buffer))))
        (when (and (eq (car-safe form) 'defun) (eq (cadr form) 'pi-reload))
          (eval form t)
          (throw 'found t))))))
(cl-assert (not (featurep 'pilish)))
(pi-reload)
(cl-assert (featurep 'pilish))
(cl-assert (equal (symbol-file 'pilish 'defun)
                  (expand-file-name "pilish.el" +sayre-pilish-source-dir)))
(dolist (entry load-history)
  (when (and (stringp (car entry))
             (file-in-directory-p (car entry) +sayre-pilish-source-dir))
    (cl-assert (string-suffix-p ".el" (car entry)) nil
               "Unexpected compiled Pilish origin: %s" (car entry))))
(pi-reload)
(message "Real Pilish cold and warm source reload passed")
