#!/bin/sh
# ggconf.sh 
#   - set up environment specific variables in this script.
#
# Author: Yu (Denis) Sun
#
# Notes:
#    Oracle sqlplus is used to load data.
#    orapass program need to be at ~/bin
#
# Modifications:
#    Denis  4-12-2020  created
#

. ~/.profile

export EZCONN=xxx
export DBUSER=xxx
export DBSID=xxx

export PATH=~/bin:$PATH
