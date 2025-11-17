SET SERVEROUTPUT ON

define label=&1 

DECLARE
BEGIN
    FOR r IN (
	SELECT  /* realtime_hc */
	    ORIGINATING_TIMESTAMP, 
	    INSTANCE_ID, 
	    MESSAGE_TEXT
	FROM  
	    alertlog 
	WHERE 
	    ORIGINATING_TIMESTAMP > SYSDATE - 5/1440
	ORDER BY 
            INSTANCE_ID, ORIGINATING_TIMESTAMP
    ) 
    LOOP
	    -- Output
	    DBMS_OUTPUT.PUT_LINE('~ALERT~&label | ' || r.INSTANCE_ID || '| ' || r.ORIGINATING_TIMESTAMP);
	    DBMS_OUTPUT.PUT_LINE('~ALERT~&label | ' || r.INSTANCE_ID || '| ' || r.message_text);
    END LOOP;
END;
/
