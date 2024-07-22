package File2Influx;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.time.Instant;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;

import com.influxdb.client.InfluxDBClient;
import com.influxdb.client.WriteApi;

public class OswTopFileParser {

    public static void process_oswtop_file2(InfluxDBClient client, String org, String bucket, String oswtopFile, String hostname) {
        // Proccessing Linux 8 version of oswtop file, fileType=="oswtop2"
        String data;
        long timeInMillis = 0;
        long timeInMillis_prv = 0;
        try {
            BufferedReader in = new BufferedReader(new FileReader(oswtopFile));
            String line;
            while ((line = in.readLine()) != null) {
                if (line.matches("^zzz(.*)")) {
                    // zzz ***Mon Mar 8 21:00:26 EST 2021
                    timeInMillis_prv = timeInMillis;
                    System.out.println(line);
                    String dateStr = line.substring(7);
                    System.out.println(dateStr);
                    DateTimeFormatter formatter = DateTimeFormatter.ofPattern("EEE MMM d H:m:s z yyyy");
                    ZonedDateTime zDateTime = ZonedDateTime.parse(dateStr, formatter);
                    System.out.println(zDateTime);
                    Instant instant = zDateTime.toInstant();
                    timeInMillis = instant.toEpochMilli();
                    System.out.println(timeInMillis);
                    System.out.println("--------");
                    // String data = "load_average,host=TNC0060ALKVTACL
                    // load1=40,load5=xxx,load15=xxx";
                } else if (line.matches("^top(.*)")) {
                    System.out.println(line);
                    // top - 21:00:28 up 657 days, 14:09, 2 users, load average: 6.60, 6.04, 5.88
                    // top - 08:56:52 up 170 days,  6:12,  2 users, load average: 4.43, 4.94, 5.07
                    String[] topLineWords = line.split("\\s+");
                    String load1 = topLineWords[11];
                    String load5 = topLineWords[12];
                    String load15 = topLineWords[13];
                    data = String.format("load_average,host=%s load1=%s,load5=%s,load15=%s %d", hostname,
                            load1.replace(",", ""), load5.replace(",", ""), load15, timeInMillis);
                    System.out.println(data);
                    System.out.println("--------");
                    if (timeInMillis > timeInMillis_prv) {
                        File2Influx.Save_to_Influx(data, client, org, bucket);
                    }
                } else if (line.matches("^Tasks(.*)")) {
                    // Tasks: 4121 total,   8 running, 4113 sleeping,   0 stopped,   0 zombie
                    String[] tasksLineWords = line.split("\\s+");
                    String countTotal = tasksLineWords[1];
                    String countSleep = tasksLineWords[5];
                    data = String.format("tasks,host=%s count=%s,count_sleep=%s %d", hostname, countTotal, countSleep,
                            timeInMillis);
                    System.out.println(data);
                    if (timeInMillis > timeInMillis_prv) {
                        File2Influx.Save_to_Influx(data, client, org, bucket);
                    }
                } else if (line.matches("^%Cpu(.*)")) {
                    // Cpu(s): 13.5%us, 4.4%sy, 0.0%ni, 80.4%id, 1.4%wa, 0.0%hi, 0.3%si, 0.0%st
                    // %Cpu(s):  9.0 us,  3.3 sy,  0.0 ni, 86.7 id,  0.7 wa,  0.2 hi,  0.2 si,  0.0 st
                    String[] cpuLineWords = line.split("\\s+");
                    String cpuUS = cpuLineWords[1];
                    String cpuSY = cpuLineWords[3];
                    String cpuID = cpuLineWords[7];
                    String cpuWA = cpuLineWords[9];
                    data = String.format("host_cpu_linux,host=%s cpu_util=%.1f,user=%s,system=%s,wait=%s %d", 
                                        hostname, 100 - Float.parseFloat(cpuID), cpuUS, cpuSY, cpuWA, timeInMillis);
                    System.out.println(data);
                    if (timeInMillis > timeInMillis_prv) {
                        File2Influx.Save_to_Influx(data, client, org, bucket);
                    }
                } else if (line.matches("^MiB Mem(.*)")) {
                    // Mem:  148692928k total, 133562960k used, 15129968k free,  2191036k buffers
                    // MiB Mem : 385037.8 total,  64748.9 free, 124336.1 used, 195952.8 buff/cache

                    String[] memLineWords = line.split("\\s+");
                    String memTotal = memLineWords[3];
                    String memFree = memLineWords[5];
                    String memUsed = memLineWords[7];
                    String memBuf = memLineWords[9];
                    data = String.format("host_mem_linux,host=%s total=%s,used=%s,free=%s,buffers=%s %d", 
                           hostname, memTotal, memUsed, memFree, memBuf, timeInMillis);
                    System.out.println(data);
                    if (timeInMillis > timeInMillis_prv) {
                        File2Influx.Save_to_Influx(data, client, org, bucket);
                    }
                }
            }

        } catch (IOException e) {
            System.out.println("Unable to read oswtopFile file");
            throw new RuntimeException(e);
        }
    }

