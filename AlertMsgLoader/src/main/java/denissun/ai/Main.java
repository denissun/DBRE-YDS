package denissun.ai;

import java.sql.*;

import java.io.IOException;
import java.nio.file.Paths;
import java.nio.file.Files;
import java.nio.file.Path;

public class Main {
    public static void main(String[] args) throws Exception {

        // check number of args and print out usage


        int numberOfArguments = args.length;

        if (numberOfArguments < 6) {
            System.out.println("Wrong number of arguments: " + numberOfArguments +" found, 6 expected");
            System.out.println("Usage: " + "java -jar AlertMsgLoader.jar <appcode> <db_name> <host_name> <title> <message-text-file-or-text> <severity>");
            System.out.println("     Note:  if the 5th argument is not a text file, it will be treated as text string");
            System.exit(0);
        }


        String appcode =args[0];
        String db =args[1];
        String host =args[2];
        String title =args[3];
        String severity =args[5];

        // check  if the 5th args is a file if not treat it as a string
        String filePath = args[4];

        Path path = Paths.get(filePath);

        String fileContent;
        if (Files.exists(path)) {
            System.out.println("File exists: " + filePath);
            byte[] fileBytes = Files.readAllBytes(Paths.get(filePath));
            fileContent = new String(fileBytes, "UTF-8");
        } else {
            System.out.println("File does not exist: \"" + filePath + "\". We use 5th arg as text string");
            fileContent = filePath;
        }

        if ( fileContent.length() > 2500 )
            fileContent = fileContent.substring(0, 1000) + fileContent.substring(fileContent.length() - 1500);

        System.out.println(appcode +  ",  " + db + ",  " + host + ", " + title  + ", " + severity);
        // System.out.println(fileContent);

        Connection conn=null;
        try {
            // the following are masked with dummpy data
            // better programing practice is not to hard code such db configuration certainly
            // but this utility java program is compiled to jar file and deployed to different server
            // more conveniently with hard coded db connection credentials
            String ALERTMSG_REPO_DSN = "dbscan.mycomanpy.com:1521/repodb";
            String ALERTMSG_REPO_USER = "alertmsg";
            String ALERTMSG_REPO_PASS = "xxxxx";

            conn = DriverManager.getConnection(
                    "jdbc:oracle:thin:@" + ALERTMSG_REPO_DSN, ALERTMSG_REPO_USER, ALERTMSG_REPO_PASS);
            // Check if the connection is valid
            boolean reachable = conn.isValid(10); // 10 seconds timeout
            if (reachable) {
                System.out.println("Connection to the database is successful!");
            } else {
                System.out.println("Connection to the database is not valid.");
            }

            String sql = "INSERT INTO cronjob_alert_msgs (appcode, db_name, host_name, title, msg,severity) " +
                   " VALUES (?,?,?,?,?,?)"; // Adjust column names

            PreparedStatement statement  = conn.prepareStatement(sql);

            statement.setString(1, appcode);
            statement.setString(2, db);
            statement.setString(3, host);
            statement.setString(4, title);
            statement.setString(5, fileContent);
            statement.setString(6, severity);
            try {
                statement.executeUpdate();
                System.out.println("Alert message loaded!");
                System.out.println("----------------");
            } catch (SQLException e) {
                System.err.format("SQL State: %s\n%s\n", e.getSQLState(), e.getMessage());
                System.err.println("Error inserting: [" + title + "] " + db + " " + host );
            }

        } catch (SQLException e) {
            System.err.println("Database connection error: " + e.getMessage());
        } finally {
           // Close the connection in the finally block
            if (conn != null) {
                try {
                    conn.close();
                } catch (SQLException e) {
                    // Ignore or log the exception if the connection cannot be closed
                }
            }
        }
   }
}
