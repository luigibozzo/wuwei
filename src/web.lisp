(in-package :wu)

;;; +=========================================================================+
;;; | Copyright (c) 2009, 2010  Mike Travers and CollabRx, Inc                |
;;; |                                                                         |
;;; | Released under the MIT Open Source License                              |
;;; |   http://www.opensource.org/licenses/mit-license.php                    |
;;; |                                                                         |
;;; | Permission is hereby granted, free of charge, to any person obtaining   |
;;; | a copy of this software and associated documentation files (the         |
;;; | "Software"), to deal in the Software without restriction, including     |
;;; | without limitation the rights to use, copy, modify, merge, publish,     |
;;; | distribute, sublicense, and/or sell copies of the Software, and to      |
;;; | permit persons to whom the Software is furnished to do so, subject to   |
;;; | the following conditions:                                               |
;;; |                                                                         |
;;; | The above copyright notice and this permission notice shall be included |
;;; | in all copies or substantial portions of the Software.                  |
;;; |                                                                         |
;;; | THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,         |
;;; | EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF      |
;;; | MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  |
;;; | IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY    |
;;; | CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,    |
;;; | TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE       |
;;; | SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                  |
;;; +=========================================================================+

;;; Author:  Mike Travers

(export '(*public-directory* locate-public-directory public-url image-url
	  
	  javascript-include javascript-includes css-include css-includes
	  with-http-response-and-body	  

	  render-update render-scripts
	  
	  html-string html-to-stream
	  html-escape-string clean-js-string

	  publish-ajax-update publish-ajax-func ajax-continuation 
	  *ajax-request* *within-render-update*

	  image-tag 
	  html-list
	  select-field

	  nbsp br html-princ

	  remote-function link-to
	  link-to-remote link-to-function
	  button-to-remote button-to-function
	  checkbox-to-function checkbox-to-remote
	  radio-buttons radio-to-remote

	  uploader *file-field-name*

	  async async-html

	  ))

;;; Basic web functions and infrastructure.  Stuff in this file should stand on its own (no prototype or other libraries required).

;;; Define a directory and path for public files

(defvar *public-directory* (make-pathname 
			    :name nil
			    :type nil
			    :version nil
			    :directory (append (butlast (pathname-directory #.(this-pathname))) '("public"))))

;;; Can be called at runtime to inform system where public files are.
(defun locate-public-directory (&optional directory)
  (when directory (setq *public-directory* directory))
  (format t "~%Wupub located at ~A" (truename *public-directory*))
  ;; +++ the expiry isn't working, hard to say why
  (publish-directory :destination (namestring *public-directory*)
		     :prefix "/wupub/"
		     :headers `(("Cache-control" . ,(format nil "max-age=~A, public" 36000))
				("Expires" . ,(net.aserve::universal-time-to-date (+ (get-universal-time) (* 20 60 60)))))
		     ))

;;; (locate-public-directory)  

(defun public-url (name)
  (string+ "/wupub/" name))

(defun image-url (img)
  (public-url (string+ "images/" (string img))))

;;; +++ kind of random rules
(defun coerce-url  (file-or-url)
  (if (or (string-prefix-equals file-or-url "http:")
	  (string-prefix-equals file-or-url "/"))
      file-or-url
      (public-url file-or-url)))

;;; +++ this needs a more flexible API...
(defun javascript-include (file-or-url)
  (html
   ((:script :type "text/javascript" :src (coerce-url file-or-url))) :newline ))

(defun javascript-includes (&rest files)
  (mapc #'javascript-include files))

(defun css-include (file-or-url)
  (html
    ((:link :rel "stylesheet" :type "text/css" :href  (coerce-url file-or-url)))))

(defun css-includes (&rest files)
  (mapc #'css-include files))
#|
Philosophy of this library: Things work via side effect (by using the HTML macro and associated machinery).

If you want a string, wrap the call with html-string.  For example:
(link-to (html-string (image-tag "logo_small.png"))
         "/")
|#



(defmacro html-to-stream (stream &body stuff)
  `(let ((*html-stream* ,stream))
     (html ,@stuff)))

(defmacro html-string (&body stuff)
  `(with-output-to-string (s)
     (html-to-stream s
		     ,@stuff)))

(defmacro maybe-to-string (to-string? &body body)
  `(if ,to-string?
       (html-string ,@body)
       (progn ,@body)))

;;; +++ should take same keywords as link-to-remote (ie html-options)
(defun link-to (text url &key target)
  (html ((:a :href url :if* target :target target)
         ;; :princ rather than :princ-safe to allow html embedding
         (:princ text))))

(defun image-tag (img &key alt border width height to-string?)
  (maybe-to-string to-string?
                   (html ((:img :src (image-url img)
                                :if* width :width width
                                :if* height :height height
                                :if* border :border border
                                :if* alt :alt alt
                                :if* alt :title alt
                                )))))

(defun break-lines (string)
  (string-replace string (string #\Newline) "<br/>"))

;;; convert lisp-style hyphenated string into camel case
(defun camel-case (string)
  (apply #'string+
         (mapcar #'string-capitalize
                 (string-split string #\-))))

;;; convert lisp-style hyphenated string into capitalized label
(defun labelify (string)
  (string-capitalize (substitute #\  #\- string)))

(defmacro html-princ (text)
  `(html
     (:princ-safe ,text)))

(defmacro nbsp ()
  `(html
     (:princ "&nbsp;")))

(defmacro br ()
  `(html :br))

(defmacro p ()
  `(html :p))

(defmacro nl ()
  `(html
     :newline))

(defmacro html-list (var)
  `(:ul
    ,@(loop for i in (eval var)
         collecting `(:li (:princ (symbol-name ,i))))))

;;; Options is list of (value label) pairs.  Separator is html to stick in-between options (ie, :br).
;;; +++ hm, wrapping something AROUND options would make more sense.
(defmacro radio-buttons (name options &key separator)
  `(dolist (option ,options)
     (html 
      ((:input :type :radio :name ,name :value (car option) :if* (third option) :checked "true") (:princ (cadr option)))
      ,separator)))
     
      
(defmacro with-http-response-and-body ((req ent &rest keys) &body body)
  #.(doc
     "Combines WITH-HTTP-RESPONSE and WITH-HTTP-BODY")
  `(with-http-response (,req ,ent ,@keys)
     (with-http-body (,req ,ent)
       ,@body)
     ))