    public static void process_oswtop_file(InfluxDBClient client, String org, String bucket, String oswtopFile, String hostname) {
        // Proccessing Solaris version of oswtop file, file_type=="oswtop"
        String data;
        long timeInMillis=0;
        long timeInMillis_prv=0;
        try {
           BufferedReader in = new BufferedReader(new FileReader(oswtopFile));
           String line;
           while ((line = in.readLine()) != null){
              if ( line.matches("^zzz(.*)") ) {
                 timeInMillis_prv=timeInMillis;
                 //System.out.println(line);
                 String dateStr=line.substring(7);
                 System.out.println(dateStr);	
                 DateTimeFormatter formatter = DateTimeFormatter.ofPattern("EEE MMM d H:m:s z yyyy");
                 ZonedDateTime zDateTime = ZonedDateTime.parse(dateStr, formatter);
                 System.out.println(zDateTime);	
                 Instant instant = zDateTime.toInstant();	
                  timeInMillis = instant.toEpochMilli();
                  // System.out.println(timeInMillis);
                  System.out.println("--------");
                 //String data = "mem,host=TNC0060ALKVTACL used_percent=40";
              }
              else if  (line.matches("(.*)processes:(.*)")) {
                 System.out.println(line);
                 String[] ProcWords = line.split(" ");
                 String numProc=ProcWords[0];
                 String numSleepProc=ProcWords[2];
                 System.out.println(numProc + ' ' + numSleepProc);
                 data = String.format("processes,host=%s count=%s,count_sleep=%s %d",hostname, numProc, numSleepProc, timeInMillis);
                 System.out.println(data);
                 if (timeInMillis > timeInMillis_prv) {
                    System.out.println("------- processes call Save_to_Influx----");
                    File2Influx.Save_to_Influx(data, client, org, bucket);
                 }
                  System.out.println("--------");
  
              }
              else if  (line.matches("^CPU states:(.*)")) {
                 //System.out.println(line);
                 String[] CpuWords = line.split("\\s+");
                 String CpuIdle =CpuWords[2];
                 String CpuUser =CpuWords[4];
                 String CpuKernel =CpuWords[6];
                 String CpuIowait =CpuWords[8];
                 data = String.format("host_cpu,host=%s total=%.1f,user=%s,kernel=%s,iowait=%s %d",hostname, 100-Float.parseFloat(CpuIdle.replace("%","")), CpuUser.replace("%",""), CpuKernel.replace("%",""), CpuIowait.replace("%",""), timeInMillis); 
                 if (timeInMillis > timeInMillis_prv) {
                      System.out.println("------- host_cpu call Save_to_Influx----");
                     File2Influx.Save_to_Influx(data, client, org, bucket);
                 }
  
                  System.out.println("--------");
              }
              else if  (line.matches("^Memory:(.*)")) {
                 //System.out.println(line);
                 String[] MemWords = line.split("\\s+");
                 String Mem = MemWords[1];
                 String freeMem = MemWords[4];
                 //System.out.println(Mem.replace("G","") + ' ' + freeMem.replace("G","") );
                 data = String.format("host_mem,host=%s total=%s,free=%s %d",hostname, Mem.replace("G",""), freeMem.replace("G",""), timeInMillis); 
                 if (timeInMillis > timeInMillis_prv) {
                    System.out.println("------- host_mem call Save_to_Influx----");
                    File2Influx.Save_to_Influx(data, client, org, bucket);
                 }
                  System.out.println("--------");
              }
  
           }
        }
        catch (IOException e) {
           System.out.println("Unable to read oswtopFile file");
           throw new RuntimeException(e);
        }
  
     }
  

}