package File2Influx;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.time.Instant;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;

import com.influxdb.client.WriteApi;

public class OswIostatFileParser {

     public static void process_oswiostat_file3(WriteApi writeApi, String org, String bucket, String oswiostatFile, String hostname) {
      // Proccessing Linux version of oswiostat file, file_type=="oswiostat3"
      // the file has 15 field
      // Device  r/s     w/s     rkB/s     wkB/s   rrqm/s   wrqm/s  %rrqm  %wrqm r_await w_await aqu-sz rareq-sz wareq-sz  svctm  %util
      // sda    0.00   11.00      0.00    296.00     0.00     0.00   0.00   0.00    0.00    0.09   0.00     0.00    26.91   0.18   0.20
      String data;
      long timeInMillis=0;
      long timeInMillis_prv=0;
      try {
         BufferedReader in = new BufferedReader(new FileReader(oswiostatFile));
         String line;
         Float sum_r_s =0.0f;
         Float sum_w_s =0.0f;
         Float sum_rkB_s=0.0f;
         Float sum_wkB_s=0.0f;
         while ((line = in.readLine()) != null){
            String[] words = line.split("\\s+");

	         // System.out.println(words.length);
            if ( line.matches("^zzz(.*)") ) {
               timeInMillis_prv=timeInMillis;
               System.out.println(line);
               String dateStr=line.substring(7);
               // System.out.println(dateStr);	
               DateTimeFormatter formatter = DateTimeFormatter.ofPattern("EEE MMM d H:m:s z yyyy");
               ZonedDateTime zDateTime = ZonedDateTime.parse(dateStr, formatter);
               System.out.println(zDateTime);	
               Instant instant = zDateTime.toInstant();	
	            timeInMillis = instant.toEpochMilli();
	            //System.out.println(timeInMillis);
	            System.out.println("--------");
               if (timeInMillis_prv > 0)  {
	               System.out.println(" ------  save sum data   ----");
	               // System.out.println(sum_r_s);
                  data = String.format("iostat,host=%s sum_r_s=%.1f,sum_w_s=%.1f,sum_rkB_s=%.1f,sum_wkB_s=%.1f %d", 
                                       hostname,sum_r_s, sum_w_s, sum_rkB_s, sum_wkB_s, timeInMillis_prv);
	               System.out.println(data);
                  File2Influx.Save_to_Influx_WriteApi(data, writeApi, org, bucket);
                  sum_r_s =0.0f;
                  sum_w_s =0.0f;
                  sum_rkB_s=0.0f;
                  sum_wkB_s=0.0f;
               }
            }
            else  if (  words.length == 16 &&  ! words[0].equals("Device") ) {
               // data line  16 fields 
               // Device            r/s     w/s     rkB/s     wkB/s   rrqm/s   wrqm/s  %rrqm  %wrqm r_await w_await aqu-sz rareq-sz wareq-sz  svctm  %util
               // sda              0.00   11.00      0.00    296.00     0.00     0.00   0.00   0.00    0.00    0.09   0.00     0.00    26.91   0.18   0.20
               
               data = String.format("iostat,host=%s,device=%s r_s=%s,w_s=%s,rkB_s=%s,wkB_s=%s,rrqm_s=%s,wrqm_s=%s,pct_rrqm=%s,pct_wrqm=%s,r_await=%s,w_await=%s,aqu-sz=%s,rareq-sz=%s,wareq-sz=%s,svctm=%s,pct_util=%s %d",
                    hostname, words[0] , words[1] , words[2] , words[3] , words[4] , words[5] , words[6] , words[7] , words[8] , words[9] , words[10] , words[11] , words[12], words[13], words[14], words[15], timeInMillis);
               if (timeInMillis > timeInMillis_prv) {
                   sum_r_s += Float.parseFloat(words[1]);
                   sum_w_s += Float.parseFloat(words[2]);
                   sum_rkB_s += Float.parseFloat(words[3]);
                   sum_wkB_s += Float.parseFloat(words[4]);

                   File2Influx.Save_to_Influx_WriteApi(data, writeApi, org, bucket);
               }
            } 
         }
         // whenever seeing zzz line we save the sum with timeInMillis_prv
         // when the end of file reached, we need to save the sum as well with timeInMillis
         if (timeInMillis > 0)  {
            System.out.println(" ------  save sum data   ----");
            data = String.format("iostat,host=%s sum_r_s=%.1f,sum_w_s=%.1f,sum_rkB_s=%.1f,sum_wkB_s=%.1f %d", 
                                 hostname,sum_r_s, sum_w_s, sum_rkB_s, sum_wkB_s, timeInMillis);
            System.out.println(data);
            File2Influx.Save_to_Influx_WriteApi(data, writeApi, org, bucket);
         }
      }
      catch (IOException e) {
         System.out.println("Unable to read oswiostatFile file");
         throw new RuntimeException(e);
      }
   }

