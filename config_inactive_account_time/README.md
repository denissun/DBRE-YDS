Purpose:

   set INACTIVE_ACCOUNT_TIME limit to be 90 days for the profiles which have PASSWORD_LIFE_TIME less or equal to 90 

Description of the approach:

   We have hundreds of database servers. It will be tedious if I have to log into each database and manually run the script
   to set the parameter.  Here I take advantage of  Ansible to  perform the task from a control server by looping through a 
   list of db servers and run the Ansible playbook  
   

List of scripts:

  config_inactive_accttime_driver.sh

     this script runs on the control server

  config_inactive_accttime.yml

     Ansible Playbook configuraiton file that defines each task

  config_inactive_accttime.sh

      copy to the target server to run automatically

  config_inactive_accttime.sql

      copy to the target server to run automatically

  hosts.cfg

      contain a list of database hosts 


To perform the task, typically  run the script as follows:


   $> ./config_inactive_accttime_driver.sh hosts.cfg 

