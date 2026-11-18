;;; pins.el --- Shared personal package revisions -*- lexical-binding: t; -*-

;; Both libraries share one repository checkout and must advance together.
;; Publish/test the authoring clone first, change this pin, then plain doom sync.
(defconst +sayre-emacs-world-revision
  "b3a8137e1c60af266ef0beaaebacb5d8c1d51ca5")
;; Pilish 3.4.5 requires md-ts-mode >= 0.5.0 (validated prerequisite).
(defconst +sayre-md-ts-revision
  "769ef52965c46e9346bf19d04adc6fef9d23b01c")
(defconst +sayre-table-engine-revision
  "f846b77d13f34fba57c80214c1a61e00c94048a3")

(dolist (revision (list +sayre-emacs-world-revision
                        +sayre-md-ts-revision
                        +sayre-table-engine-revision))
  (unless (string-match-p "\\`[[:xdigit:]]\\{40\\}\\'" revision)
    (error "Resolve and record the migration revision before sync: %S"
           revision)))
