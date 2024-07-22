package File2Influx;

import org.joda.time.LocalTime;
import com.influxdb.client.InfluxDBClient;
import com.influxdb.client.InfluxDBClientFactory;
import com.influxdb.client.WriteApi;
import com.influxdb.client.domain.WritePrecision;
import com.influxdb.client.WriteOptions;
import java.io.*;
import java.util.*; 


public class File2Influx {
   
   public static Properties loadProperties(String fileName) throws IOException {
      final Properties envProps = new Properties();
      final FileInputStream input = new FileInputStream(fileName);
      envProps.load(input);
      input.close();
      return envProps;
   }

   public static void Save_to_Influx(String data, InfluxDBClient client, String org, String bucket) {
      try (WriteApi writeApi = client.getWriteApi()) {
          writeApi.writeRecord(bucket, org, WritePrecision.MS, data);
          System.out.println("#####" + data + " is written to influxdb: " + org + " - " + bucket);
      }
   }  

   public static void Save_to_Influx_WriteApi(String data, WriteApi writeApi, String org, String bucket) {
      writeApi.writeRecord(bucket, org, WritePrecision.MS, data);
      // System.out.println("### In Save_to_Influx_WriteApi : \n" + data + "\n  is written to influxdb: " + org + " - " + bucket + "\n\n");
   }  
  
   
   public static void main(String[] args) {
      Helper helper = new Helper();
      if (args.length !=4 ) {
          System.out.println("Wrong number of arguments");
          helper.printUsage();
          System.exit(1);
      }
      
      LocalTime currentTime = new LocalTime();
      System.out.println("the current local time is: " + currentTime);
      System.out.println(helper.sayHello());
      helper.printUsage();

      String propertyFile=args[0];

      try {
         Properties props = loadProperties(propertyFile);
         String token = props.getProperty("token");
         String influxdb_url = props.getProperty("influxdb_url");
         String org = props.getProperty("org");
         String bucket = props.getProperty("bucket");
         String tzcode=props.getProperty("tzcode");

         InfluxDBClient client = InfluxDBClientFactory.create(influxdb_url, token.toCharArray());

         String inputFile=args[1];
         String fileType=args[2];
         String hostname=args[3];

         if  ( fileType.equals("oswtop") ) {
            OswTopFileParser.process_oswtop_file(client, org, bucket, inputFile, hostname);
         }
         else if ( fileType.equals("oswtop2") ) {
            OswTopFileParser.process_oswtop_file2(client, org, bucket, inputFile, hostname);
         }
         else if ( fileType.equals("oswiostat2") ) {
            WriteApi writeApi = client.getWriteApi(WriteOptions.builder().flushInterval(5_000).build());
            OswIostatFileParser.process_oswiostat_file2(writeApi, org, bucket, inputFile, hostname);
         }
         else if ( fileType.equals("oswiostat2a") ) {
            WriteApi writeApi = client.getWriteApi(WriteOptions.builder().flushInterval(5_000).build());
            OswIostatFileParser.process_oswiostat_file2a(writeApi, org, bucket, inputFile, hostname);
            writeApi.close();
         }
         else if ( fileType.equals("oswiostat3") ) {
            // 16 fields
            WriteApi writeApi = client.getWriteApi(WriteOptions.builder().flushInterval(5_000).build());
            OswIostatFileParser.process_oswiostat_file3(writeApi, org, bucket, inputFile, hostname);
            writeApi.close();
         }
         else if ( fileType.equals("eventSysmetric") ) {
            // java -jar File2Influx.jar influx.properties topwaitevet.csv eventSysmetric vvoscpd1_vvoprdsc
            WriteApi writeApi = client.getWriteApi();
            // process_event_sysmetric_file(client, org, bucket, inputFile, hostname, tzcode);
            EventSysmetricFileParser.process_event_sysmetric_file_a(writeApi, org, bucket, inputFile, hostname, tzcode);
            writeApi.close();
         }
         else {
            System.out.println("Warning - file_type not found!  ");
            helper.printUsage();
            System.exit(1);
         }
      }
      catch (IOException e) {
         System.out.println("Unable to read Properties file");
         throw new RuntimeException(e);
      }
   }
}