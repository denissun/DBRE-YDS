rem to escape quotation mark
rem exampele:  @print 'select * from v$sqlarea where sql_id=''9a31rc8qh0215'' '
rem

set serverout on size 1000000
declare
 p_query   varchar2(32767) := q'[&1]';
 p_date_fmt varchar2(50) := 'MM/DD/YYYY hh24:mi:ss' ;
 l_theCursor     integer default dbms_sql.open_cursor;
 l_columnValue   varchar2(4000);
 l_status        integer;
 l_descTbl       dbms_sql.desc_tab2;
 l_colCnt        number;
 l_cs            varchar2(255);
 l_date_fmt      varchar2(255);
 procedure restore is
    begin
       if ( upper(l_cs) not in ( 'FORCE','SIMILAR' )) then
           execute immediate 'alter session set cursor_sharing=exact';
       end if;
       if ( p_date_fmt is not null ) then
           execute immediate 'alter session set nls_date_format=''' || l_date_fmt || '''';
       end if;
       dbms_sql.close_cursor(l_theCursor);
    end restore;
begin
    if ( p_date_fmt is not null ) then
       select sys_context( 'userenv', 'nls_date_format' ) into l_date_fmt from dual;
       execute immediate 'alter session set nls_date_format=''' || p_date_fmt || ''''; 
    end if;
    if ( dbms_utility.get_parameter_value ( 'cursor_sharing', l_status, l_cs ) = 1 ) then
        if ( upper(l_cs) not in ('FORCE','SIMILAR')) then
            execute immediate 'alter session set cursor_sharing=force';
        end if;
    end if;
    dbms_sql.parse(  l_theCursor,  p_query, dbms_sql.native );
    dbms_sql.describe_columns2 ( l_theCursor, l_colCnt, l_descTbl );
    for i in 1 .. l_colCnt loop    
		if ( l_descTbl(i).col_type not in ( 113 ) ) then
        	dbms_sql.define_column(l_theCursor, i, l_columnValue, 4000);
		end if;
    end loop;
    l_status := dbms_sql.execute(l_theCursor);
    while ( dbms_sql.fetch_rows(l_theCursor) > 0 ) 
    loop
        for i in 1 .. l_colCnt loop
	    if ( l_descTbl(i).col_type not in ( 113 ) ) then
            	dbms_sql.column_value( l_theCursor, i, l_columnValue );
            	dbms_output.put_line( rpad( l_descTbl(i).col_schema_name || '.' 
				|| l_descTbl(i).col_name, 30 )|| ': ' || substr( l_columnValue, 1, 200 ) );
	    end if;
        end loop;
        dbms_output.put_line( '-----------------' );
    end loop;
    restore;
exception
    when others then
        restore;
        raise;
end;
/
undef 1
undef 1
clear columns	
