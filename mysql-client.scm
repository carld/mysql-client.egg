; chicken-scheme  MySQL query procedure
; 
; To use:
;   (use mysql-client)
;   (define mysql (make-mysql-connection "host" "user" "pass" "schema"))
;   (define fetch (mysql "select * from messages"))
;   (fetch)
;
; Provide password as #f to use the password from the .my.cnf
; options file (/home/user/.my.cnf).   If host is #f, it will
; try to connect via a socket (same as "localhost", which differs
; from "127.0.0.1").  If user is #f, it will connect as the current
; UNIX user.
;
; Example .my.cnf:
;
;   [client]
;   user=root
;   password=secret
;
; To connect to a host on a nonstandard port or socket, use the port: or
; socket: keywords.  For example, to connect to socket /tmp/mysql.socket:
; (define mysql (make-mysql-connection
;                 #f "user" "pass" "schema" socket: "/tmp/mysql.socket"))

(module mysql-client (make-mysql-connection mysql-null mysql-null?)
        (import scheme chicken foreign)
        (use irregex data-structures)

(define (make-mysql-connection host user pass database #!key port socket)
  (define mysql-c (make-mysql-c-connection host user pass database
                                           (or port 0) socket))
  (set-finalizer! mysql-c close-mysql-c-connection)

  ;; XXX Should the password be in the arguments list?
  ;; It'll appear in the error trace.  OTOH, it's important that
  ;; we can debug how/why it went wrong.
  (mysql-check-error mysql-c 'make-mysql-connection
                     `(,host ,user ,pass ,database
                             ,@(if port (list port: port) '())
                             ,@(if socket (list socket: socket) '())))

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


(define-inline (fetch-row result-c)
  (or (mysql-c-fetch-row result-c)
      ;; result-c could also be NULL, but that should
      ;; never be possible in a normal situation.
      (error "Out of memory while fetching row")))

(define (execute-query mysql-c query)
  (define result-c (mysql-c-query mysql-c query))
  (mysql-check-error mysql-c 'execute-query query)
  (set-finalizer! result-c mysql-c-free-result)
  (if (not result-c)
      (constantly #f)
      (lambda fetch-args
        (cond ((null? fetch-args)
               (let ((row (fetch-row result-c)))
                 (and (pair? row) row)))
              ((pair? fetch-args)
               (fetch-loop result-c (car fetch-args)))))))

(define (fetch-loop result-c thunk)
  (let process ()
    (let ((row (fetch-row result-c)))
      (when (pair? row)
        (thunk row)
        (process)))))

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
        (or (mysql-c-real-escape-string
             mysql-c (alist-ref (irregex-match-substring r 0)
                                stringified-keys string=?))
            (error "Out of memory while escaping parameter"))))))

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

  if (mysql_query(conn, sql) != 0) {
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
    (c-string database)
    (int port)
    (c-string socket))
#<<END
  MYSQL *conn;
  conn = mysql_init(NULL);
  mysql_options(conn, MYSQL_READ_DEFAULT_GROUP, "client");
  mysql_real_connect(conn, host, user, pass, database, port, socket, 0);
  return(conn);
END
))

(define (mysql-check-error mysql-c loc . args)
  (let ((errno ((foreign-lambda int "mysql_errno" c-pointer) mysql-c)))
    (unless (zero? errno)
      (let ((msg ((foreign-lambda c-string "mysql_error" c-pointer) mysql-c)))
        (signal (make-composite-condition
                 (make-property-condition
                  'exn 'location loc 'message msg 'arguments args)
                 (make-property-condition
                  'mysql 'errno errno 'error msg)))))))
)
