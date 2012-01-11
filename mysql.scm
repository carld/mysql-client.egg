; chicken-scheme  MySQL query procedure
; Copyright (c) 2011 A. Carl Douglas
; 
; (require-library mysql)
; (define mysql (make-mysql-connection "host" "user" "pass" "schema"))
; (define fetch (mysql "select * from messages"))
; (fetch)

(foreign-declare "#include \"mysql.h\"")

(define (make-mysql-connection host user pass database)
  (define mysql-c 
    (make-mysql-c-connection host user pass database))
  (set-finalizer! mysql-c 
                  (lambda() 
                    (close-mysql-c-connection mysql-c-conn)))
  (define (mysql-query sql)
    (define result-c 
      (mysql-c-query mysql-c sql))
    (set-finalizer! result-c
                    (lambda()
                      (mysql-c-free-result result-c)))
    (lambda()
      (mysql-c-fetch-row result-c)))
  mysql-query)

(define mysql-c-fetch-row
  (foreign-primitive scheme-object ((c-pointer result))
#<<END
  int num_fields = mysql_num_fields(result);
  int num_rows   = mysql_num_rows(result);
  MYSQL_ROW row  = mysql_fetch_row(result);
  if (row != NULL) {
    C_word *store_list = C_alloc(C_SIZEOF_LIST(num_fields));
    C_word x, last, current, first = C_SCHEME_END_OF_LIST;
    for(last = C_SCHEME_UNDEFINED; 
             num_fields--; 
             last = current) {
      C_word *xp = C_alloc(C_SIZEOF_STRING(strlen(row[num_fields])));
      C_word x = C_string2(&xp, row[num_fields]);
      current = C_a_pair(&store_list, x, C_SCHEME_END_OF_LIST);
      if(last != C_SCHEME_UNDEFINED)
        C_set_block_item(last, 1, current);
      else first = current;
    }
    return(first);
  } else {
    return(C_SCHEME_FALSE);
  }
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


