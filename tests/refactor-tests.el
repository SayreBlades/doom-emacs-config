;;; refactor-tests.el --- ERT fixture tests for the emacs-world refactor -*- lexical-binding: t; -*-

;; Run with:  emacs -Q --batch -l tests/refactor-tests.el -f ert-run-tests-batch-and-exit
;; or:        tests/run-refactor-tests.sh

;; These tests verify the refactor described in .scratch/emacs-world-refactor-plan.md.

;; Constraints honored here:
;; - Everything runs in an isolated `emacs -Q --batch' process; no GUI, no
;;   live Doom session, no `doom sync', no writes into the live checkout.
;;   The only writes are disposable fixtures under `make-temp-file' dirs.
;; - Module sources (modules/sayre/...) and root files are only READ and
;;   their actual forms are extracted and evaluated.  No behavior is copied
;;   into this file: the code under test is the real module code.
;; - Baseline comparisons use the saved pre-refactor root config backup.
;;   The backup directory comes from $DOOM_REFACTOR_BASELINE_DIR when set,
;;   otherwise the recorded state path under the user's home; when it is
;;   unavailable the baseline-dependent tests skip instead of failing.
;; - The Pilish development checkout is located at sources/pilish after the
;;   final move (with site-lisp/pilish as the pre-move fallback); tests do
;;   not depend on where the parent's concurrent editing currently stands.
;; - Tests that need modules/sayre/pins.el skip until the parent writes it,
;;   rather than inventing pin values.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'subr-x)
(require 'bytecomp)

(defvar doom-user-dir)
(defvar pilish-executable)
(defvar pilish-project-trust-policy)
(defvar +sayre-pilish-source-dir)
(defvar +sayre-pilish-default-command)
(defvar +sayre-mermaid-command)
(defvar ob-mermaid-cli-path)
(defvar pilish-fixture-load-record)

;;;; ------------------------------------------------------------------
;;;; Paths, all derived from this file's location (no hardcoded home).
;;;; ------------------------------------------------------------------

(defconst test--this-file
  (or (and (boundp 'load-file-name) load-file-name) buffer-file-name)
  "This test file's absolute path.")

(defconst test--doom-dir
  (directory-file-name
   (file-name-directory
    (directory-file-name
     (file-name-directory (file-truename test--this-file)))))
  "The Doom checkout root (parent of tests/).")

(defconst test--sayre-dir (expand-file-name "modules/sayre" test--doom-dir))

(defconst test--pilish-config   (expand-file-name "pilish/config.el"   test--sayre-dir))
(defconst test--pilish-packages (expand-file-name "pilish/packages.el" test--sayre-dir))
(defconst test--pilish-doctor   (expand-file-name "pilish/doctor.el"   test--sayre-dir))
(defconst test--pilish-shared   (expand-file-name "pilish/shared.el"   test--sayre-dir))
(defconst test--table-config    (expand-file-name "table-pretty/config.el"   test--sayre-dir))
(defconst test--table-packages  (expand-file-name "table-pretty/packages.el" test--sayre-dir))
(defconst test--diagrams-config (expand-file-name "diagrams/config.el" test--sayre-dir))
(defconst test--diagrams-doctor (expand-file-name "diagrams/doctor.el" test--sayre-dir))
(defconst test--diagrams-shared (expand-file-name "diagrams/shared.el" test--sayre-dir))
(defconst test--vterm-config    (expand-file-name "vterm/config.el"    test--sayre-dir))
(defconst test--yank-config     (expand-file-name "yank-rich/config.el"    test--sayre-dir))
(defconst test--yank-packages   (expand-file-name "yank-rich/packages.el"  test--sayre-dir))
(defconst test--pins-file       (expand-file-name "pins.el" test--sayre-dir))
(defconst test--root-config     (expand-file-name "config.el" test--doom-dir))

;; Baseline: optional, overridable through the environment, skipped when
;; absent so the suite never depends on one machine's home directory.
(defconst test--baseline-config
  (or (let ((env (getenv "DOOM_REFACTOR_BASELINE_DIR")))
        (and env (expand-file-name "config.el" env)))
      (let ((d (expand-file-name
                ".local/state/doom-refactor/20261116-220301/doom"
                (expand-file-name "~"))))
        (and (file-exists-p (expand-file-name "config.el" d))
             (expand-file-name "config.el" d)))))

(defun test--pilish-real-source-dir ()
  "The real Pilish development checkout: sources/pilish after the move,
site-lisp/pilish before it; nil when neither exists yet."
  (let ((new (expand-file-name "sources/pilish" test--doom-dir))
        (old (expand-file-name "site-lisp/pilish" test--doom-dir)))
    (cond ((file-directory-p new) new)
          ((file-directory-p old) old))))

;;;; ------------------------------------------------------------------
;;;; Form extraction helpers (actual source, never copied code).
;;;; ------------------------------------------------------------------

(defun test--file-forms (file)
  "Read all top-level sexps from FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (let ((forms ()) form)
      (while (setq form (ignore-error end-of-file (read (current-buffer))))
        (push form forms))
      (nreverse forms))))

(defun test--file-forms-safe (file)
  "Like `test--file-forms' but return nil if FILE is unreadable or
unparseable (e.g. a concurrent edit is in flight)."
  (and (file-exists-p file)
       (ignore-error error (test--file-forms file))))

(defun test--deep-collect (pred form)
  "Collect every sub-form of FORM (a form or list of forms) satisfying PRED."
  (let (result)
    (cl-labels ((walk (x)
                  (when (consp x)
                    (when (funcall pred x) (push x result))
                    (walk (car x))
                    (walk (cdr x)))))
      (dolist (f (if (and (consp form) (not (functionp form))) form (list form)))
        (walk f)))
    (nreverse result)))

