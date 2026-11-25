;; -*- lexical-binding: t; -*-
;;; modules/sayre/quota-axi/config.el -*- lexical-binding: t; -*-
;;; Magit-style under Evil: motion state.  Evil's motion keys win; the
;;; vanilla keys that would collide move (g r refreshes, [ and ] move
;;; between providers, TAB folds a card).  The core never loads Evil; the
;;; opt-in adapter quota-axi-evil does.

;; Common buffers for every workspace.  Doom workspaces are persp-mode
;; perspectives.  A buffer matching the common filter belongs to none of
;; them: it is never attached to a workspace, switching to it never
;; prompts, and killing it never asks.  The "*quota-axi" prefix covers
;; the report buffer plus its siblings: *quota-axi: PROVIDER* (detail),
;; *quota-axi-help* and *quota-axi-auth*.
(defun +sayre-quota-axi-common-buffer-p (buffer)
  (string-prefix-p "*quota-axi" (buffer-name buffer)))
(with-eval-after-load 'persp-mode
  (add-to-list 'persp-common-buffer-filter-functions
               #'+sayre-quota-axi-common-buffer-p))

(use-package! quota-axi
  :commands (quota-axi)
  :config
  (map! :map quota-axi-mode-map          ; the localleader is SPC m
        :localleader "?" #'quota-axi-dispatch))

(when (modulep! :editor evil)
  (after! evil
    (require 'quota-axi-evil)))

;; SPC o q: the report buffer.  Already displayed: jump to it.  One window:
;; split (to the right when it is wide enough).  Two or more windows: show it
;; in the selected window.  A plain `pop-to-buffer' with ACTION t would pop up
;; a new window whenever the selected one is wide enough, which is where the
;; unwanted third window came from.
(defun +sayre-quota-axi-other-window ()
  "Show *quota-axi* and refresh it: in the selected window, or a split when there is only one window."
  (interactive)
  (let ((buf (get-buffer-create "*quota-axi*")))
    (cond ((get-buffer-window buf t)
           (pop-to-buffer buf))
          ((one-window-p t)
           (let ((split-height-threshold nil)
                 (split-width-threshold 100))
             (pop-to-buffer buf t)))
          (t
           (pop-to-buffer buf '(display-buffer-same-window))))
    (quota-axi)))

(map! :leader :prefix "o"
      :desc "quota-axi" "q" #'+sayre-quota-axi-other-window)