   public static void process_oswiostat_file2a(WriteApi writeApi, String org, String bucket, String oswiostatFile, String hostname) {
      // Proccessing Linux version of oswiostat file, file_type=="oswiostat2a"
      String data;
      long timeInMillis=0;
      long timeInMillis_prv=0;
      try {
         BufferedReader in = new BufferedReader(new FileReader(oswiostatFile));
         String line;
         Float sum_r_s =0.0f;
         Float sum_w_s =0.0f;
         Float sum_rkB_s=0.0f;
         Float sum_wkB_s=0.0f;

         while ((line = in.readLine()) != null){
            String[] words = line.split("\\s+");

	         // System.out.println(words.length);
            if ( line.matches("^zzz(.*)") ) {
               timeInMillis_prv=timeInMillis;
               System.out.println(line);
               String dateStr=line.substring(7);
               System.out.println(dateStr);	
               DateTimeFormatter formatter = DateTimeFormatter.ofPattern("EEE MMM d H:m:s z yyyy");
               ZonedDateTime zDateTime = ZonedDateTime.parse(dateStr, formatter);
               System.out.println(zDateTime);	
               Instant instant = zDateTime.toInstant();	
	            timeInMillis = instant.toEpochMilli();
	            //System.out.println(timeInMillis);
	            System.out.println("--------");
               if (timeInMillis_prv > 0)  {
	               System.out.println(" ------  save sum data   ----");
	               System.out.println(sum_rkB_s);
                  data = String.format("iostat,host=%s sum_r_s=%.1f,sum_w_s=%.1f,sum_rkB_s=%.1f,sum_wkB_s=%.1f %d", 
                                       hostname,sum_r_s, sum_w_s, sum_rkB_s, sum_wkB_s, timeInMillis_prv);
                  File2Influx.Save_to_Influx_WriteApi(data, writeApi, org, bucket);
                  sum_r_s =0.0f;
                  sum_w_s =0.0f;
                  sum_rkB_s=0.0f;
                  sum_wkB_s=0.0f;
               }
            }
            else  if (  words.length == 14 &&  ! words[0].equals("Device:") ) {
               // data line  
               // Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await r_await w_await  svctm  %util
               // sdq               0.00     0.00    0.00    0.00     0.00     0.00     0.00     0.00    0.00    0.00    0.00   0.00   0.00
               
               data = String.format("iostat,host=%s,device=%s rrqm_s=%s,wrqm_s=%s,r_s=%s,w_s=%s,rkB_s=%s,wkB_s=%s,avgrq-sz=%s,avgqu-sz=%s,await=%s,r_await=%s,w_await=%s,svctm=%s,pct_util=%s %d",
                    hostname , words[0] , words[1] , words[2] , words[3] , words[4] , words[5] , words[6] , words[7] , words[8] , words[9] , words[10] , words[11] , words[12], words[13], timeInMillis);
               if (timeInMillis > timeInMillis_prv) {
                   sum_r_s += Float.parseFloat(words[3]);
                   sum_w_s += Float.parseFloat(words[4]);
                   sum_rkB_s += Float.parseFloat(words[5]);
                   sum_wkB_s += Float.parseFloat(words[6]);
                   File2Influx.Save_to_Influx_WriteApi(data, writeApi, org, bucket);
               }
            } 
         }
         // whenever seeing zzz line we save the sum with timeInMillis_prv
         // when the end of file reached, we need to save the sum as well with timeInMillis
         if (timeInMillis > 0)  {
            System.out.println(" ------  save sum data   ----");
            System.out.println(sum_rkB_s);
            data = String.format("iostat,host=%s sum_r_s=%.1f,sum_w_s=%.1f,sum_rkB_s=%.1f,sum_wkB_s=%.1f %d", 
                                 hostname,sum_r_s, sum_w_s, sum_rkB_s, sum_wkB_s, timeInMillis);
            File2Influx.Save_to_Influx_WriteApi(data, writeApi, org, bucket);
         }
      }
      catch (IOException e) {
         System.out.println("Unable to read oswiostatFile file");
         throw new RuntimeException(e);
      }
       
   }

