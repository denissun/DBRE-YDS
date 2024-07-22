package File2Influx;

import java.io.FileReader;
import java.io.IOException;
import java.time.Instant;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;

import com.influxdb.client.WriteApi;
import com.opencsv.CSVReader;

public class EventSysmetricFileParser {
   
   public static void process_event_sysmetric_file_a(WriteApi writeApi, String org, String bucket, String inputFile, String tagname, String tzcode) {
      String data="";
      long timeInMillis=0;
      try (CSVReader csvReader = new CSVReader(new FileReader(inputFile));) {
         String[] words = null;
         while ((words = csvReader.readNext()) != null) {
            if (  words.length == 9  ) {
                // "vvoscpd6_vvorptsc","db file sequential read","66","User I/O","2021-03-10 08:25:02","2021-03-10 08:30:01","9.4","1","2021-03-10 08:30:02"
               String event = words[1];
               String pct =words[2];
               String aas_evt=words[6];

               String dateStr=words[8];
               System.out.println(dateStr + " " + tzcode);	
               DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd H:m:s z");
               ZonedDateTime zDateTime = ZonedDateTime.parse(dateStr + " " + tzcode, formatter);
               System.out.println(zDateTime);	
               Instant instant = zDateTime.toInstant();	
	            timeInMillis = instant.toEpochMilli();

               data = String.format("event,event_name=%s,service_name=%s percent_of_dbtime=%s,aas_evt=%s %d",event.replace(" ","_"),tagname,pct, aas_evt, timeInMillis);
               System.out.println(data);
               // Save_to_Influx(data, client, org, bucket);
               File2Influx.Save_to_Influx_WriteApi(data, writeApi, org, bucket); 
            }
            else if ( words.length == 2 ) {
               String metric_name=words[0];
               String metric_value=words[1];
               data = String.format("sysmetric,metric_name=%s,service_name=%s value=%s %d", metric_name.replace(" ","_"), tagname, metric_value, timeInMillis);
               System.out.println(data);
               File2Influx.Save_to_Influx_WriteApi(data, writeApi, org, bucket); 
            }
         }
      }
      catch (IOException e) {
         System.out.println("Unable to read input file");
         throw new RuntimeException(e);
      }
      catch (com.opencsv.exceptions.CsvValidationException e) {
         System.out.println("Unable to read input file");
         throw new RuntimeException(e);
      }
   }

}
