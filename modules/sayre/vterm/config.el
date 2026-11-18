;; -*- lexical-binding: t; -*-
;;; modules/sayre/vterm/config.el -*- lexical-binding: t; -*-
;;; Personal vterm customization on top of the stock :term vterm module
;;; (which owns the package — no second package declaration here).
;;; Only the terminal-specific pieces moved out of the root config.el; the
;;; shared Shift-Return implementation (`+my/find-file-at-point-other-window')
;;; and its global binding remain in root config.el.

;; Prerequisite: this module only adjusts the stock :term vterm module.
;; Fail clearly instead of half-working when it is disabled.
(unless (modulep! :term vterm)
  (error "sayre:vterm requires the :term vterm module; enable it or disable :sayre vterm."))

;; remove vterm output from popups -> use full window instead
;;
;; NOTE: deliberately NOT wrapped in `(after! popup ...)'.  In this Doom
;; version (doom+ / v3 core) the :ui popup module is `doom-load'ed as a plain
;; file and never `(provide 'popup)'s, so an `after! popup' block silently
;; never runs.  The companion PLANTUML exception lives in
;; modules/sayre/diagrams/config.el.
(when (modulep! :ui popup)
  (set-popup-rule! "^\\*vterm\\*" :ignore t))

;; ============================================================================
;; vterm: SPC o T reuses an existing undisplayed vterm buffer
;; ============================================================================
;; Everything here is default Doom behavior, except: `+vterm/here' (SPC o T)
;; normally spawns a brand-new vterm every time.  Instead, if a full (non-popup)
;; vterm buffer already exists but isn't displayed in any window, switch to it.

(defun my/vterm-here (&optional arg)
  "Like `+vterm/here', but reuse an existing undisplayed vterm buffer.

With no prefix ARG: if a vterm buffer (created by SPC o T, i.e. not a
SPC o t popup) exists and no window is displaying it, switch to it in
the current window.  Otherwise, exactly `+vterm/here' behavior."
  (interactive "P")
  (if-let* ((buf (and (not arg)
                      (cl-loop for buf in (doom-buffers-in-mode 'vterm-mode)
                               unless (string-prefix-p "*doom:" (buffer-name buf))
                               unless (get-buffer-window-list buf nil t)
                               return buf))))
      ;; `display-buffer-alist' must be nil'd, else Doom's "^\*vterm" popup
      ;; rule hijacks the buffer into a side window (same trick +vterm/here
      ;; uses internally).
      (let (display-buffer-alist)
        (pop-to-buffer-same-window buf))
    (call-interactively #'+vterm/here)))

(map! :leader
      :desc "Open vterm here (reuse if hidden)" "oT" #'my/vterm-here)

;; vterm captures all keys; re-bind S-RET there too (the shared
;; implementation is defined in root config.el).
(after! vterm
  (map! :map vterm-mode-map
        "S-<return>" #'+my/find-file-at-point-other-window))
