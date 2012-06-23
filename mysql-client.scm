; chicken-scheme  MySQL query procedure
; 
; To use:
;   (use mysql-client)
;   (define mysql (make-mysql-connection "host" "user" "pass" "schema"))
;   (define fetch (mysql "select * from messages"))
;   (fetch)
;
; Provide password as #f to use the password from the .my.cnf
; options file (/home/user/.my.cnf). 
;
; Example .my.cnf:
;
;   [client]
;   user=root
;   password=secret
;

(module mysql-client (make-mysql-connection mysql-null mysql-null?)
        (import scheme chicken foreign)
        (use irregex data-structures)

(define (make-mysql-connection host user pass database)
  (define mysql-c (make-mysql-c-connection host user pass database))
  (set-finalizer! mysql-c close-mysql-c-connection)

  (define (mysql-query query . parameters)
    (cond ((procedure? query)(mysql-query-with-proc mysql-c query parameters))
          ((string? query)   (mysql-query-with-string mysql-c query parameters))
          (else (error "unrecognised query object: " query))))
  mysql-query)

(define (mysql-query-with-proc mysql-c proc . parameters)
  (proc mysql-c parameters))

(define (mysql-query-with-string mysql-c query parameters)
  (cond ((null? parameters) (execute-query mysql-c query))
        ((pair? parameters) (execute-query mysql-c (escape-parameters mysql-c query (car parameters))))
        (else (error "unrecognised parameter object: " parameters))))

(define (execute-query mysql-c query)
  (define result-c (mysql-c-query mysql-c query))
  (set-finalizer! result-c mysql-c-free-result)
  (define (fetch . fetch-args)
    (cond ((null? fetch-args)
             (let ((row (mysql-c-fetch-row result-c)))
                  (if (pair? row) row #f)))
          ((pair? fetch-args)
             (fetch-loop result-c (car fetch-args)))))
  (if result-c fetch (lambda r #f)))

(define (fetch-loop result-c thunk)
  (let process ()
       (let ((row (mysql-c-fetch-row result-c)))
            (if (pair? row)
               (begin
                 (thunk row)
                 (process))))))

(define (make-irx parameters)
  (flatten (list 'or (map (lambda(x) (car x)) parameters))))

(define (stringify-keys parameters)
  (map (lambda(p)
         (cons (symbol->string(car p)) (cdr p))) parameters))

(define (escape-parameters mysql-c query parameters)
  (let ((stringified-keys (stringify-keys parameters)))
    (irregex-replace/all 
      (make-irx stringified-keys) 
      query 
      (lambda(r)
        (mysql-c-real-escape-string mysql-c 
          (alist-ref (irregex-match-substring r 0) stringified-keys string=?))))))

(define mysql-null (make-parameter "(NULL)"))

(define-external (mysql_null) c-string (mysql-null))

(define (mysql-null? field)
  (equal? (mysql-null) field))

(foreign-declare "#include \"mysql.h\"")

(define mysql-c-real-escape-string
  (foreign-lambda* c-string ((c-pointer conn) (c-string str))
#<<END
  char *dst = NULL;
  unsigned long len1 = 0, len2 = 0;
  len1 = strlen(str) * 2 + 1;
  dst = (char *)calloc(len1, sizeof(char));
  if (dst == NULL) {
    fprintf(stderr, "out of memory\n");
    return(NULL);
  }
  len2 = mysql_real_escape_string(conn, dst, str, strlen(str));
  return(dst);
END
))

(define mysql-c-fetch-row
  (foreign-safe-lambda* c-string-list* ((c-pointer result))
#<<END
  int num_fields = 0;
  int index = 0;
  MYSQL_ROW row = NULL;
  char **fields = NULL;
  if (result == NULL) {
    return(NULL);
  }
  num_fields = mysql_num_fields(result);
  index = num_fields;
  row = mysql_fetch_row(result);
  fields = (char **)calloc(num_fields + 1, sizeof(char *));
  if (fields == NULL) {
    fprintf(stderr, "out of memory\n");
    return(NULL);
  }
  for (;row && index--;) {
    if (row[index] == NULL)
      fields[index] = strdup(mysql_null());
    else
      fields[index] = strdup(row[index]);
  }
  return(fields);
END
))

(define mysql-c-free-result
  (foreign-primitive ((c-pointer result))
#<<END
  mysql_free_result(result);
END
))

(define mysql-c-query 
  (foreign-primitive c-pointer ((c-pointer conn) (c-string sql))
#<<END
  MYSQL_RES *result;

  fprintf (stderr, "MYSQL QUERY: %s\n", sql);

  int rc = mysql_query(conn, sql);

  if (mysql_errno(conn) != 0) {
    fprintf (stderr, "MYSQL ERROR: %d %s\n", 
            mysql_errno(conn), mysql_error(conn));
  }

  if (rc != 0) {
    return(NULL); /*C_return(C_SCHEME_FALSE);*/
  }

  result = mysql_store_result(conn);
  return(result);
END
))

(define close-mysql-c-connection 
  (foreign-primitive ((c-pointer mysql))
#<<END
  mysql_close(mysql);
END
))

(define make-mysql-c-connection
  (foreign-primitive c-pointer (
    (c-string host)
    (c-string user)
    (c-string pass)
    (c-string database))
#<<END
  MYSQL *conn;
  conn = mysql_init(NULL);
  mysql_options(conn, MYSQL_READ_DEFAULT_GROUP, "client");
  mysql_real_connect(conn, host, user, pass, database, 0, NULL, 0);
  if (mysql_errno(conn) != 0) {
    fprintf (stderr, "MYSQL ERROR: %d %s\n", 
            mysql_errno(conn), mysql_error(conn));
  }
  return(conn);
END
))

)
