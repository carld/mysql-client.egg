; chicken-scheme  MySQL query procedure
;
; To build:
;   CSC_OPTIONS=`mysql_config --include --libs` chicken-install -n
; 
; To use:
;   (require-library mysql)
;   (define mysql (make-mysql-connection "host" "user" "pass" "schema"))
;   (define fetch (mysql "select * from messages"))
;   (fetch)
;
; Provide password as #f to use the password from the .my.cnf
; options file (/home/user/.my.cnf).
;   
; A NULL field is represented by a string containing 
; a 0x04 0x00 char sequence

(define (make-mysql-connection host user pass database)
  (define mysql-c (make-mysql-c-connection host user pass database))
  (set-finalizer! mysql-c 
                  (lambda(x) 
                    (close-mysql-c-connection mysql-c-conn)))
  (define (mysql-query sql)
    (define result-c (mysql-c-query mysql-c sql))
    (define (fetch-c)(let ((row (mysql-c-fetch-row result-c)))
                        (if (> (length row) 0)
                            row
                            #f)))
    (set-finalizer! result-c
                    (lambda(x)
                      (mysql-c-free-result result-c)))
    fetch-c)
  mysql-query)

(foreign-declare "#include \"mysql.h\"")

(define mysql-c-fetch-row
  (foreign-lambda* c-string-list* ((c-pointer result))
#<<END
  int num_fields = mysql_num_fields(result);
  int index = num_fields;
  MYSQL_ROW row;
  char **fields;
  row = mysql_fetch_row(result);
  fields = (char **)malloc(sizeof(char *) * (num_fields + 1));
  bzero(fields, sizeof (char *) * (num_fields + 1));
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


