# vim: tabstop=8 noexpandtab

MY_CONFIG ?= mysql_config 
UNAME     ?= $(shell uname)

# csc doesn't like -rdynamic provided by mysql_config on Linux
ifeq ($(UNAME),Linux)
  CSC_OPTIONS ?= `$(MY_CONFIG) --include --libs | sed -e 's/-rdynamic //g' -e 's/-Wl,-Bsymbolic-functions//g'`
endif

ifeq ($(UNAME),Darwin)
  CSC_OPTIONS ?= `$(MY_CONFIG) --include --libs`
endif

all: mysql.so scm-mysql-example

mysql.so:
	CSC_OPTIONS=$(CSC_OPTIONS) chicken-install -n

scm-mysql-example:
	csc -o scm-mysql-example README

clean:
	rm -v -f mysql.so mysql.o mysql.c scm-mysql-example 

.PHONY: clean 

