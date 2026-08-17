#!/bin/bash
# Script name: pgconn.sh 
# Purpose    : use database.ini file that used by pgcheck.py to connect to the postgresql with psql
# Usage      :  
#            (1) no argumets :  pgconn.sh
#            (2) 1 argument  :  pgconn.sh <DBCONFIG>  or pgconn.sh <SQLFILE>  or pgconn.sh -E  
#            (3) 2 arguments  :  pgconn.sh <DBCONFIG>  <SQLFILE> or pgconn.sh <DBCONFIG> -E  
#            (4) 3 arguments  :  pgconn.sh <DBCONFIG>  <SQLFILE> "-E -o out.txt"   
#
# Modifications:
#    01-Aug-2019  command line options   Yu (Denis) Sun 
#    26-Jun-2019  Created                Yu (Denis) Sun 
#

if [[ $# -eq 1 ]]; then
  if   [[ $1 =~ psql ]]; then
      RUNPSQL=$1
  elif [[ $1 =~ -.* ]]; then
      OPTIONS=$1 
  elif [[ -n ` grep "^\[postgresql\]\s*$" $1  ` ]]; then
      DBCONF=$1
  else
      SQLFILE=$1
  fi
fi 

if [[ -n $RUNPSQL ]]; then
$RUNPSQL
exit 0
fi

if [[ $# -eq 2 ]]; then

  if [[ -n ` grep "^\[postgresql\]\s*$" $1  ` ]]; then
      DBCONF=$1
  else
     echo "Please provide a db config file as the first argument"
     exit 1
  fi
   
  if [[ $2 =~ -.* ]]; then
      OPTIONS=$2 
  else
      SQLFILE=$2
  fi
fi 

if [[ $# -eq 3 ]]; then
  if [[ -n ` grep "^\[postgresql\]\s*$" $1  ` ]]; then
      DBCONF=$1
  else
     echo "Please provide a db config file as the first argument"
     exit 1
  fi
  SQLFILE=$2
  OPTIONS=$3
fi


if [[ -n $DBCONF ]]; then
	MYHOST=` grep "^\s*host" $DBCONF | awk -F= '{print $2 }' `
	MYPORT=` grep "^\s*port" $DBCONF | awk -F= '{print $2 }' `
	USERNAME=` grep "^\s*user" $DBCONF | awk -F= '{print $2 }' `
	DBNAME=` grep "^\s*database" $DBCONF | awk -F= '{print $2 }' `
	PASSWORD=` grep "^\s*password" $DBCONF | awk -F= '{print $2 }' `
fi


if [[ -z $MYHOST ]]; then
    echo "Enter the endpoint (hostname) you want to connect to: "
    read MYHOST
fi


if [[ -z $MYPORT ]]; then
    echo "Enter port: "
    read MYPORT 
fi

if [[ -z $USERNAME ]]; then
    echo "Enter username: "
    read USERNAME 
fi

if [[ -z $DBNAME ]]; then
    echo "Enter database : "
    read DBNAME 
fi

echo "---------------------------Your connection inputs---------------------------"
echo "Endpoint: $MYHOST"
echo "Port    : $MYPORT"
echo "User    : $USERNAME"
echo "Database: $DBNAME"

if [[ -n $SQLFILE ]]; then
  echo "SQLFILE : $SQLFILE"
fi

if [[ -n $OPTIONS ]]; then
  echo "Options : $OPTIONS"
fi
echo "---------------------------------------------------------------------------"
echo " "
echo " "


if [ -n "$SQLFILE" ]; then
   echo "------------------- You run the following sql statments ------------"
   cat $SQLFILE
   echo "------------------- end  -------------------------------------------"
   echo " "
   echo " "

   PGPASSWORD=$PASSWORD psql -h $MYHOST -p $MYPORT -U $USERNAME  -d  $DBNAME -f $SQLFILE $OPTIONS
else
   PGPASSWORD=$PASSWORD psql -h $MYHOST -p $MYPORT -U $USERNAME  -d  $DBNAME  $OPTIONS
fi
