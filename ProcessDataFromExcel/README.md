Python Scripts to Extract unique vulnerabilities from Security Team's reports
=============================================================================


# Program Files

##  process_and_load_hardware_vuls.py

     Processing data in an Excel file specified as the first command line argument and load the data into Hardware Vulns Summary.xlsx table

     input file:  sheets\Hardware_app_sample.xlsx (w/ masked data)
     output file: Hardware Vulns Summary.xlsx




```

(venv311_prac) C:\Users\...\DBRE-YDS\ProcessDataFromExcel>python process_and_load_hardware_vuls.py sheets\Hardware_app_sample.xlsx

python process_and_load_hardware_vuls.py sheets\Hardware_app_sample.xlsx

List DB related vulnerabilities in "sheets\Hardware_app_sample.xlsx"


### Warning - Apache Log4Shell RCE detection via callback correlation (Direct Check HTTP) is not found. Adding ...
### Warning - Oracle Database Unsupported Version Detection is not found. Adding ...
### Warning - Apache Log4Shell RCE detection via Path Enumeration (Direct Check HTTP) is not found. Adding ...
### Warning - SSL Medium Strength Cipher Suites Supported (SWEET32) is not found. Adding ...
### Warning - Apache Tomcat 9.0.0.M1 < 9.0.71 is not found. Adding ...
### Warning - Apache Tomcat 8.5.0 < 8.5.49 Privilege Escalation is not found. Adding ...
### Warning - Apache Tomcat 7.0.x <= 7.0.108 / 8.5.x <= 8.5.65 / 9.0.x <= 9.0.45 / 10.0.x <= 10.0.5 vulnerability is not found. Adding ...
### Warning - Apache Tomcat 8.5.0 < 8.5.41 DoS is not found. Adding ...
### Warning - Apache Tomcat Default Files is not found. Adding ...
### Warning - Apache Tomcat 9.0.30 < 9.0.65 vulnerability is not found. Adding ...
### Warning - HTTP TRACE / TRACK Methods Allowed is not found. Adding ...
### Warning - JQuery 1.2 < 3.5.0 Multiple XSS is not found. Adding ...
### Warning - Apache Tomcat 8.5.0 < 8.5.85 is not found. Adding ...

```



# get_summary_app_id.py

Generate summary report from Tanable and Hardware excel files for a particular app_id ( app_id represents an application).

For example, assuming app_id=12345, It takes two input files as arguments, the first could be the Tanable Agent Vulns_app_id_12345.xlsx and the second should be Hardware_app_id_12345.xlsx

C:\Users\...\Denis_files\...\Projects\Tenable_DB> python get_summary_app_id.py "sheets\Tanable Agent Vulns_app_id_12345.xlsx" "sheets\Hardware_app_id_12345.xlsx"

The output file is:  app_id_12345_summary.xlsx



```


(venv311_prac) C:\Users\xxxxx\DBRE-YDS\ProcessDataFromExcel>python get_summary_app_id.py "sheets\Tenable Agent Vulns_app_id_12345.xlsx" "sheets\Hardware_app_id_12345.xlsx"

List DB related vulnerabilities in "sheets\Hardware_app_id_12345.xlsx"



List DB related vulnerabilities in "sheets\Tenable Agent Vulns_app_id_12345.xlsx"


Path matching: /opt/IBM/oracle/base/product/11gR204/jdk
Path matching: /opt/IBM/oracle/base/product/11gR204/jdk
Path matching: /opt/IBM/oracle/base/product/11gR204/jdk
Path matching: /opt/IBM/oracle/base/product/11gR204/jdk
Path matching: /opt/IBM/oracle/base/product/11gR204/jdk
Path matching: /opt/IBM/oracle/base/product/11gR204/jdk
Path matching: /opt/IBM/oracle/base/product/11gR204/jdk
Path matching: /opt/IBM/oracle/base/product/11gR204/jdk
Path matching: /opt/IBM/OracleClient.bkp/12201/jdk/
Path matching: /opt/IBM/OracleClient/12201/jdk/
Path matching: /opt/IBM/OracleClient/12201/jdk/
Path matching: /opt/IBM/OracleClient/12201/jdk/
Path matching: /oracle/app/product/11gR2/client_1/jdk
Path matching: /oracle/client/19.0.0.0/jdk/
Path matching: /oracle/client/stage/Components/oracle.jdk/1.8.0.201.0/1/DataFiles/Expanded/filegroup2/jre/
Path matching: /opt/IBM/OracleClient/12201/jdk/
Path matching: /opt/IBM/OracleClient/12201/jdk/
Path matching: /oracle/app/product/11gR2/client_1/jdk


...

```


MISC

to test:

.\Denis_files\python_proj\practise\venv311\Scripts\activate.bat