-- check to see if debug is disabled

select text  from dba_source where name='DEBUG' and instr(text, 'return;') > 0;

set doc off
doc

if we see the following line in the output we know debug is disabled :

return;  -- added to make FA NOOP
return;  -- add to make F NOOP

#



