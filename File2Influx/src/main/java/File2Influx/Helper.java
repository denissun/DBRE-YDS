package File2Influx;

public class  Helper {
   public String sayHello() {
      return "Welcome to File2Influx by Yu (Denis) Sun!";
   }
   public void printUsage() {
      System.out.println("--------------------------------------------------------------------------------------\n" );
      System.out.println("File2Influx : Load time series data from files to InfluxDB \n\n"
             + "  Usage         : java -jar File2Influx.jar propertyFile inputFile inputFileType tagName\n\n"
             + "  propertyFile  : A config file that contains InfluxDB connect info\n" 
             + "  inputFile     : A text file that contains the data\n" 
             + "  inputFileType : \n" 
             + "                  oswtop         - Solaris version of OSWatcher oswtop file \n" 
             + "                  oswtop2        - Linux version of OSWatcher oswtop file \n" 
             + "                  oswiostat3     - Linux version of OSWatcher iostat file (16 fields) \n" 
             + "                  eventSysmetric - A CSV file that contains top 5 wait events \n"
             + "                                   and system metrics data of Oracle database \n" 
             + "  tagName       : InfluxDB line protocol tag key value e.g. host_name \n" 
      );
      System.out.println("--------------------------------------------------------------------------------------\n" );
   }
}
