#!/bin/sh
# ggconf.sh 
#   - set up environment specific variables in this script.
#
# Author: Yu (Denis) Sun
#
# Notes:
#    Oracle sqlplus is used to load data.
#
# Modifications:
#   
#    Denis  9-12-2020  abandon orapass for ansible deployment 
#    Denis  4-12-2020  created
#

. ~/.profile

export EZCONN=repodb-host.example.com:1521/repodb.example.com
export DBUSER=repodb-user

# dbsid used to get password
# not used anymore 
export DBSID=repodb

export PATH=~/bin:$PATH
