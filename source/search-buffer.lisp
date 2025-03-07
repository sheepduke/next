;;; search-buffer.lisp --- functions to enable searching within a webview

(in-package :next)

(define-parenscript initialize-search-buffer ()
  (ps:defvar current-search 0)
  (ps:defvar index 0)
  (defun insert (str index value)
    (+ (ps:chain str (substr 0 index)) value (ps:chain str (substr index)))))

;; TODO: Draw a box over the word instead?
(define-parenscript %add-search-hints (search-string)
  (defun create-search-span ()
    (setf index (+ 1 index))
    (ps:let* ((el (ps:chain document (create-element "span"))))
      (setf (ps:@ el class-name) "next-search-hint")
      (setf (ps:@ el style background) "rgba(255, 255, 255, 0.75)")
      (setf (ps:@ el style border) "1px solid red")
      (setf (ps:@ el style font-weight) "bold")
      (setf (ps:@ el style text-align) "center")
      (setf (ps:@ el text-content) index)
      ;; TODO: Ensure uniqueness of match IDs.
      (setf (ps:@ el id) index)
      el))

  ;; TODO: Ignore HTML comments.
  (ps:defun walk-dom (node proc)
    (when (and node (not (ps:chain node first-child)))
      (funcall proc node (ps:lisp search-string)))
    (setf node (ps:chain node first-child))
    (loop while node
          do (walk-dom node proc)
          do (setf node (ps:chain node next-sibling))))

  (ps:defun split-string-at (string regexp)
    "Like a regular split-string except that the matching regexp is included in the following string.
For instance
  (split-string-at \"foo@bar\" \"@\")
returns
  (\"foo\" \"@bar\")"
    (let* ((regex-string (ps:lisp search-string))
           (regex-flags "gi")
           (matcher (ps:new (-reg-exp regex-string regex-flags)))
           (last-match nil)
           (remaining ""))
      (loop with next-to-last-index = 0
            while (setf last-match (ps:chain matcher (exec string)))
            collect (ps:chain string (substring next-to-last-index (ps:chain last-match index))) into result
            do (setf next-to-last-index (ps:chain last-match index))
               (setf remaining (ps:chain string (substring (ps:chain last-match index))))
            finally (progn (ps:chain result (push remaining))
                           result))))

  (ps:defun insert-hint (node search-string)
    (let ((new-el (ps:chain document (create-element "span")))
          (fragments (split-string-at (ps:@ node text-content)
                                      (ps:lisp search-string))))
      (when  (< 1 (length fragments))
        (ps:chain new-el (append-child
                          (ps:chain document (create-text-node (ps:elt fragments 0)))))
        (loop for fragment in (ps:chain fragments (slice 1))
              do (ps:chain new-el (append-child (create-search-span)))
                 (ps:chain new-el (append-child
                                   (ps:chain document (create-text-node fragment)))))
        (ps:chain node (replace-with new-el)))))
  (walk-dom (ps:chain document body) insert-hint)
  nil)

(define-command add-search-hints ()
  "Add search boxes for a given search string."
  (initialize-search-buffer)
  (with-result (input (read-from-minibuffer
                       (minibuffer *interface*)
                       :input-prompt "Search for:"))
    (%add-search-hints :search-string input)))

(define-parenscript %remove-search-hints ()
  (defun qsa (context selector)
    "Alias of document.querySelectorAll"
    (ps:chain context (query-selector-all selector)))
  (defun search-hints-remove-all ()
    "Removes all the links"
    (ps:dolist (el (qsa document ".next-search-hint"))
      (ps:chain el (remove))))
  (search-hints-remove-all))

(define-command remove-search-hints ()
  "Remove all search hints."
  (%remove-search-hints))

(define-parenscript %next-search-hint ()
  (when (> index current-search)
    (setf current-search (+ current-search 1)))
  (let ((element (ps:chain document (get-element-by-id current-search))))
    (ps:chain element (scroll-into-view t))))

(define-command next-search-hint ()
  "Go to next search hint."
  (%next-search-hint))

(define-parenscript %previous-search-hint ()
  (when (> current-search 0)
    (setf current-search (- current-search 1)))
  (let ((element (ps:chain document (get-element-by-id current-search))))
    (ps:chain element (scroll-into-view t))))

(define-command previous-search-hint ()
  "Go to previous search hint."
  (%previous-search-hint))
