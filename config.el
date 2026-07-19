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
(setq doom-font (font-spec :family "Fira Code" :size 15 :weight 'semi-light)
      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 15)
      doom-symbol-font (font-spec :family "Apple Symbols"))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-earl-grey)
;;(setq doom-theme 'doom-one)
;; (setq doom-theme 'doom-nord-light)
;; (setq doom-theme 'doom-nord)
;; (setq doom-theme 'doom-zenburn)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; Fix org-modern fold stars: replace Level 3 chars (⯈/⯆ U+2BC8/2BC6) which
;; are missing from nearly all installed fonts, with glyphs Apple Symbols has.
(after! org-modern
  (setq org-modern-fold-stars
        '(("▶" . "▼") ("▷" . "▽") ("▸" . "▾") ("▹" . "▿") ("▸" . "▾"))))

;; ob-mermaid — org-babel execution for mermaid diagrams
;; Requires: npm install -g @mermaid-js/mermaid-cli (provides mmdc)
(after! org
  (require 'ob-mermaid)
  (setq ob-mermaid-cli-path "/opt/homebrew/bin/mmdc"))


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


;; Remap modifier keys for macOS:
;;   - Set Command (⌘) key to function as Control key for Emacs shortcuts
;;   - Physical Control (⌃) key remains as Control key by default
;;
;; This makes common Emacs shortcuts (like C-c/C-v) accessible via Command key.
;; Uncomment the second line to make Control key function as Meta/Alt instead.
(setq
 ns-command-modifier 'control    ; Command key → Control
 ;; ns-control-modifier 'meta   ; Uncomment to make Control key → Meta
 )

;; kill evil snipe mode
(remove-hook 'doom-first-input-hook #'evil-snipe-mode)

;; Configure Evil to treat symbols as words for movement and search operations.
;;
;; This changes the behavior of:
;;   - Word movements (w, b, e) to move by symbol boundaries
;;   - Word searches (*, #) to match entire symbols
;;
;; Symbols include any non-whitespace characters (letters, numbers, underscores, etc.)
;; Example: "foo_bar" is treated as a single word rather than two separate words.
;;
;; References:
;;   https://emacs.stackexchange.com/questions/9583/how-to-treat-underscore-as-part-of-the-word
;;   :help evil-symbol-word-search
(with-eval-after-load 'evil
  ;; Alias forward-evil-word to forward-evil-symbol so word movements use symbol boundaries
  (defalias #'forward-evil-word #'forward-evil-symbol)
  ;; Enable symbol-based word searching so */# match entire symbols
  (setq-default evil-symbol-word-search t))


;; dired-mode configs
;;
;; turn off dired-omit-mode by default, to display '.' and '..' files
;; https://emacs.stackexchange.com/questions/51046/how-to-use-recover-session-and-dired-omit-mode-in-emacs-26-and-lower
;; https://github.com/doomemacs/doomemacs/issues/1568
(remove-hook 'dired-mode-hook #'dired-omit-mode)

;; turn off the "really quit emacs" prompt when closing emacs
(setq confirm-kill-emacs nil)

;; remove compile output from popups (SPC c c) -> use full window instead
(after! popup
  (set-popup-rule! "^\\*compilation\\*" :ignore t)
  (set-popup-rule! "^\\*vterm\\*" :ignore t)
  (set-popup-rule! "^\\*PLANTUML" :ignore t))

;; associate .puml files with plantuml-mode
(add-to-list 'auto-mode-alist '("\\.puml\\'" . plantuml-mode))

;; maximize emacs on startup
(add-to-list 'initial-frame-alist '(fullscreen . maximized))

;; ============================================================================
;; pi-coding-agent.el - Emacs frontend for pi coding agent
;; ============================================================================
(use-package! pi-coding-agent
  :load-path "~/.config/doom/site-lisp/pi.el"
  :commands (pi-coding-agent)
  :init
  ;; Auto-detect truman projects: if .devcontainer/truman.sh exists,
  ;; route pi through the sandboxed container; otherwise run natively.
  ;; Uses setq (not let) so the async version probe sees the right value.
  (defun my/pi-maybe-truman ()
    "Start pi-coding-agent, prompting for truman when available."
    (interactive)
    (let* ((dir (or (when-let ((proj (project-current)))
                      (project-root proj))
                    default-directory))
           (truman-sh (expand-file-name ".devcontainer/truman.sh" dir)))
      (setq pi-coding-agent-executable
            (if (and (file-executable-p truman-sh)
                     (y-or-n-p "Truman devcontainer detected. Run sandboxed? "))
                (list truman-sh "run-pi" "-T")
              '("pi"))))
    (call-interactively #'pi-coding-agent))

  ;; Fix executable-find check for relative paths (e.g. .devcontainer/truman.sh).
  ;; The upstream check only searches PATH; we also resolve against default-directory.
  ;; NB: upstream `pi-coding-agent--check-pi' now takes an optional DIRECTORY
  ;; argument (used to bind `default-directory'); the override must accept it too,
  ;; or callers like `pi-coding-agent--check-dependencies' error with
  ;; "Wrong number of arguments".
  (advice-add 'pi-coding-agent--check-pi :override
              (lambda (&optional directory)
                (let* ((directory (or directory default-directory))
                       (default-directory directory)
                       (cmd (car pi-coding-agent-executable)))
                  (or (executable-find cmd)
                      (file-executable-p (expand-file-name cmd directory))))))

  ;; Leader key binding to start pi
  (map! :leader
        :desc "Pi coding agent" "o p" #'my/pi-maybe-truman)

  ;; Command to open input as a split within the chat window
  (defun my/pi-open-input ()
    "Open the pi input buffer in a split below the chat buffer.
     If the input buffer is already visible, select its window instead."
    (interactive)
    (when-let ((input-buf (pi-coding-agent--get-input-buffer)))
      (if-let ((existing-win (get-buffer-window input-buf)))
          (select-window existing-win)
        (let ((input-win (split-window-below -10)))
          (set-window-buffer input-win input-buf)
          (select-window input-win)))))

  ;; Close input window after sending
  (defadvice! my/pi-send-close-input (&rest _)
    :after #'pi-coding-agent-send
    (when-let ((win (get-buffer-window (current-buffer))))
      (when (and (window-parent win)
                 (derived-mode-p 'pi-coding-agent-input-mode))
        (delete-window win))))

  :config
  ;; Set appropriate evil states for each mode
  (after! evil
    (evil-set-initial-state 'pi-coding-agent-chat-mode 'motion)
    (evil-set-initial-state 'pi-coding-agent-input-mode 'insert))

  ;; Mark pi buffers as "real" so they appear in workspace buffer lists
  (add-hook 'pi-coding-agent-chat-mode-hook (lambda () (setq doom-real-buffer-p t)))
  (add-hook 'pi-coding-agent-input-mode-hook (lambda () (setq doom-real-buffer-p t)))

  ;; Close input window with q in normal mode
  (defun my/pi-close-input ()
    "Close the input window and return to chat."
    (interactive)
    (when-let ((win (get-buffer-window (current-buffer))))
      (delete-window win)))

  ;; Wrap pi-quit with confirmation prompt
  (defadvice! my/pi-quit-confirm (&rest args)
    :before-while #'pi-coding-agent-quit
    (yes-or-no-p "Really quit Pi session? "))

  ;; Chat buffer bindings (motion state - read-only buffer)
  (map! :map pi-coding-agent-chat-mode-map
        ;; Actions
        :m [tab]       #'pi-coding-agent-toggle-tool-section
        :m "TAB"       #'pi-coding-agent-toggle-tool-section
        :m "i"         #'my/pi-open-input  ; open input popup
        :m "q"         #'pi-coding-agent-quit
        :m "?"         #'pi-coding-agent-menu
        :m "C-c C-p"   #'pi-coding-agent-menu
        ;; :m "<escape>"  #'pi-coding-agent-abort
        ;; :m "ESC"       #'pi-coding-agent-abort
        :m "C-c C-k"   #'pi-coding-agent-abort
        ;; Session
        :m "C-c C-n"   #'pi-coding-agent-new-session
        :m "C-c C-r"   #'pi-coding-agent-resume-session
        :m "C-c C-e"   #'pi-coding-agent-export-html
        ;; Context
        :m "C-c C-c"   #'pi-coding-agent-compact
        :m "C-c C-b"   #'pi-coding-agent-fork-at-point
        ;; Model
        :m "C-c C-m"   #'pi-coding-agent-select-model
        :m "C-c C-t"   #'pi-coding-agent-cycle-thinking
        ;; Info
        :m "C-c C-s"   #'pi-coding-agent-session-stats
        :m "C-c C-y"   #'pi-coding-agent-copy-last-message
        )

  ;; Input buffer bindings (matches pi-menu transient commands)
  (map! :map pi-coding-agent-input-mode-map
        ;; Actions
        :n "q"         #'my/pi-close-input
        :n "?"         #'pi-coding-agent-menu
        :n "C-c C-k"   #'pi-coding-agent-abort
        :n "<return>"  #'pi-coding-agent-send
        :n "RET"       #'pi-coding-agent-send
        ;; Session
        :n "C-c C-n"   #'pi-coding-agent-new-session
        :n "C-c C-r"   #'pi-coding-agent-resume-session
        :n "C-c C-e"   #'pi-coding-agent-export-html
        ;; Context
        :n "C-c C-c"   #'pi-coding-agent-compact
        :n "C-c C-b"   #'pi-coding-agent-fork-at-point
        ;; Model
        :n "C-c C-m"   #'pi-coding-agent-select-model
        :n "C-c C-t"   #'pi-coding-agent-cycle-thinking
        ;; Info
        :n "C-c C-s"   #'pi-coding-agent-session-stats
        :n "C-c C-y"   #'pi-coding-agent-copy-last-message
        )


  )

;;   ;; Add mode-line click support to pi's header keymaps
;;   (define-key pi-coding-agent--header-model-map [mode-line mouse-1] #'pi-coding-agent-select-model)
;;   (define-key pi-coding-agent--header-model-map [mode-line mouse-2] #'pi-coding-agent-select-model)
;;   (define-key pi-coding-agent--header-thinking-map [mode-line mouse-1] #'pi-coding-agent-cycle-thinking)
;;   (define-key pi-coding-agent--header-thinking-map [mode-line mouse-2] #'pi-coding-agent-cycle-thinking)

;;   ;; Helper to right-align mode-line content
;;   (defun my/mode-line-fill (reserve)
;;     "Return empty space leaving RESERVE space on the right."
;;     (propertize " "
;;                 'display `((space :align-to (- (+ right right-fringe right-margin) ,reserve)))))

;;   ;; Custom mode-line for chat buffer with pi status on the right
;;   (add-hook 'pi-coding-agent-chat-mode-hook
;;             (lambda ()
;;               (setq-local header-line-format nil)  ; Remove header-line
;;               (setq-local mode-line-format
;;                           '("%e"
;;                             mode-line-front-spac
;;                             mode-line-buffer-identification
;;                             ;; Fill space to push pi info to the right
;;                             (:eval (my/mode-line-fill
;;                                     (string-width (or (pi-coding-agent--header-line-string) ""))))
;;                             ;; Pi info (model, thinking, stats)
;;                             (:eval (pi-coding-agent--header-line-string))))))

;;   ;; Remove header-line from input buffer
;;   (add-hook 'pi-coding-agent-input-mode-hook
;;             (lambda ()
;;               (setq-local header-line-format nil)))

;;   ;; Fix spinner: also update chat buffer mode-line (where we moved it)
;;   (defadvice! my/pi-spinner-update-chat (&rest _)
;;     :after #'pi-coding-agent--spinner-tick
;;     (dolist (buf pi-coding-agent--spinning-sessions)
;;       (when (buffer-live-p buf)
;;         (dolist (win (get-buffer-window-list buf nil t))
;;           (with-selected-window win
;;             (force-mode-line-update))))))

;;   ;; Override display to only show chat initially
;;   (defadvice! my/pi-display-chat-only (chat-buf _input-buf)
;;     :override #'pi-coding-agent--display-buffers
;;     (switch-to-buffer chat-buf)
;;     (with-current-buffer chat-buf
;;       (goto-char (point-max))))

;;   ;; Helper to look up keys from pi-coding-agent-input-mode-map for transient menu
;;   (defun my/pi-key (cmd)
;;     "Get key string bound to CMD in pi-coding-agent-input-mode's evil normal state map."
;;     (let* ((state-map (evil-get-auxiliary-keymap pi-coding-agent-input-mode-map 'normal t))
;;            (key (when state-map (where-is-internal cmd state-map nil t))))
;;       (if key
;;           (key-description key)
;;         "?"))))

(defun pi-reload ()
  "Reload all pi-coding-agent modules from development directory."
  (interactive)
  (let ((dir "~/.config/doom/site-lisp/pi.el/"))
    (dolist (mod '("pi-coding-agent-core"
                   "pi-coding-agent-grammars"
                   "pi-coding-agent-ui"
                   "pi-coding-agent-table"
                   "pi-coding-agent-render"
                   "pi-coding-agent-input"
                   "pi-coding-agent-menu"
                   "pi-coding-agent"))
      (load (expand-file-name mod dir) nil t)))
  (message "Pi reloaded (all modules)"))
