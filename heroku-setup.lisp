(in-package :cl-user)

(print ">>> Building system....")

(asdf:clear-system "wuwei")
(asdf:clear-system "wuwei-examples")

(trace load)

(load (make-pathname :directory *build-dir* :defaults "wuwei.asd"))

(ql:quickload :wuwei-examples)

(trace wu::wuwei-initialize-application wu::locate-public-directory cl-user::initialize-application)

(print ">>> Done building system")
