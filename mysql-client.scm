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
; Note how MySQL (NULL) values are represented when
; returned in an array of string pointers:
; A (NULL) value is represented by a string containing 
; a 0x04 0x00 char sequence.

(module mysql-client (make-mysql-connection)
        (import scheme chicken foreign)
        (use irregex data-structures)

(define (make-mysql-connection host user pass database)
  (define mysql-c (make-mysql-c-connection host user pass database))
  (set-finalizer! mysql-c (lambda(x) (close-mysql-c-connection mysql-c)))
  (define (mysql-query query . parameters)
    (cond ((and (string? query)(equal? parameters '())) (dispatch-query mysql-c query parameters))
          ((string? query) (dispatch-query mysql-c query (car parameters)))
          ((procedure? query) (dispatch-proc mysql-c query parameters))
          (else (error "unrecognised query object: " query))))
  mysql-query)

(define (dispatch-query conn query parameters)
  (define result-c 
    (cond ((equal? '() parameters) (mysql-c-query conn query))
          (else (mysql-c-query conn (escape-placeholder-params conn query parameters)))))
  (define (fetch-c)(let ((row (mysql-c-fetch-row result-c)))
                      (if (> (length row) 0) row #f)))
  (set-finalizer! result-c (lambda(x) (mysql-c-free-result result-c)))
  fetch-c)

(define (dispatch-proc conn proc . parameters)
  (proc conn parameters))

(define (escape-placeholder-params conn query parameters)
  (let ((escaped-parameters 
          (map (lambda(x)
                 (cons (symbol->string (car x)) (mysql-c-real-escape-string conn (cdr x))))
               parameters)))
       (irregex-replace/all 
         (flatten (list 'or (map (lambda(x) (car x)) escaped-parameters)))
         query
         (lambda (r) 
           (alist-ref (irregex-match-substring r 0) escaped-parameters string=?)))))

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
    return(C_SCHEME_FALSE);
  }
  len2 = mysql_real_escape_string(conn, dst, str, strlen(str));
  return(dst);
END
))

(define mysql-c-fetch-row
  (foreign-lambda* c-string-list* ((c-pointer result))
#<<END
  int num_fields = mysql_num_fields(result);
  int index = num_fields;
  MYSQL_ROW row;
  char **fields;
  row = mysql_fetch_row(result);
  fields = (char **)calloc(num_fields + 1, sizeof(char *));
  if (fields == NULL) {
    fprintf(stderr, "out of memory\n");
    return(C_SCHEME_FALSE);
  }
  for (;row && index--;) {
    if (row[index] == NULL) 
      fields[index] = strdup("\x04\x00");
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
    C_return(NULL); /*C_return(C_SCHEME_FALSE);*/
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