(defun test--find-defun (name forms)
  "Return the (defun NAME ...) form found anywhere in FORMS, or nil."
  (car (test--deep-collect
        (lambda (x) (and (eq (car-safe x) 'defun) (eq (cadr x) name)))
        forms)))

(defun test--collect-head (head forms)
  "Collect all forms whose car is HEAD, searched recursively in FORMS."
  (test--deep-collect (lambda (x) (eq (car-safe x) head)) forms))

(defun test--form-mentions (form what)
  "Non-nil if the symbol or string WHAT occurs anywhere in FORM."
  (cond ((equal form what) t)
        ((consp form) (or (test--form-mentions (car form) what)
                          (test--form-mentions (cdr form) what)))
        (t nil)))

(defun test--deep-strings (form)
  "All string literals contained in FORM."
  (let (result)
    (cl-labels ((walk (x)
                  (cond ((stringp x) (push x result))
                        ((consp x) (walk (car x)) (walk (cdr x))))))
      (walk form))
    (nreverse result)))

(defun test--multiset-equal (a b)
  "Equality of forms ignoring order and duplicates-free multiset sense."
  (equal (sort (mapcar #'prin1-to-string a) #'string<)
         (sort (mapcar #'prin1-to-string b) #'string<)))

(defun test--nosuffix-load-form (defun-form)
  "The exact (load PATH nil t t) form inside DEFUN-FORM.
The 4th argument t is load's NOSUFFIX flag."
  (car (test--deep-collect
        (lambda (x)
          (and (eq (car-safe x) 'load)
               (= (safe-length x) 5)
               (null (nth 2 x)) (eq (nth 3 x) t)
               (eq (nth 4 x) t)))
        (list defun-form))))

(defun test--pi-reload-declared-files ()
  "The ordered 13-file list quoted inside the actual `pi-reload' defun."
  (let* ((defun (test--find-defun 'pi-reload (test--file-forms test--pilish-config)))
         (qlist (car (test--deep-collect
                      (lambda (x)
                        (and (eq (car-safe x) 'quote)
                             (consp (cadr x))
                             (cl-every #'stringp (cadr x))
                             (>= (length (cadr x)) 5)))
                      (list defun)))))
    (should defun)
    (should qlist)
    (cadr qlist)))

;;;; ------------------------------------------------------------------
;;;; Doom-environment stubs.  These stand in for Doom-only macros and
;;;; functions so the REAL module files can be loaded in `emacs -Q'.
;;;; They record what was called; they never emulate module behavior.
;;;; ------------------------------------------------------------------

(defvar test--package!-forms nil
  "Unevaluated (package! NAME . PLIST) forms recorded by the stub.")
(defvar test--skipped-loads nil
  "Files the `load!' stub could not find (e.g. pins.el not written yet).")
(defvar test--warnings nil
  "Messages passed to the `warn!' stub.")
(defvar test--popup-rules nil
  "Rules passed to the `set-popup-rule!' stub.")
(defvar test--modulep-table nil
  "Alist of MODULE -> boolean overriding the default (enabled).")

(defvar test--idempotent-loads nil
  "When non-nil, `load!' skips files already loaded (lets a test rebind
variables that a shared file would otherwise re-defconst).")

(defun load! (file &optional _noerror)
  "Stub for Doom's `load!': resolve FILE relative to the loading file."
  (let* ((dir (and load-file-name (file-name-directory load-file-name)))
         (target (and dir (expand-file-name file dir)))
         (target (cond ((and target (file-exists-p target)) target)
                       ((and target (file-exists-p (concat target ".el")))
                        (concat target ".el")))))
    (cond ((and target test--idempotent-loads
                (cl-find target load-history :key #'car :test #'equal))
           nil)                   ; already loaded; keep current bindings
          (target (load target nil t))
          (t (push target test--skipped-loads)))))

(defmacro package! (&rest whole)
  "Stub for Doom's `package!': record the unevaluated form."
  (declare (indent 1))
  `(setq test--package!-forms
         (append test--package!-forms (list ',whole))))

(defun warn! (msg &rest args)
  "Stub for Doom's `warn!'."
  (push (if args (apply #'format msg args) msg) test--warnings)
  nil)

(defun test--modulep (module)
  (let ((entry (assq module test--modulep-table)))
    (if entry (eq (cdr entry) t) t)))

(defmacro modulep! (module &rest _)
  "Stub for Doom's `modulep!'."
  `(test--modulep ',module))

(defmacro after! (_feature &rest body)
  "Stub: run BODY now."
  (declare (indent 1))
  `(progn ,@body))

(defmacro use-package! (_name &rest _)
  "Stub: record nothing, expand nothing."
  (declare (indent 1))
  nil)

(defmacro map! (&rest _)
  "Stub: key bindings are verified structurally, not installed here."
  nil)

(defun set-popup-rule! (rule &rest props)
  "Stub: record the rule."
  (push (cons rule props) test--popup-rules)
  nil)

;; The diagrams config requires ob-mermaid inside `after! org'; provide a
;; stand-in feature so the REAL `require' form succeeds in emacs -Q.
(provide 'ob-mermaid)

;;;; ------------------------------------------------------------------
;;;; Pilish fixture machinery.
;;;; The fixture require-graph is READ FROM THE REAL CHECKOUT (not
;;;; copied into this file); fixture files are disposable and live
;;;; only under temp dirs.
;;;; ------------------------------------------------------------------

(defun test--pilish-real-require-graph (dir)
  "Alist (FILE . INTERNAL-REQUIRES) for every pilish*.el in DIR."
  (let (graph)
    (dolist (file (directory-files dir t "\\`pilish.*\\.el\\'"))
      (let ((reqs (cl-loop for form in (test--file-forms file)
                           when (and (eq (car-safe form) 'require)
                                     (symbolp (cadr form))
                                     (string-match-p "\\`pilish" (symbol-name (cadr form))))
                           collect (symbol-name (cadr form)))))
        (push (cons (file-name-nondirectory file) reqs) graph)))
    (nreverse graph)))

(defun test--write-pilish-fixtures (dir graph stale)
  "Write fixture files for GRAPH into DIR.  STALE selects the bytecode-
generation stamps; rewriting with STALE nil produces distinct fresh-source
content."
  (pcase-dolist (`(,base . ,reqs) graph)
    (let* ((feature (file-name-sans-extension base))
           (stamp (if stale
                      (format "STALE-BYTECODE %s v0" feature)
                    (format "FRESH-SOURCE %s v1" feature)))
           (body `((defvar pilish-fixture-load-record nil)
                   ,@(mapcar (lambda (r) `(require ',(intern r))) reqs)
                   (provide ',(intern feature))
                   (setq pilish-fixture-load-record
                         (append pilish-fixture-load-record ',(list base)))
                   (defun pilish-fixture--probe ()
                     ,stamp
                     ',(intern feature)))))
      (with-temp-file (expand-file-name base dir)
        (insert (format ";;; %s --- disposable pi-reload fixture -*- lexical-binding: t; -*-\n" base))
        (insert ";;; Generated by refactor-tests.el; lives only in this temp dir.\n")
        (dolist (f body)
          (prin1 f (current-buffer))
          (insert "\n"))))))

(defun test--compile-fixtures (dir)
  "Byte-compile every fixture in DIR (creating the stale-.elc hazard)."
  (let ((load-path (cons dir load-path))
        (byte-compile-warnings nil))
    (dolist (file (directory-files dir t "\\.el\\'"))
      (byte-compile-file file))))

(defun test--make-fake-executable (path)
  "Create an executable placeholder script at PATH (no real program)."
  (write-region "#!/bin/sh\nexit 0\n" nil path nil 'silent)
  (set-file-modes path #o755))

(defun test--fresh-root ()
  "A disposable doom-user-dir fixture root."
  (make-temp-file "refactor-test-root-" t))

;;;; ------------------------------------------------------------------
;;;; Tests: environment and shared source-dir derivation
;;;; ------------------------------------------------------------------

(ert-deftest refactor/test-environment-isolated-and-portable ()
  "The suite runs non-interactively and derives every path from itself."
  (should noninteractive)
  (should (file-exists-p (expand-file-name "init.el" test--doom-dir)))
  (dolist (f (list test--pilish-config test--pilish-packages test--pilish-doctor
                   test--pilish-shared test--table-config test--table-packages
                   test--diagrams-config test--diagrams-doctor test--diagrams-shared
                   test--vterm-config test--yank-config test--yank-packages))
    (should (file-exists-p f))))

(ert-deftest refactor/pilish-shared-derives-sources-pilish-from-doom-user-dir ()
  "shared.el must derive sources/pilish from doom-user-dir (the final
move layout), and only from it."
  (let ((root (test--fresh-root)))
    (let ((doom-user-dir root))
      (load test--pilish-shared nil t t))
    (should (file-name-absolute-p +sayre-pilish-source-dir))
    (should (equal +sayre-pilish-source-dir
                   (file-name-as-directory (expand-file-name "sources/pilish" root))))
    (should (equal +sayre-pilish-default-command '("pi")))))

;;;; ------------------------------------------------------------------
;;;; Tests: pi-reload (warm, cold, NOSUFFIX vs stale bytecode, order,
;;;; preflight)
;;;; ------------------------------------------------------------------

(ert-deftest refactor/pi-reload-order-matches-actual-require-graph ()
  "The reload list must cover the real checkout and put every internal
require earlier than its dependent; the Evil adapter stays conditional."
  (let ((real (test--pilish-real-source-dir)))
    (skip-unless real)
    (let* ((declared (test--pi-reload-declared-files))
           (graph (test--pilish-real-require-graph real))
           (pos (lambda (f) (cl-position f declared :test #'equal))))
      ;; every real module except the Evil adapter appears exactly once
      (dolist (entry graph)
        (unless (equal (car entry) "pilish-evil.el")
          (should (member (car entry) declared))
          (should (= (cl-count (car entry) declared :test #'equal) 1))))
      ;; dependency order: every internal require precedes its dependent
      (dolist (entry graph)
        (dolist (req (cdr entry))
          (let ((reqfile (concat req ".el")))
            (should (member reqfile declared))
            (should (< (funcall pos reqfile)
                       (or (funcall pos (car entry))
                           (length declared)))))))
      ;; Evil adapter: conditional, mentioned explicitly, loaded last
      (should-not (member "pilish-evil.el" declared))
      (should (test--form-mentions
               (test--find-defun 'pi-reload (test--file-forms test--pilish-config))
               "pilish-evil.el")))))

(ert-deftest refactor/pi-reload-is-source-explicit-with-nosuffix ()
  "The new pi-reload must load explicit absolute .el files with load's
NOSUFFIX flag and derive paths from the shared source dir (not the old
hardcoded home path)."
  (let* ((defun (test--find-defun 'pi-reload (test--file-forms test--pilish-config)))
         (loadform (test--nosuffix-load-form defun)))
    (should defun)
    (should loadform)                       ; (load path nil t t)
    (should (test--form-mentions defun '+sayre-pilish-source-dir))
    (should-not (test--form-mentions defun "site-lisp"))
    (should-not (test--form-mentions defun "~/.config"))
    ;; preflight: a dolist readability loop guards the loads and raises a
    ;; user-error naming the missing file before any load happens
    (let ((preflight (test--deep-collect
                      (lambda (x)
                        (and (eq (car-safe x) 'dolist)
                             (test--deep-collect
                              (lambda (y) (eq (car-safe y) 'user-error))
                              (list x))))
                      (list defun))))
      (should preflight)
      (should (cl-some (lambda (s)
                         (and (stringp s)
                              (string-match-p "Missing Pilish source" s)))
                       (test--deep-strings defun))))
    ;; the intended exception: the old baseline defun must differ
    (skip-unless test--baseline-config)
    (let ((old (test--find-defun 'pi-reload (test--file-forms-safe test--baseline-config))))
      (skip-unless old)
      (should-not (equal old defun)))))

(ert-deftest refactor/pi-reload-warm-reload-beats-stale-bytecode ()
  "Warm reload: with disposable stale .elc siblings for all files,
pi-reload must restore fresh source definitions for the full 14-file
ordered set (Evil adapter last), via load NOSUFFIX."
  (let ((real (test--pilish-real-source-dir)))
    (skip-unless real)
    (let* ((graph (test--pilish-real-require-graph real))
           (root (test--fresh-root))
           (srcdir (expand-file-name "sources/pilish" root))
           (expected (append (test--pi-reload-declared-files) '("pilish-evil.el"))))
      (make-directory srcdir t)
      ;; generation 0: stale bytecode for every fixture file
      (test--write-pilish-fixtures srcdir graph t)
      (test--compile-fixtures srcdir)
      (should (= (length (directory-files srcdir nil "\\.elc\\'"))
                 (length graph)))
      ;; generation 1: distinct fresh source content (same filenames)
      (test--write-pilish-fixtures srcdir graph nil)
      ;; load the REAL module config (defines pi-reload from actual source)
      (let ((doom-user-dir root))
        (load test--pilish-config nil t t))
      ;; control: without NOSUFFIX the stale bytecode would win
      (load (expand-file-name "pilish-core" srcdir) nil t)
      (should (string-prefix-p "STALE-BYTECODE pilish-core"
                               (documentation 'pilish-fixture--probe)))
      ;; warm reload with Evil present: all 14 files, source stamps win
      (provide 'evil)
      (setq pilish-fixture-load-record nil)
      (pi-reload)
      (should (equal pilish-fixture-load-record expected))
      (should (string-prefix-p "FRESH-SOURCE pilish-evil"
                               (documentation 'pilish-fixture--probe)))
      (should (eq (pilish-fixture--probe) 'pilish-evil))
      (should (equal (file-truename (symbol-file 'pilish-fixture--probe))
                     (file-truename (expand-file-name "pilish-evil.el" srcdir))))
      ;; preflight: a missing file aborts before ANY load (record unchanged)
      (let ((before pilish-fixture-load-record)
            (victim (expand-file-name "pilish-render.el" srcdir))
            err)
        (rename-file victim (concat victim ".hidden"))
        (condition-case e
            (pi-reload)
          (user-error (setq err (error-message-string e))))
        (should err)
        (should (string-match-p "Missing Pilish source" err))
        (should (string-match-p (regexp-quote victim) err))
        (should (equal pilish-fixture-load-record before))
        (rename-file (concat victim ".hidden") victim)))))

(ert-deftest refactor/pi-reload-cold-in-fresh-process ()
  "Cold invocation in a clean emacs -Q subprocess: no prior Pilish state,
no Evil feature; all 13 unconditional files load in declared order from
fresh sources, stale .elc siblings never win."
  (let ((real (test--pilish-real-source-dir)))
    (skip-unless real)
    (let* ((graph (test--pilish-real-require-graph real))
           (root (test--fresh-root))
           (srcdir (expand-file-name "sources/pilish" root))
           (result (expand-file-name "result.sexp" root))
           (script (expand-file-name "cold-runner.el" root)))
      (make-directory srcdir t)
      (test--write-pilish-fixtures srcdir graph t)
      (test--compile-fixtures srcdir)
      (test--write-pilish-fixtures srcdir graph nil)
      (with-temp-file script
        (insert (format "(load %S nil t t)\n" (file-truename test--this-file)))
        (insert (format "(setq doom-user-dir %S)\n" root))
        (insert (format "(load %S nil t t)\n" (file-truename test--pilish-shared)))
        (insert (format "(eval (test--find-defun 'pi-reload (test--file-forms %S)) t)\n"
                        (file-truename test--pilish-config)))
        (insert "(cl-assert (not (featurep 'evil)) t)\n")
        (insert "(cl-assert (not (featurep 'pilish)) t)\n")
        (insert "(setq pilish-fixture-load-record nil)\n")
        (insert "(pi-reload)\n")
        (insert (format "(with-temp-file %S\n" result))
        (insert "  (prin1 (list pilish-fixture-load-record\n")
        (insert "          (documentation 'pilish-fixture--probe)\n")
        (insert "          (file-truename (symbol-file 'pilish-fixture--probe))\n")
        (insert (format "          (cl-assoc-if\n           (lambda (f)\n             (and (stringp f) (string-prefix-p %S f) (string-match-p \"\\\\.elc\\\\'\" f)))\n           load-history)\n" srcdir))
        (insert "  )\n")
        (insert "  (current-buffer)))\n"))
      (let* ((emacs-bin (expand-file-name invocation-name invocation-directory))
             (stderr (expand-file-name "cold-stderr.log" root))
             (status (call-process emacs-bin nil (list nil stderr) nil
                                   "-Q" "--batch" "-l" script)))
        (should (= status 0))
        (let ((res (with-temp-buffer
                     (insert-file-contents result)
                     (read (current-buffer)))))
          (should (equal (nth 0 res) (test--pi-reload-declared-files)))
          (should (string-prefix-p "FRESH-SOURCE pilish" (nth 1 res)))
          (should (equal (nth 2 res)
                         (file-truename (expand-file-name "pilish.el" srcdir))))
          (should (null (nth 3 res))))))))

;;;; ------------------------------------------------------------------
;;;; Tests: Pilish manifest (missing-source preflight before package!,
;;;; success registration, duplicated engine/md-ts recipes)
;;;; ------------------------------------------------------------------

(defun test--load-manifest (file &optional root)
  "Load a manifest FILE with stubs; return (:forms ... :error ...)."
  (let* ((test--package!-forms nil)
         (test--skipped-loads nil)
         (doom-user-dir (or root test--doom-dir))
         err)
    (condition-case e
        (load file nil t t)
      (error (setq err (error-message-string e))))
    (list :forms test--package!-forms :error err :skipped test--skipped-loads)))

(ert-deftest refactor/manifest-missing-source-fails-before-package-registration ()
  "A missing sources/pilish entry must error with a clear message BEFORE
any package! recipe is registered."
  (let* ((root (test--fresh-root))
         (res (test--load-manifest test--pilish-packages root)))
    (should (plist-get res :error))
    (should (string-match-p "Missing Pilish source" (plist-get res :error)))
    (should (string-match-p
             (regexp-quote (expand-file-name "sources/pilish/pilish.el" root))
             (plist-get res :error)))
    (should (null (plist-get res :forms)))))

(ert-deftest refactor/manifest-registers-local-package-with-evaluated-source-path ()
  "With the source present, the manifest registers pilish, then the two
shared dependencies; the local recipe evaluates to the real absolute
source path (a value, not a quoted symbol), with compilation skipped."
  (skip-unless (file-exists-p test--pins-file))
  (let* ((root (test--fresh-root))
         (srcdir (expand-file-name "sources/pilish" root)))
    (make-directory srcdir t)
    (write-region "" nil (expand-file-name "pilish.el" srcdir) nil 'silent)
    (let ((res (test--load-manifest test--pilish-packages root)))
      (should (null (plist-get res :error)))
      (should (equal (mapcar #'car (plist-get res :forms))
                     '(pilish markdown-table-wrap md-ts-mode)))
      (let* ((form (assq 'pilish (plist-get res :forms)))
             (recipe (eval (plist-get (cdr form) :recipe) t)))
        (should recipe)
        (should (null (plist-get recipe :type)))
        (should (equal (plist-get recipe :local-repo)
                       (file-name-as-directory srcdir)))
        (should (equal (plist-get recipe :files) '("pilish*.el")))
        (should (equal (plist-get recipe :build) '(:not compile native-compile)))))))

(ert-deftest refactor/manifests-share-identical-engine-and-md-ts-recipes ()
  "The duplicated markdown-table-wrap and md-ts-mode declarations in the
table-pretty and pilish manifests must be identical (same pins, same
recipes, same pretty-companion exclusion), and yank-rich/table-pretty
must share the emacs-world pin."
  (let* ((root (test--fresh-root))
         (srcdir (expand-file-name "sources/pilish" root)))
    (make-directory srcdir t)
    (write-region "" nil (expand-file-name "pilish.el" srcdir) nil 'silent)
    (let ((table (test--load-manifest test--table-packages root))
          (pilish (test--load-manifest test--pilish-packages root))
          (yank (test--load-manifest test--yank-packages root)))
      (should (null (plist-get table :error)))
      (should (null (plist-get pilish :error)))
      (should (null (plist-get yank :error)))
      (dolist (pkg '(markdown-table-wrap md-ts-mode))
        (let ((tf (assq pkg (plist-get table :forms)))
              (pf (assq pkg (plist-get pilish :forms))))
          (should tf)
          (should pf)
          (should (equal (plist-get (cdr tf) :pin) (plist-get (cdr pf) :pin)))
          (should (equal (plist-get (cdr tf) :recipe) (plist-get (cdr pf) :recipe)))))
      ;; only the engine recipe deliberately excludes the upstream pretty
      ;; companion renderer, in both manifests
      (dolist (forms (list (plist-get table :forms) (plist-get pilish :forms)))
        (should (member '(:exclude "markdown-table-wrap-pretty.el")
                        (plist-get (plist-get (cdr (assq 'markdown-table-wrap forms)) :recipe) :files))))
      (should (equal (plist-get (cdr (assq 'yank-rich (plist-get yank :forms))) :pin)
                     (plist-get (cdr (assq 'table-pretty (plist-get table :forms))) :pin)))
      ;; once pins.el exists, the evaluated pins must be full 40-hex SHAs
      ;; and agree across both manifests
      (when (file-exists-p test--pins-file)
        (dolist (pkg '(markdown-table-wrap md-ts-mode))
          (let ((pin (eval (plist-get (cdr (assq pkg (plist-get table :forms))) :pin) t)))
            (should (stringp pin))
            (should (= (length pin) 40))
            (should (string-match-p "\\`[[:xdigit:]]\\{40\\}\\'" pin))
            (should (equal pin (eval (plist-get (cdr (assq pkg (plist-get pilish :forms))) :pin) t)))))))))

;;;; ------------------------------------------------------------------
;;;; Tests: Pilish doctor (selected backend, missing source)
;;;; ------------------------------------------------------------------

(ert-deftest refactor/pilish-doctor-flags-selected-pi-missing-source-both ()
  "With pi unavailable but omp present, doctor must warn about the
SELECTED backend (not accept the alternate), and must also warn about a
missing source checkout; exactly those two diagnostics."
  (let* ((root (test--fresh-root))
         (bindir (make-temp-file "refactor-test-bin-" t))
         (srcdir (expand-file-name "sources/pilish" root)))
    ;; no pilish.el in srcdir; omp exists on PATH, pi does not
    (test--make-fake-executable (expand-file-name "omp" bindir))
    (let ((test--warnings nil)
          (doom-user-dir root)
          (exec-path (list bindir)))
      (makunbound 'pilish-executable)   ; config.el not loaded by doctor
      (load test--pilish-doctor nil t t)
      (should (= (length test--warnings) 2))
      (should (cl-some (lambda (w) (string-match-p "Missing Pilish checkout" w))
                       test--warnings))
      (let ((sel (cl-some (lambda (w) (and (string-match-p
                                            "Selected Pilish backend is unavailable" w)
                                           w))
                          test--warnings)))
        (should sel)
        (should (string-match-p "(\"pi\")" sel))
        (should (string-match-p "alternate backend does not satisfy" sel))))))

(ert-deftest refactor/pilish-doctor-validates-selected-not-default-backend ()
  "When a custom backend is selected (omp), doctor judges THAT program:
omp missing must warn even though the pi default is available."
  (let* ((root (test--fresh-root))
         (bindir (make-temp-file "refactor-test-bin-" t))
         (srcdir (expand-file-name "sources/pilish" root)))
    (make-directory srcdir t)
    (write-region "" nil (expand-file-name "pilish.el" srcdir) nil 'silent)
    (test--make-fake-executable (expand-file-name "pi" bindir))
    (let ((test--warnings nil)
          (doom-user-dir root)
          (exec-path (list bindir))
          (pilish-executable '("omp")))
      (load test--pilish-doctor nil t t)
      (should (= (length test--warnings) 1))
      (should (string-match-p "Selected Pilish backend is unavailable"
                              (car test--warnings)))
      (should (string-match-p "omp" (car test--warnings))))))

(ert-deftest refactor/pilish-doctor-silent-when-healthy-and-invalid-command-flagged ()
  "A healthy checkout + selected pi available produces no warnings; an
invalid configured command is flagged as invalid."
  (let* ((root (test--fresh-root))
         (bindir (make-temp-file "refactor-test-bin-" t))
         (srcdir (expand-file-name "sources/pilish" root)))
    (make-directory srcdir t)
    (write-region "" nil (expand-file-name "pilish.el" srcdir) nil 'silent)
    (test--make-fake-executable (expand-file-name "pi" bindir))
    (let ((test--warnings nil)
          (doom-user-dir root)
          (exec-path (list bindir)))
      (makunbound 'pilish-executable)
      (load test--pilish-doctor nil t t)
      (should (null test--warnings)))
    ;; invalid configured command
    (let ((test--warnings nil)
          (doom-user-dir root)
          (exec-path (list bindir))
          (pilish-executable '("")))
      (load test--pilish-doctor nil t t)
      (should (= (length test--warnings) 1))
      (should (string-match-p "Invalid configured pilish-executable"
                              (car test--warnings))))))

;;;; ------------------------------------------------------------------
;;;; Tests: diagrams (exact executable runtime/doctor agreement; Org
;;;; general preferences stay root-owned)
;;;; ------------------------------------------------------------------

(defun test--setq-forms-for (forms sym)
  "Collect every (setq SYM ...) form in FORMS, searched recursively."
  (test--deep-collect
   (lambda (x) (and (eq (car-safe x) 'setq) (eq (cadr x) sym)))
   forms))

(ert-deftest refactor/diagrams-runtime-uses-shared-executable-and-popup-rules ()
  "The diagrams config must wire ob-mermaid to the exact shared constant,
add the .puml association, the PLANTUML popup exception, and the folding
hook - all from the real module source."
  (load test--diagrams-shared nil t t)
  (should (file-name-absolute-p +sayre-mermaid-command))
  (let ((test--popup-rules nil))
    (load test--diagrams-config nil t t)
    (should (equal ob-mermaid-cli-path +sayre-mermaid-command))
    (should (fboundp '+org/fold-diagram-src-blocks))
    (should (memq #'+org/fold-diagram-src-blocks org-mode-hook))
    (should (equal (cdr (assoc "\\.puml\\'" auto-mode-alist)) 'plantuml-mode))
    (should (member '("^\\*PLANTUML" :ignore t) test--popup-rules))
    ;; the module must not touch the general Org preferences
    (should (null (test--setq-forms-for
                   (test--file-forms test--diagrams-config)
                   'org-element-use-cache)))
    (should (null (test--setq-forms-for
                   (test--file-forms test--diagrams-config)
                   'org-startup-with-inline-images)))))

(ert-deftest refactor/diagrams-doctor-checks-configured-path-not-path-lookup ()
  "Doctor consults the exact configured executable from shared.el, not a
PATH lookup: with the configured path executable, doctor is silent even
with an empty PATH; with it not executable, the warning names the exact
configured path."
  (load test--diagrams-shared nil t t)
  (let* ((tmp (make-temp-file "refactor-test-mmdc-" t))
         (mmdc (expand-file-name "mmdc" tmp))
         (test--idempotent-loads t))
    ;; available at the exact configured path, absent from PATH: no warning
    (write-region "" nil mmdc nil 'silent)
    (set-file-modes mmdc #o755)
    (let ((test--warnings nil)
          (exec-path nil)
          (+sayre-mermaid-command mmdc))
      (load test--diagrams-doctor nil t t)
      (should (null test--warnings)))
    ;; not executable at the configured path (and absent from PATH):
    ;; a warning naming the exact configured path
    (set-file-modes mmdc #o644)
    (let ((test--warnings nil)
          (exec-path nil)
          (+sayre-mermaid-command mmdc))
      (load test--diagrams-doctor nil t t)
      (should (= (length test--warnings) 1))
      (should (string-match-p (regexp-quote mmdc) (car test--warnings)))
      (should (string-match-p "Configured Mermaid executable is unavailable"
                              (car test--warnings))))))

(ert-deftest refactor/org-general-preferences-stay-root-owned ()
  "org-element-use-cache and org-startup-with-inline-images must live in
root config (baseline and live), never in the diagrams module, so they
do not depend on enabling diagrams."
  ;; module ownership: absent from diagrams/config.el
  (let ((module-forms (test--file-forms test--diagrams-config)))
    (should (null (test--setq-forms-for module-forms 'org-element-use-cache)))
    (should (null (test--setq-forms-for module-forms 'org-startup-with-inline-images))))
  ;; baseline anchor
  (skip-unless test--baseline-config)
  (let ((base (test--file-forms-safe test--baseline-config)))
    (skip-unless base)
    (let ((cache (test--setq-forms-for base 'org-element-use-cache))
          (images (test--setq-forms-for base 'org-startup-with-inline-images)))
      (should (member '(setq org-element-use-cache nil) cache))
      (should (member '(setq org-startup-with-inline-images t) images))))
  ;; live root must keep them (skips explicitly if unreadable mid-edit)
  (let ((live (test--file-forms-safe test--root-config)))
    (if (null live)
        (ert-skip "live root config.el unreadable (possibly a concurrent edit)")
      (should (test--setq-forms-for live 'org-element-use-cache))
      (should (test--setq-forms-for live 'org-startup-with-inline-images)))))

;;;; ------------------------------------------------------------------
;;;; Tests: vterm (reuse, prefix delegation, module guard)
;;;; ------------------------------------------------------------------

(defvar test--fake-vterm-buffers nil)

(ert-deftest refactor/vterm-module-guard-fails-without-term-vterm ()
  "Loading the module config with :term vterm disabled must fail with a
clear message naming the prerequisite."
  (let ((test--modulep-table '((:term vterm . nil)))
        err)
    (condition-case e
        (load test--vterm-config nil t t)
      (error (setq err (error-message-string e))))
    (should err)
    (should (string-match-p ":term vterm" err))))

(defmacro test--with-vterm-spies (&rest body)
  "Run BODY with terminal/display machinery stubbed: no terminal can be
started; spies record reuse vs delegation decisions."
  (declare (indent 0))
  `(let* ((here-calls nil)
          (pop-calls nil)
          (test--fake-vterm-buffers nil)
          (display-buffer-alist '(("\\`\\*vterm" . display-buffer-below-selected))))
     (cl-letf* (((symbol-function 'doom-buffers-in-mode)
                 (lambda (_modes &optional buffer-list _predicate)
                   (cl-remove-if-not
                    (lambda (b) (provided-mode-derived-p
                                 (buffer-local-value 'major-mode b) 'vterm-mode))
                    (or buffer-list test--fake-vterm-buffers))))
                ((symbol-function '+vterm/here)
                 (lambda (&rest args)
                   (interactive "P")
                   (push (list args current-prefix-arg) here-calls)))
                ((symbol-function 'pop-to-buffer-same-window)
                 (lambda (b) (push (list b display-buffer-alist) pop-calls))))
       ,@body
       (list :here (nreverse here-calls)
             :pop (nreverse pop-calls)))))

(defun test--fake-vterm-buffer (name)
  (let ((buf (get-buffer-create name)))
    (with-current-buffer buf (setq major-mode 'vterm-mode))
    (push buf test--fake-vterm-buffers)
    buf))

(ert-deftest refactor/vterm-here-reuses-undisplayed-buffer-and-suppresses-popups ()
  "SPC o T must switch to an existing undisplayed vterm buffer in the
same window with display-buffer-alist suppressed, without spawning a
terminal or delegating."
  (load test--vterm-config nil t t)
  (should (member '("^\\*vterm\\*" :ignore t) test--popup-rules))
  (let ((hidden (get-buffer-create " *refactor-test-vterm-hidden*")))
    (with-current-buffer hidden (setq major-mode 'vterm-mode))
    (unwind-protect
        (let ((res (test--with-vterm-spies
                     (let ((test--fake-vterm-buffers (list hidden)))
                       (my/vterm-here)))))
          (should (null (plist-get res :here)))
          (should (= (length (plist-get res :pop)) 1))
          (let ((entry (car (plist-get res :pop))))
            (should (eq (car entry) hidden))
            ;; display-buffer-alist was let-bound to nil inside the reuse
            ;; branch (the popup rule could not hijack the switch)
            (should (null (cadr entry)))))
      (kill-buffer hidden))))

(ert-deftest refactor/vterm-here-delegates-on-prefix-displayed-or-doom-named ()
  "With a prefix arg, a displayed vterm buffer, or only *doom:-prefixed
buffers, my/vterm-here must fall through to +vterm/here."
  (load test--vterm-config nil t t)
  ;; prefix arg delegates
  (let* ((res (test--with-vterm-spies
                (my/vterm-here '(4)))))
    (should (= (length (plist-get res :here)) 1))
    (should (null (plist-get res :pop))))
  ;; displayed buffer delegates (reuse requires an undisplayed buffer)
  (let* ((res (test--with-vterm-spies
                (cl-letf (((symbol-function 'get-buffer-window-list)
                           (lambda (_buf &optional _n _a) (list 'fake-window))))
                  (let ((buf (test--fake-vterm-buffer " *refactor-test-vterm-displayed*")))
                    (my/vterm-here))
                  (kill-buffer (car test--fake-vterm-buffers))))))
    (should (= (length (plist-get res :here)) 1))
    (should (null (plist-get res :pop))))
  ;; a *doom: popup-style vterm is never a reuse candidate
  (let* ((res (test--with-vterm-spies
                (let ((buf (test--fake-vterm-buffer "*doom:vterm-refactor-test*")))
                  (my/vterm-here))
                (kill-buffer (car test--fake-vterm-buffers)))))
    (should (= (length (plist-get res :here)) 1))
    (should (null (plist-get res :pop)))))

;;;; ------------------------------------------------------------------
;;;; Tests: backend transitions
;;;; ------------------------------------------------------------------

(ert-deftest refactor/pilish-backend-transitions-preserve-trust-policy ()
  "From the pi/default start: toggle gives omp/default; toggling again
gives pi/approve; a prefix arg forces pi.  The actual module defun is
evaluated, not a copy."
  (let ((doom-user-dir (test--fresh-root)))
    (load test--pilish-config nil t t))
  (should (fboundp 'my/pilish-toggle-backend))
  (let ((pilish-executable (copy-sequence +sayre-pilish-default-command))
        (pilish-project-trust-policy 'default))
    ;; pi/default -> omp/default
    (my/pilish-toggle-backend)
    (should (equal pilish-executable '("omp")))
    (should (eq pilish-project-trust-policy 'default))
    ;; omp/default -> pi/approve
    (my/pilish-toggle-backend)
    (should (equal pilish-executable '("pi")))
    (should (eq pilish-project-trust-policy 'approve))
    ;; prefix forces pi again
    (my/pilish-toggle-backend '(4))
    (should (equal pilish-executable '("pi")))
    (should (eq pilish-project-trust-policy 'approve))))

;;;; ------------------------------------------------------------------
;;;; Tests: preservation against the baseline backup
;;;; ------------------------------------------------------------------

(defun test--baseline-forms-safe ()
  (and test--baseline-config
       (test--file-forms-safe test--baseline-config)))

(defun test--map-forms-mentioning (forms what)
  (cl-remove-if-not
   (lambda (f) (test--form-mentions f what))
   (test--collect-head 'map! forms)))

(ert-deftest refactor/table-module-preserves-all-six-map-forms ()
  "All six table map! forms (leader, two localleaders, two vanilla keys,
chat binding) survive into the module and match the baseline verbatim."
  (let ((module (test--map-forms-mentioning
                 (test--file-forms test--table-config) 'my/table-pretty-toggle)))
    (should (= (length module) 6))
    (let ((base (test--baseline-forms-safe)))
      (skip-unless base)
      (should (test--multiset-equal
               module
               (test--map-forms-mentioning base 'my/table-pretty-toggle))))))

(ert-deftest refactor/pilish-module-preserves-all-four-add-hook-forms ()
  "All four Pilish add-hook forms (chat real-buffer, chat/input line
numbers, chat header-line) survive into the module and match baseline."
  (let ((pred (lambda (f) (or (test--form-mentions f 'pilish-chat-mode-hook)
                              (test--form-mentions f 'pilish-input-mode-hook)))))
    (let ((module (cl-remove-if-not
                   pred
                   (test--collect-head 'add-hook (test--file-forms test--pilish-config)))))
      (should (= (length module) 4))
      (let ((base (test--baseline-forms-safe)))
        (skip-unless base)
        (should (test--multiset-equal
                 module
                 (cl-remove-if-not pred (test--collect-head 'add-hook base))))))))

(ert-deftest refactor/moved-defuns-unchanged-vs-baseline ()
  "Every moved defun must equal its baseline original; only pi-reload is
the intended exception (already covered by its own test)."
  (let ((base (test--baseline-forms-safe)))
    (skip-unless base)
    (dolist (pair (list (cons 'my/vterm-here test--vterm-config)
                        (cons 'my/pilish-toggle-backend test--pilish-config)
                        (cons 'my/table-pretty-toggle test--table-config)
                        (cons 'my/table-pretty-maybe-enable test--table-config)
                        (cons '+org/fold-diagram-src-blocks test--diagrams-config)))
      (let ((old (test--find-defun (car pair) base))
            (new (test--find-defun (car pair) (test--file-forms (cdr pair)))))
        (should old)
        (should new)
        (should (equal old new)))))
  ;; the shared Shift-Return helper stays in root config, unchanged
  (let ((live (test--file-forms-safe test--root-config)))
    (if (null live)
        (ert-skip "live root config.el unreadable (possibly a concurrent edit)")
      (let ((old (test--find-defun '+my/find-file-at-point-other-window
                                   (test--baseline-forms-safe)))
            (new (test--find-defun '+my/find-file-at-point-other-window live)))
        (should old)
        (should new)
        (should (equal old new))))))

(ert-deftest refactor/yank-rich-bindings-and-which-key-labels-preserved ()
  "The gy map! forms and the which-key replacements (including the
literal Unicode-ellipsis label) match the baseline exactly."
  (let ((base (test--baseline-forms-safe)))
    (skip-unless base)
    (let* ((pred (lambda (f) (or (test--form-mentions f 'yank-rich)
                                 (test--form-mentions f 'yank-plain)
                                 (test--form-mentions f "gy"))))
           (module-map (cl-remove-if-not pred
                                         (test--collect-head 'map!
                                                             (test--file-forms test--yank-config))))
           (base-map (cl-remove-if-not pred (test--collect-head 'map! base))))
      (should module-map)
      (should (test--multiset-equal module-map base-map)))
    ;; which-key replacements form identical (labels preserved verbatim)
    (let ((module-wk (test--collect-head 'which-key-add-key-based-replacements
                                         (test--file-forms test--yank-config)))
          (base-wk (test--collect-head 'which-key-add-key-based-replacements base)))
      (should module-wk)
      (should (test--multiset-equal module-wk base-wk))
      ;; the literal ellipsis label, character-exact in both sources
      (should (cl-some (lambda (s) (equal s "yank-as…"))
                       (test--deep-strings module-wk)))
      (should (cl-some (lambda (s) (equal s "yank-as…"))
                       (test--deep-strings base-wk))))))

;;;; ------------------------------------------------------------------
;;;; Tests: shared pins file (skips until the parent writes pins.el)
;;;; ------------------------------------------------------------------

(ert-deftest refactor/pins-define-three-validated-revisions ()
  "pins.el, once written, defines all three revision constants as full
40-hex SHAs and self-validates them."
  (skip-unless (file-exists-p test--pins-file))
  (let ((doom-user-dir test--doom-dir))
    (load test--pins-file nil t t))
  (dolist (var '(+sayre-emacs-world-revision +sayre-md-ts-revision
                 +sayre-table-engine-revision))
    (should (boundp var))
    (should (stringp (symbol-value var)))
    (should (= (length (symbol-value var)) 40))
    (should (string-match-p "\\`[[:xdigit:]]\\{40\\}\\'" (symbol-value var)))))

(provide 'refactor-tests)
;;; refactor-tests.el ends here
