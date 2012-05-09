# vim: tabstop=8 noexpandtab

all: install scm-mysql-example

install:
	chicken-install -s -test

mysql-client.so: mysql-client.scm
	chicken-install -n

scm-mysql-example: README
	csc -o scm-mysql-example README

test:
	salmonella --this-egg

clean:
	rm -v -f mysql-client.so mysql-client.o mysql-client.c \
	  mysql-client.import.scm \
	  mysql-client.import.so mysql-client.import.o mysql-client.import.c \
	  scm-mysql-example

.PHONY: all install clean 

