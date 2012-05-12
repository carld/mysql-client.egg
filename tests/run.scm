(use mysql-client lolevel)

(define mysql 
  (make-mysql-connection "localhost" "root" #f "information_schema"))
(define fetch (mysql "select * from schemata"))
(define (fetch-loop)
  (let ((row (fetch)))
    (if row
      (begin
        (printf "~A~%" row)
        (fetch-loop)))))
(fetch-loop)

(if (not (pointer? (mysql (lambda(c . a) c))))
  (error "closure did not dispatch connection object"))

(define fetch2 
  (mysql "select * from tables where table_name = '$1' or table_name = '$foo'"
 '(($1 . "reads")($foo . "'unknown'"))))
(printf "~A~%" (fetch2))

