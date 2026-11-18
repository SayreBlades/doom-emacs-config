;;; macos-copy-check.el --- Real conversion probes without clipboard writes -*- lexical-binding: t; -*-

;; emacs -Q --batch -L <yank-rich> -L <htmlize> -L <ox-clip>
;;   -l tests/macos-copy-check.el -f ert-run-tests-batch-and-exit
;; Only the clipboard destination is replaced with a disposable RTF file.
;; Real pandoc/textutil/htmlize/Org/ox-clip conversions run. Rich application
;; paste and actual system clipboard integration remain separate manual checks.
(require 'ert)
(require 'cl-lib)
(require 'yank-rich)
(require 'org)
(require 'ox-html)
(require 'ox-clip)

(defmacro copy-check--capture-rtf (&rest body)
  (declare (indent 0) (debug t))
  `(let* ((file (make-temp-file "doom-copy-check-" nil ".rtf"))
          (command (concat "textutil -inputencoding UTF-8 -stdin -format html -convert rtf -stdout > "
                           (shell-quote-argument file)))
          (yank-rich-rtf-command command)
          (ox-clip-osx-cmd command)
          (kill-ring nil)
          (kill-ring-yank-pointer nil)
          (interprogram-cut-function nil))
     (unwind-protect
         (progn
           (skip-unless (and (eq system-type 'darwin) (executable-find "textutil")))
           ,@body
           (with-temp-buffer
             (insert-file-contents file)
             (should (string-prefix-p "{\\rtf" (buffer-string))))
           (with-temp-buffer
             (should (zerop (call-process "textutil" nil t nil "-convert" "txt" "-stdout" file)))
             (should (string-match-p "refactor-copy-probe" (buffer-string)))))
       (delete-file file))))

(ert-deftest copy-check/markdown-real-rich-and-plain ()
  (skip-unless (executable-find yank-rich-pandoc-executable))
  (copy-check--capture-rtf
    (with-temp-buffer
      ;; This selects the real Markdown conversion path without loading a
      ;; separate major-mode package or requiring tree-sitter in this probe.
      (setq major-mode 'markdown-mode)
      (insert "**refactor-copy-probe**\n\n```sh\necho hello\n```\n")
      (yank-rich-plain (point-min) (point-max))
      ;; Common-indent stripping keeps code indentation in mixed prose.
      (should (equal (car kill-ring) "refactor-copy-probe\n\n    echo hello"))
      (yank-rich-rich (point-min) (point-max)))
    (with-temp-buffer
      (setq major-mode 'markdown-mode)
      (insert "```sh\necho hello\n```\n")
      (yank-rich-plain (point-min) (point-max))
      (should (equal (car kill-ring) "echo hello")))))

(ert-deftest copy-check/org-real-ox-clip-rich ()
  (copy-check--capture-rtf
    (with-temp-buffer
      (org-mode)
      (insert "*refactor-copy-probe* and /emphasis/\n")
      ;; ox-clip exports the active region; keep it active in batch too.
      (goto-char (point-min))
      (push-mark (point-max) nil t)
      (let ((transient-mark-mode t))
        (yank-rich-rich (point-min) (point-max)))
      (should (string-match-p "refactor-copy-probe" (car kill-ring))))))

(ert-deftest copy-check/fallback-real-htmlize-rich ()
  (copy-check--capture-rtf
    (with-temp-buffer
      (text-mode)
      (insert "refactor-copy-probe\n")
      (yank-rich-rich (point-min) (point-max)))))
