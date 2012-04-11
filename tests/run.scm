(use mysql-client)

(define mysql 
  (make-mysql-connection "localhost" "root" "" "information_schema"))
(define (fetch-loop)
  (let ((row (fetch)))
    (if row
      (begin
        (printf "~A~%" row)
        (fetch-loop)))))

