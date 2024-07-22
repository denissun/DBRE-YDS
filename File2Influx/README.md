# Overview

InfluxDB is a time series platform. It is purpose-built to handle the massive volumes and countless sources of time-stamped data produced by sensors, applications and infrastructure. InfluxDB provides built-in data visualization capabilities through “Data Explorer” and “Dashboard” in the web browser.

OSWatcher (oswbb) is downloadable from Oracle support website and is a utility to capture performance metrics from the operating system.

We have already run OSWatcher program on most of our Oracle database servers as part of TFA/AHF installation process and typically we configure it to collect data every 30s and retain for weeks. Therefore, large amount of OSWatcher data has been stored on the disks, however they are very infrequently being utilized due to lack of visualization tools. By loading OSWatcher time series data into InfluxDB, we will make those data readily accessible and we can take advantage of many built-in real time visualization and analytical capabilities offered by InfluxDB platform.

For the aforementioned purpose, I have developed a Java program called File2InFlux to parse OSWatcher data files and load the time series data into InfluxDB. File2Influx currently is also able to parse Oracle database system metrics and wait event data from a customized query. It is easily extendable to parase any other type of time series data and load into the InfluxDb if needs arise.   




# File2Influx 

     A Java program Parsing various types of input files and load time series data into InfluxDB. I choose Java because we have Solaris databases servers. Other language such as Python, Golang are not suitable to run on Solaris platform. 


## Usage:




```
--------------------------------------------------------------------------------------

File2Influx : Load time series data from files to InfluxDB

  Usage         : java -jar File2Influx.jar propertyFile inputFile inputFileType tagName

  propertyFile  : A config file that contains InfluxDB connect info
  inputFile     : A text file that contains the data
  inputFileType :
                  oswtop         - Solaris version of OSWatcher oswtop file
                  oswtop2        - Linux version of OSWatcher oswtop file
                  oswiostat3     - Linux version of OSWatcher iostat file (16 fields)
                  eventSysmetric - A CSV file that contains top 5 wait events
                                   and system metrics data of Oracle database
  tagName       : InfluxDB line protocol tag key value e.g. host_name

--------------------------------------------------------------------------------------

```


# InfluxDB example dashboards to visulize time series data


## OS Watch data 

![Alt text](/File2Influx/img/osw.png "OS Watcher Dashbaord")

## Wait Event and Sysmetric data

![Alt text](/File2Influx/img/event.png "Wait Event and Sysmtric Dashbaord")



# MISC

## Maven


    https://spring.io/guides/gs/maven/

    mvn compile
    mvn package


    C:\Users\...\java\java8projects\File2Influx>mvn -v
    Apache Maven 3.9.8 (36645f6c9b5079805ea5009217e36f2cffd34256)
    Maven home: C:\Users\...\java\apache-maven-3.9.8-bin\apache-maven-3.9.8
    Java version: 1.8.0-272, vendor: OpenLogic-OpenJDK, runtime: C:\Users\...\java\openlogic-openjdk-8u272-b10-windows-64\jre
    Default locale: en_US, platform encoding: Cp1252
    OS name: "windows 10", version: "10.0", arch: "amd64", family: "windows"

## Test 


    java -jar target\File2Influx-0.1.5.jar src\main\java\File2Influx\configuration\influx.properties src\data\iostat_linux_16.dat oswiostat3 linhost2_testdb

    java -jar target\File2Influx-0.1.5.jar src\main\java\File2Influx\configuration\influx.properties src\data\el8.dat oswtop2 linhost2_testdb

    java -jar target\File2Influx-0.1.5.jar src\main\java\File2Influx\configuration\influx.properties src\data\topwaitevent.csv  eventSysmetric linhost2_testdb

## iostat file format differences

   * OSWachter iostat file data have different number of fields, for examples:

```
                        oswiostat2b    - Linux version of OSWatcher iostat file (14 fields)

Device            r/s     w/s     rkB/s     wkB/s   rrqm/s   wrqm/s  %rrqm  %wrqm r_await w_await aqu-sz rareq-sz wareq-sz  svctm  %util
sda              0.00   31.00      0.00    493.00     0.00     3.00   0.00   8.82    0.00    0.13   0.00     0.00    15.90   0.06   0.20


                        oswiostat2a    - Linux version of OSWatcher iostat file (14 fields)

Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
sdq               0.00     0.00    0.00    0.00     0.00     0.00     0.00     0.00    0.00    0.00    0.00   0.00   0.00


                        oswiostat2     - Linux version of OSWatcher iostat file (12 fields)


 Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await  svctm  %util
 sdb               0.00     0.00    0.00    0.00     0.00     0.00     0.00     0.00    0.00   0.00   0.00
 ```




## influx line protocal example


```

        weather,location=us-midwest temperature=82 1465839830100400200
        |    -------------------- --------------  |
        |             |             |             |
        |             |             |             |
        +-----------+--------+-+---------+-+---------+
        |measurement|,tag_set| |field_set| |timestamp|
        +-----------+--------+-+---------+-+---------+

```


A single line of text in line protocol format represents one data point in InfluxDB. It informs InfluxDB of the point’s measurement, tag set, field set, and timestamp.
