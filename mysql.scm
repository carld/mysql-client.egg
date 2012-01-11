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
; A NULL field is represented by a string containing 
; a 0x04 0x00 char sequence

(define (make-mysql-connection host user pass database)
  (define mysql-c (make-mysql-c-connection host user pass database))
  (set-finalizer! mysql-c 
                  (lambda() 
                    (close-mysql-c-connection mysql-c-conn)))
  (define (mysql-query sql)
    (define result-c (mysql-c-query mysql-c sql))
    (define (fetch-c)(mysql-c-fetch-row result-c))
    (set-finalizer! result-c
                    (lambda()
                      (mysql-c-free-result result-c)))
    fetch-c)
  mysql-query)

(foreign-declare "#include \"mysql.h\"")

(define mysql-c-fetch-row
  (foreign-lambda* c-string-list* ((c-pointer result))
#<<END
  int num_fields = mysql_num_fields(result);
  MYSQL_ROW row;
  char **fields;
  fields = (char **)malloc(sizeof(char *) * num_fields);
  row = mysql_fetch_row(result);
  for (;num_fields--;) {
    if (row[num_fields] == NULL) 
      fields[num_fields] = strdup("\x04\x00");
    else
      fields[num_fields] = strdup(row[num_fields]);
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
int rc = mysql_query(conn, sql);
MYSQL_RES *result;
if (rc != 0) C_return(NULL); /*C_return(C_SCHEME_FALSE);*/
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
  mysql_real_connect(conn, host, user, pass, database, 0, NULL, 0);
  return(conn);
END
))


