#!/usr/bin/bash

if [[ $# -lt 1 ]]; then
      echo " *****  Usage  ******"
      echo " * Connect to a PG database using connect info in the configFile:"
      echo "   $0 -c <configFile> "
      echo " * Connect to a PG database using connect info in the configFile and run the sql commands in sqlCmdFile:"
      echo "   $0 -c <configFile> -s <sqlCmdFile> "
      echo " * Connect to a PG database with connect info entered interactively:"
      echo "   $0 -i  "
      exit 1
fi

while getopts "hic:s:" opt; do
  case ${opt} in
    h )
      echo " * Connect to a PG database using connect info in the configFile:"
      echo "   $0 -c <configFile> "
      echo " * Connect to a PG database using connect info in the configFile and run the sql commands in sqlCmdFile:"
      echo "   $0 -c <configFile> -s <sqlCmdFile> "
      echo " * Connect to a PG database with connect info entered interactively:"
      echo "   $0 -i  "
      exit 1
      ;;
    c )
      DBCONF="$OPTARG" 
      ;;
    s )
      SQLFILE="$OPTARG"
      ;;
    i )
       echo "Interactively enter required info ..."
      ;;  
    ? ) 
        echo "**** Script Uages example  **** "
        echo " $0 -h "
        echo " $0 -c <configFile> "
        echo " $0 -c <configFile> -s <sqlCmdFile> "
        echo " $0 -i  "
        exit 1
       ;;
   esac
done
shift "$(($OPTIND -1))"


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




echo "---------------------------You connection inputs---------------------------"
echo "Endpoint: $MYHOST"
echo "Port    : $MYPORT"
echo "User    : $USERNAME"
echo "Database: $DBNAME"
echo "---------------------------------------------------------------------------"
echo " "
echo " "

if [ -n "$SQLFILE" ]; then
   echo "------------------- You run the following sql statments ------------"
   cat $SQLFILE
   echo "------------------- end  -------------------------------------------"
   echo " "
   echo " "

   PGPASSWORD=$PASSWORD psql -h $MYHOST -p $MYPORT -U $USERNAME  -d  $DBNAME -f $SQLFILE
else
   PGPASSWORD=$PASSWORD psql -h $MYHOST -p $MYPORT -U $USERNAME  -d  $DBNAME
fi

