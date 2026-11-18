;; -*- lexical-binding: t; -*-
;;; modules/sayre/pilish/config.el -*- lexical-binding: t; -*-
;;; Complete Pilish block moved from the root config.el.  The old :load-path
;;; is replaced by the shared absolute source dir (shared.el + the evaluated
;;; straight recipe in packages.el); all settings, the launch key, the raw-
;;; markdown copy behavior, and all FOUR `add-hook' forms are unchanged.

(load! "shared")

;; ============================================================================
;; pilish.el - Emacs frontend for pi coding agent
;; ============================================================================
(use-package! pilish
  ;; Local development checkout, resolved by shared.el and wired into
  ;; straight by packages.el (no :load-path).
  ;; Defer loading until the `pilish' command is invoked
  :commands (pilish)
  :init
  ;; Bind SPC o p to launch the pi coding agent
  (map! :leader
        :desc "Pi coding agent" "o p" #'pilish)
  ;; Copy messages as raw markdown instead of rendered text
  (setq pilish-copy-raw-markdown t)
  ;; Start the input buffer in evil normal state
  (setq pilish-evil-input-state 'normal)
  ;; Launch sessions chat-only and hide the input after each send;
  ;; reopen it with `i'/`a' (Evil) or M-x pilish-open-input.
  ;; This subsumes the old `my/pi-send-close-input' advice.
  (setq pilish-input-window-display 'hidden)
  ;; Initial trust policy: `default' passes no trust flag.
  ;; (pi also supports `approve'; omp has no project-trust gate at all —
  ;; project-local omp resources are always active, a behavioral difference
  ;; vs pi --approve.  See my/pilish-toggle-backend below.)
  (setq pilish-project-trust-policy 'default)
  ;; Active backend: pi (the shared default command; copied so backend
  ;; toggling can mutate the value without touching the shared constant).
  ;; --- optional omp backend ("Oh My Pi", a pi-lineage fork) ---
  ;; omp has no --approve/--no-approve flags; pi's flag would kill the
  ;; process at startup (exit 2), hence `default' under omp.  To trial it:
  ;; M-x my/pilish-toggle-backend (or (setq pilish-executable '("omp"))).
  ;; Known gaps on omp: model picker (C-c C-m) fails, slash-command menu
  ;; empty, fork unsupported, session browser needs Phase 1 root fix.
  (setq pilish-executable (copy-sequence +sayre-pilish-default-command))
  :config
  ;; Mark only the chat buffer as "real" so Doom treats it like a
  ;; regular file buffer.  Leave the input buffer non-real (Doom's
  ;; default) so it behaves like an ephemeral/popup pane.
  (add-hook 'pilish-chat-mode-hook (lambda () (setq doom-real-buffer-p t)))
  ;; Disable line numbers in chat and input buffers
  (add-hook 'pilish-chat-mode-hook
            (lambda () (display-line-numbers-mode -1)))
  (add-hook 'pilish-input-mode-hook
            (lambda () (display-line-numbers-mode -1)))
  ;; Show the agent's status header line in chat buffers
  (add-hook 'pilish-chat-mode-hook
            (lambda () (setq-local header-line-format
                                   '(:eval (pilish--header-line-string))))))

;; Reload Pilish definitions from explicit development source files, in
;; dependency order (verified against the checkout's `require' graph; the
;; Evil file is conditional and loads last).  Absolute .el paths with load's
;; NOSUFFIX argument, so a stale sibling .elc can never win.  Note: this
;; replaces definitions but does not tear down running sessions, timers, or
;; removed definitions; cold starts remain required for installation tests.
;; An extensionless internal `require' could still pick up bytecode if a
;; dependency were missing from this ordered list.
(defun pi-reload ()
  "Reload Pilish definitions from explicit development source files."
  (interactive)
  (let* ((files
          (append
           '("pilish-core.el"
             "pilish-grammars.el"
             "pilish-ui.el"
             "pilish-jsonl.el"
             "pilish-table.el"
             "pilish-conversations.el"
             "pilish-answer.el"
             "pilish-render.el"
             "pilish-input.el"
             "pilish-menu.el"
             "pilish-browse.el"
             "pilish-snapshot.el"
             "pilish.el")
           (when (featurep 'evil) '("pilish-evil.el"))))
         (paths (mapcar (lambda (file)
                          (expand-file-name file +sayre-pilish-source-dir))
                        files))
         (load-path (cons +sayre-pilish-source-dir load-path)))
    (dolist (path paths)
      (unless (file-readable-p path)
        (user-error "Missing Pilish source: %s" path)))
    (dolist (path paths)
      (load path nil t t))
    (message "Pilish source reloaded (%d files)" (length paths))))

(defun my/pilish-toggle-backend (&optional arg)
  "Toggle the pilish RPC backend between omp and pi.
With prefix ARG, force pi.  New sessions pick up the change; running
sessions keep their current process.  See .scratch/PILISH-OMP-PLAN.md."
  (interactive "P")
  (setq pilish-executable
        (if arg '("pi")
          (if (equal (car pilish-executable) "omp") '("pi") '("omp"))))
  ;; pi supports --approve, omp does not; keep the policy compatible
  ;; with whichever backend is active.
  (setq pilish-project-trust-policy
        (if (equal (car pilish-executable) "omp") 'default 'approve))
  (message "pilish backend: %s (trust policy: %s)"
           (car pilish-executable) pilish-project-trust-policy))
