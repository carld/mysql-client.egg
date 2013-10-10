(use mysql-client lolevel)

(define mysql
  (make-mysql-connection "localhost" "root" #f "information_schema"))

(if (not (pointer? (mysql (lambda(c . a) c))))
  (error "closure did not dispatch connection object"))

(define-syntax exec-sql
  (syntax-rules ()
    ((_ sql ...)
     (begin
       ((mysql sql ...) (lambda r (printf "~A~%" r)))))))

(define-syntax assert-mysql-error
  (syntax-rules ()
    ((_ code ...)
     (assert (condition-case
              (begin code ... #f)
              ((exn mysql) #t))))))

(assert-mysql-error (exec-sql "gibberish"))

(exec-sql "CREATE DATABASE IF NOT EXISTS chicken_scheme_mysql_client_test")
(exec-sql "USE chicken_scheme_mysql_client_test")
(exec-sql
#<#SQL
  CREATE TEMPORARY TABLE IF NOT EXISTS `scheme_test` (
    `created_at`   TIMESTAMP,
    `name`         VARCHAR(32)
  )
SQL
)
(exec-sql "INSERT INTO scheme_test (created_at, name) VALUES (NOW(), '$name')" 
          '(($name . "hell'o1")))
(exec-sql "INSERT INTO scheme_test (created_at, name) VALUES (NOW(), '$name')" 
          '(($name . "hello%2")))
(exec-sql "INSERT INTO scheme_test (created_at, name) VALUES (NOW(), NULL)") 
(exec-sql "SELECT * FROM scheme_test")
(assert (mysql-null? "(NULL)"))

(let ((result '()))
  ((mysql "SELECT name FROM scheme_test ORDER BY name")
   (lambda (r)
     (set! result (cons (car r) result))))
  (assert (equal? result '("hello%2" "hell'o1" "(NULL)"))))

(mysql-null "(ANOTHER NULL)")
(assert (mysql-null? "(ANOTHER NULL)"))
(let ((result '()))
  ((mysql "SELECT name FROM scheme_test ORDER BY name")
   (lambda (r)
     (set! result (cons (car r) result))))
  (assert (equal? result '("hello%2" "hell'o1" "(ANOTHER NULL)"))))

(exec-sql "USE information_schema")
(exec-sql "DROP DATABASE chicken_scheme_mysql_client_test")