   public static void process_oswiostat_file2(WriteApi writeApi, String org, String bucket, String oswiostatFile, String hostname) {
      // Proccessing Linux version of oswiostat file, file_type=="oswiostat2"
      String data;
      long timeInMillis=0;
      long timeInMillis_prv=0;
      try {
         BufferedReader in = new BufferedReader(new FileReader(oswiostatFile));
         String line;
         Float sum_r_s =0.0f;
         Float sum_w_s =0.0f;
         Float sum_rkB_s=0.0f;
         Float sum_wkB_s=0.0f;

         while ((line = in.readLine()) != null){
            String[] words = line.split("\\s+");

	         // System.out.println(words.length);
            if ( line.matches("^zzz(.*)") ) {
               timeInMillis_prv=timeInMillis;
               System.out.println(line);
               String dateStr=line.substring(7);
               System.out.println(dateStr);	
               DateTimeFormatter formatter = DateTimeFormatter.ofPattern("EEE MMM d H:m:s z yyyy");
               ZonedDateTime zDateTime = ZonedDateTime.parse(dateStr, formatter);
               System.out.println(zDateTime);	
               Instant instant = zDateTime.toInstant();	
	            timeInMillis = instant.toEpochMilli();
	            // System.out.println(timeInMillis);
	            System.out.println("--------");
               if (timeInMillis_prv > 0)  {
	               System.out.println(" ------  save sum data   ----");
	               System.out.println(sum_rkB_s);
                  data = String.format("iostat,host=%s sum_r_s=%.1f,sum_w_s=%.1f,sum_rkB_s=%.1f,sum_wkB_s=%.1f %d", 
                                       hostname,sum_r_s, sum_w_s, sum_rkB_s, sum_wkB_s, timeInMillis_prv);
                  File2Influx.Save_to_Influx_WriteApi(data, writeApi, org, bucket);
                  sum_r_s =0.0f;
                  sum_w_s =0.0f;
                  sum_rkB_s=0.0f;
                  sum_wkB_s=0.0f;
               }
            }
            else  if (  words.length == 12 &&  ! words[0].equals("Device:") ) {
               // data line  
               // Device:         rrqm/s   wrqm/s     r/s     w/s    rkB/s    wkB/s avgrq-sz avgqu-sz   await  svctm  %util
               // sdb               0.00     0.00    0.00    0.00     0.00     0.00     0.00     0.00    0.00   0.00   0.00
               data = String.format("iostat,host=%s,device=%s rrqm_s=%s,wrqm_s=%s,r_s=%s,w_s=%s,rkB_s=%s,wkB_s=%s,avgrq-sz=%s,avgqu-sz=%s,await=%s,svctm=%s,pct_util=%s %d",
                    hostname , words[0] , words[1] , words[2] , words[3] , words[4] , words[5] , words[6] , words[7] , words[8] , words[9] , words[10] , words[11] , timeInMillis);
               if (timeInMillis > timeInMillis_prv) {
                   sum_r_s += Float.parseFloat(words[3]);
                   sum_w_s += Float.parseFloat(words[4]);
                   sum_rkB_s += Float.parseFloat(words[5]);
                   sum_wkB_s += Float.parseFloat(words[6]);
                   File2Influx.Save_to_Influx_WriteApi(data, writeApi, org, bucket);
               }
            } 
         }
         // whenever seeing zzz line we save the sum with timeInMillis_prv
         // when the end of file reached, we need to save the sum as well with timeInMillis
         if (timeInMillis > 0)  {
            System.out.println(" ------  save sum data   ----");
            System.out.println(sum_rkB_s);
            data = String.format("iostat,host=%s sum_r_s=%.1f,sum_w_s=%.1f,sum_rkB_s=%.1f,sum_wkB_s=%.1f %d", 
                                 hostname,sum_r_s, sum_w_s, sum_rkB_s, sum_wkB_s, timeInMillis);
            File2Influx.Save_to_Influx_WriteApi(data, writeApi, org, bucket);
         }
      }
      catch (IOException e) {
         System.out.println("Unable to read oswiostatFile file");
         throw new RuntimeException(e);
      }
   }
}
