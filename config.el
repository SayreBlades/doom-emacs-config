;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;;(setq doom-theme 'doom-one)
(setq doom-theme 'doom-nord)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;; make the command key interpreted as ctrl - assuming mac command key
(setq
 ns-command-modifier 'control
 ;; ns-control-modifier 'meta
 )

;; kill evil snipe mode
(remove-hook 'doom-first-input-hook #'evil-snipe-mode)

;; evil configs
;;
;; use symbols instead of word boundaries
;; https://emacs.stackexchange.com/questions/9583/how-to-treat-underscore-as-part-of-the-word
;; viw -> marks symbol
(with-eval-after-load 'evil
  (defalias #'forward-evil-word #'forward-evil-symbol)
  ;; make evil-search-word look for symbol rather than word boundaries
  (setq-default evil-symbol-word-search t))


;; dired-mode configs
;;
;; turn off dired-omit-mode by default, to display '.' and '..' files
;; https://emacs.stackexchange.com/questions/51046/how-to-use-recover-session-and-dired-omit-mode-in-emacs-26-and-lower
;; https://github.com/doomemacs/doomemacs/issues/1568
(remove-hook 'dired-mode-hook #'dired-omit-mode)

;; turn off the "really quit emacs" prompt when closing emacs
(setq confirm-kill-emacs nil)

;; remove vterm from popups
(after! popup
  (set-popup-rule! "^\\*vterm\\*" :ignore t))

(defun my/display-in-right-window (buffer _alist)
  "Display BUFFER in the right-hand window.
   If only one window is present, it is split vertically.
   If multiple windows are present, the right-most one is used."
  (let ((target-window
         (if (one-window-p t)
             (split-window-right)
           (let ((win (frame-root-window)))
             ;; Traverse right until we can't anymore
             (while (window-in-direction 'right win)
               (setq win (window-in-direction 'right win)))
             win))))
    (window-set-buffer target-window buffer)
    target-window))

;; Add our custom display action to the end of the list, so it acts as a fallback.
(add-to-list 'display-buffer-alist
             '(t (my/display-in-right-window)) t)
