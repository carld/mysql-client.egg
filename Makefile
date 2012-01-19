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

mysql.so:
	CSC_OPTIONS=$(CSC_OPTIONS) chicken-install -n

clean:
	rm -v mysql.so mysql.o mysql.c

.PHONY: clean 

