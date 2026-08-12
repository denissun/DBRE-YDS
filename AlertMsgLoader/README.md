# AlertMsgLoader

A lightweight Java utility that loads cron job alert messages into a centralized Oracle database table for consumption by other monitoring and alerting systems.

## Purpose

AlertMsgLoader provides a simple way to capture alert messages from various cron jobs and automated processes, storing them in a standardized schema. This enables:

- **Centralized alert aggregation**: Consolidate alerts from multiple databases and hosts into a single repository
- **Alert consumption**: Provide other applications (dashboards, notification systems) with structured alert data
- **Historical tracking**: Maintain a record of all alerts with timestamps and severity levels
- **Operational visibility**: Track database and infrastructure issues across your environment

## Usage

### Basic Syntax

```bash
java -jar AlertMsgLoader.jar <appcode> <db_name> <host_name> <title> <message-text-file-or-text> <severity>
```

### Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `appcode` | Vertical Segment/Account code | `EV6V` |
| `db_name` | Database name | `mposdb` |
| `host_name` | Hostname where the issue occurred | `hostname1` |
| `title` | Alert title/summary | `Alert - tablespace usage exceeds limit` |
| `message-text-file-or-text` | Path to file containing message, or text string | `msg.txt` or `"Error in backup"` |
| `severity` | Alert severity level | `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` |

### Examples

**Loading alert from a text file:**
```bash
java -jar AlertMsgLoader.jar EV6V mposdb hostname1 "Tablespace Usage Alert" /var/logs/alert_msg.txt CRITICAL
```

**Loading alert from inline text:**
```bash
java -jar AlertMsgLoader.jar EV6V mposdb hostname1 "Backup Failed" "Backup job failed at 2:30 AM" HIGH
```

## Features

- **File or Text Input**: Automatically detects whether the 5th argument is a file path or text string
- **Message Truncation**: Automatically truncates messages longer than 2500 characters (keeps first 1000 + last 1500 chars)
- **UTF-8 Support**: Handles UTF-8 encoded text files
- **Connection Validation**: Validates database connectivity before inserting data
- **Error Handling**: Reports SQL errors and connection issues with detailed messages

## Database Schema

Inserts data into the `cronjob_alert_msgs` table with the following columns:

| Column | Type | Description |
|--------|------|-------------|
| `appcode` | VARCHAR | Vertical Segment/Account code |
| `db_name` | VARCHAR | Database name |
| `host_name` | VARCHAR | Hostname |
| `title` | VARCHAR | Alert title |
| `msg` | CLOB/VARCHAR | Alert message content |
| `severity` | VARCHAR | Severity level |

## Technical Details

- **Language**: Java 8+
- **Dependencies**: Oracle JDBC Driver (ojdbc8)
- **Build Tool**: Maven
- **Packaging**: Uber JAR (all dependencies included)

## Building

```bash
mvn clean package
```

This creates `AlertMsgLoader.jar` in the `target/` directory.

## Version History

- **v2.0**: Added severity level parameter
- **v1.x**: Initial version supporting basic alert loading

## Notes

- The alert message is limited to 2500 characters. Messages longer than this will be truncated intelligently (keeping beginning and end)
- The database connection uses a predefined repository database (OEMTDPRD)
- All parameters are required; the program will exit with an error message if insufficient arguments are provided
