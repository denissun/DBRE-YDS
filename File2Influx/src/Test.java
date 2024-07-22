import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.time.format.DateTimeFormatter;
import java.time.LocalDate;
import java.util.Locale;
import java.time.ZonedDateTime;
import java.time.Instant;

public class Test {
    public static void main(String[] args) {
        //Pattern pattern = Pattern.compile(".*'([^']*)'.*");
        // Matcher matcher = pattern.matcher(mydata);


        //if(matcher.matches()) {
        //    System.out.println(matcher.group(1));
        //}

        String dateInString = "Mon, 05 May 1980";
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("EEE, d MMM yyyy", Locale.ENGLISH);
        LocalDate dateTime = LocalDate.parse(dateInString, formatter);
        // System.out.println(dateTime);	


        String mydata = "zzz ***Sun Mar 7 15:14:32 GMT 2021";
	String dateStr=mydata.substring(7);
        System.out.println(dateStr);	
        formatter = DateTimeFormatter.ofPattern("EEE MMM d H:m:s z yyyy");
        ZonedDateTime zDateTime = ZonedDateTime.parse(dateStr, formatter);
        System.out.println(zDateTime);	
        Instant instant = zDateTime.toInstant();	
	long timeInNanos = instant.toEpochMilli() * 1000;
	// System.out.println(timeInNanos);

        //
	String CpuIdle ="90.6";
        String CpuUser ="7.5";
        String CpuKernel ="1.8";
        String CpuIowait ="0.0";
	String hostname="host123";
	long timeInNaos =167888908;
        String data = String.format("host_cpu,host=%s total=%.1f,user=%s,kernel=%s,iowait=%s %d",hostname, 100-Float.parseFloat(CpuIdle), CpuUser, CpuKernel, CpuIowait, timeInNanos); 
	System.out.println(data);


    }
}
