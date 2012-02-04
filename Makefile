# vim: tabstop=8 noexpandtab

MY_CONFIG   ?= mysql_config 
UNAME       ?= $(shell uname)
CSC_CFLAGS   = $(shell $(MY_CONFIG) --include )
CSC_LFLAGS   = $(shell $(MY_CONFIG) --libs )

all: mysql.so scm-mysql-example

mysql.so: mysql.scm
	CSC_OPTIONS="$(CSC_CFLAGS) $(CSC_LFLAGS)" chicken-install -n

scm-mysql-example: README
	csc -C "$(CSC_CFLAGS)" -L "$(CSC_LFLAGS)" -d2 -v -o scm-mysql-example README

clean:
	rm -v -f mysql.so mysql.o mysql.c scm-mysql-example 

.PHONY: clean 

