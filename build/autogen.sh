#! /bin/bash

aclocal -I aclocal
autoconf
rm -rf autom4te.cache
