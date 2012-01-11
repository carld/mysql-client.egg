(require-library mysql)

(define mysql (make-mysql-connection "localhost" "root" "" "information_schema"))
(define fetch (mysql "select * from schemata;"))
(pp (fetch))
(pp (fetch))
(pp (fetch))
(pp (fetch))
(pp (fetch))


