(use mysql-client lolevel)

(define mysql
  (make-mysql-connection "localhost" "root" #f "information_schema"))

(if (not (pointer? (mysql (lambda(c . a) c))))
  (error "closure did not dispatch connection object"))

(define-syntax exec-sql
  (syntax-rules ()
      ((_ sql ...) (begin 
                     ((mysql sql ...) (lambda r (printf "~A~%" r)))))))

(exec-sql "CREATE DATABASE IF NOT EXISTS chicken_scheme_mysql_client_test")
(exec-sql "USE chicken_scheme_mysql_client_test")
(exec-sql
#<#SQL
  CREATE TABLE IF NOT EXISTS `scheme_test` (
    `created_at`   TIMESTAMP,
    `name`         VARCHAR(32)
  )
SQL
)
(exec-sql "INSERT INTO scheme_test (created_at, name) VALUES (NOW(), '$name')" 
          '(($name . "hell'o1")))
(exec-sql "INSERT INTO scheme_test (created_at, name) VALUES (NOW(), '$name')" 
          '(($name . "hello%2")))
(exec-sql "SELECT * FROM scheme_test")
(exec-sql "DROP DATABASE chicken_scheme_mysql_client_test")
(exec-sql "USE information_schema")

