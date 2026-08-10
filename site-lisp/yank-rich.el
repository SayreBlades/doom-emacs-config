;;; yank-rich.el --- Multi-format yank: rich (RTF), plain (stripped), raw -*- lexical-binding: t; -*-

;; Copyright (C) 2026 SayreBlades
;; SPDX-License-Identifier: GPL-3.0-or-later

;; Author: SayreBlades
;; Keywords: convenience, clipboard, yank, rich-text

;;; Commentary:

;; Three yank modalities beyond normal `y':
;;
;;   `yank-rich'  — Copy as RTF to system clipboard.  Formatting (bold,
;;                  italic, code background, links) is preserved for pasting
;;                  into Word, Outlook, Teams, etc.  In org-mode delegates to
;;                  `ox-clip-formatted-copy'; elsewhere uses `htmlize' to
;;                  capture Emacs faces → HTML → textutil → RTF → pbcopy.
;;
;;   `yank-plain' — Copy content stripped of ALL markup.  Code fences,
;;                  bold markers, table pipes — everything is removed via
;;                  pandoc.  Ideal for grabbing a command from a rendered
;;                  code block without ```bash cruft.
;;
;; Both are `evil-define-operator's, so they work with:
;;   - Visual selection: select text, then `gyr' or `gyp'
;;   - Motions:          `gyr ip' (rich-yank inner paragraph)
;;
;; The raw modality (underlying markup source) is just normal `y' — left
;; undisturbed.
;;
;; macOS only (uses `textutil' + `pbcopy').  Requires: pandoc, htmlize.

;;; Code:

(require 'cl-lib)

;; Optional deps — loaded on demand.
(declare-function htmlize-region-for-paste "htmlize" (beg end))
(declare-function ox-clip-formatted-copy "ox-clip" (r1 r2))
(declare-function evil-yank "evil" (beg end &optional type register yank-handler))

;;;; Customization

(defgroup yank-rich nil
  "Multi-format yank: rich, plain, raw."
  :group 'convenience)

(defcustom yank-rich-pandoc-executable "pandoc"
  "Path to the pandoc executable for plain-text conversion."
  :type 'string
  :group 'yank-rich)

(defcustom yank-rich-rtf-command
  "textutil -inputencoding UTF-8 -stdin -format html -convert rtf -stdout | pbcopy"
  "Shell pipeline to convert HTML on stdin to RTF on the system clipboard.
Default uses macOS textutil + pbcopy."
  :type 'string
  :group 'yank-rich)

(defcustom yank-rich-dedent-code-blocks t
  "When non-nil, strip the 4-space indent pandoc adds to code blocks.
Pandoc's plain-text output indents fenced code by 4 spaces; this
dedents it back so pasted commands are ready to run."
  :type 'boolean
  :group 'yank-rich)

;;;; Utilities

(defun yank-rich--buffer-format ()
  "Return the markup format of the current buffer for pandoc input.
Returns \"markdown\", \"org\", or \"markdown\" as fallback."
  (cond
   ((derived-mode-p 'org-mode) "org")
   ((derived-mode-p 'markdown-mode) "markdown")  ; covers gfm-mode
   ((eq major-mode 'md-ts-mode) "markdown")
   ;; pi-chat derives from md-ts-mode
   ((derived-mode-p 'pi-coding-agent-chat-mode) "markdown")
   (t "markdown")))

(defun yank-rich--raw-text (beg end)
  "Return the raw buffer text between BEG and END.
In pi-chat buffers with `pi-coding-agent-copy-raw-markdown' active,
uses the filter to get the raw markdown source.  Otherwise returns
`buffer-substring-no-properties'."
  (if (and (derived-mode-p 'pi-coding-agent-chat-mode)
           (bound-and-true-p pi-coding-agent-copy-raw-markdown))
      ;; The filter function returns raw markdown (stripping render props).
      (funcall filter-buffer-substring-function beg end nil)
    (buffer-substring-no-properties beg end)))

(defun yank-rich--dedent (text)
  "Remove common leading whitespace from TEXT (like Python textwrap.dedent)."
  (let* ((lines (split-string text "\n"))
         (non-empty (cl-remove-if (lambda (l) (string-match-p "\\`[ \t]*\\'" l)) lines))
         (min-indent (if non-empty
                         (apply #'min (mapcar (lambda (l)
                                               (if (string-match "\\`\\( *\\)" l)
                                                   (length (match-string 1 l))
                                                 0))
                                             non-empty))
                       0)))
    (if (> min-indent 0)
        (mapconcat (lambda (l)
                     (if (>= (length l) min-indent)
                         (substring l min-indent)
                       l))
                   lines "\n")
      text)))

;;;; Rich (RTF) yank

(defun yank-rich--copy-as-rtf (beg end)
  "Copy region BEG..END as RTF to the system clipboard.
In `org-mode', delegates to `ox-clip-formatted-copy' (org's HTML
exporter produces the best output).  In markdown/md-ts/pi-chat modes,
uses pandoc to convert markdown → HTML (semantic: real links, tables,
code blocks) → textutil → RTF → pbcopy.  Falls back to `htmlize' for
other modes."
  (cond
   ((derived-mode-p 'org-mode)
    (require 'ox-clip)
    (ox-clip-formatted-copy beg end)
    (message "Yanked rich (org → RTF)"))
   ((or (derived-mode-p 'markdown-mode)
        (eq major-mode 'md-ts-mode)
        (derived-mode-p 'pi-coding-agent-chat-mode))
    (let* ((raw (yank-rich--raw-text beg end))
           (html (with-temp-buffer
                   (insert raw)
                   (let ((exit-code
                          (shell-command-on-region
                           (point-min) (point-max)
                           (format "%s -f markdown -t html"
                                   (shell-quote-argument yank-rich-pandoc-executable))
                           t t nil)))
                     (unless (zerop exit-code)
                       (user-error "pandoc failed (exit %d)" exit-code)))
                   (buffer-string))))
      (with-temp-buffer
        (insert html)
        (shell-command-on-region (point-min) (point-max)
                                yank-rich-rtf-command nil nil nil)
        (message "Yanked rich (pandoc → RTF)"))))
   (t
    (require 'htmlize)
    (let ((html (htmlize-region-for-paste beg end)))
      (with-temp-buffer
        (insert html)
        (shell-command-on-region (point-min) (point-max)
                                yank-rich-rtf-command nil nil nil)
        (message "Yanked rich (htmlize → RTF)"))))))

;;;; Plain yank

(defun yank-rich--copy-as-plain (beg end)
  "Copy region BEG..END as plain text (markup stripped) to kill ring.
Uses pandoc to convert from the buffer's markup format to plain text.
Also copies to the system clipboard via `kill-new'."
  (let* ((raw (yank-rich--raw-text beg end))
         (fmt (yank-rich--buffer-format))
         (result (with-temp-buffer
                   (insert raw)
                   (let ((exit-code
                          (shell-command-on-region
                           (point-min) (point-max)
                           (format "%s -f %s -t plain --wrap=none"
                                   (shell-quote-argument yank-rich-pandoc-executable)
                                   fmt)
                           t t nil)))
                     (unless (zerop exit-code)
                       (user-error "pandoc failed (exit %d)" exit-code)))
                   (buffer-string)))
         ;; Remove trailing newline pandoc adds.
         (trimmed (string-trim-right result "\n+"))
         ;; Dedent code block indentation if enabled.
         (final (if yank-rich-dedent-code-blocks
                    (yank-rich--dedent trimmed)
                  trimmed)))
    (kill-new final)
    (message "Yanked plain (%d chars)" (length final))))

;;;; Evil operators

(when (featurep 'evil)
  (evil-define-operator yank-rich (beg end _type _register _yank-handler)
    "Yank region as rich text (RTF) to the system clipboard."
    :move-point nil
    :repeat nil
    (interactive "<R><x><y>")
    (yank-rich--copy-as-rtf beg end))

  (evil-define-operator yank-plain (beg end _type _register _yank-handler)
    "Yank region as plain text (markup stripped) to kill ring."
    :move-point nil
    :repeat nil
    (interactive "<R><x><y>")
    (yank-rich--copy-as-plain beg end)))

;;;; Non-evil interactive commands (fallback)

;;;###autoload
(defun yank-rich-rich (beg end)
  "Copy region BEG..END as rich text (RTF) to system clipboard."
  (interactive "r")
  (yank-rich--copy-as-rtf beg end))

;;;###autoload
(defun yank-rich-plain (beg end)
  "Copy region BEG..END as plain text (markup stripped) to kill ring."
  (interactive "r")
  (yank-rich--copy-as-plain beg end))

(provide 'yank-rich)
;;; yank-rich.el ends here
