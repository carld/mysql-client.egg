# vim: tabstop=8 noexpandtab

MY_CONFIG   ?= mysql_config 
UNAME       ?= $(shell uname)
CSC_CFLAGS   = $(shell $(MY_CONFIG) --include )
CSC_LFLAGS   = $(shell $(MY_CONFIG) --libs )

all: install scm-mysql-example

install:
	chicken-install -s -test

mysql-client.so: mysql-client.scm
	CSC_OPTIONS="$(CSC_CFLAGS) $(CSC_LFLAGS)" chicken-install -n

scm-mysql-example: README
	csc -C "$(CSC_CFLAGS)" \
	    -L "$(CSC_LFLAGS)" \
	    -o scm-mysql-example README

clean:
	rm -v -f mysql-client.so mysql-client.o mysql-client.c scm-mysql-example 

.PHONY: clean 

