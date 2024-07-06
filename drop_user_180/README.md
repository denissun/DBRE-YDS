drop_user_180
=============

## Purpose

Set up a process that runs on all DB's to drop human user accounts if the user has not logged in for 180 days and the user does not own any objects. 

If the user owns at least one object, the user account shall be reviewd and a desision shall be decided on whether to drop it or not.

The drop user account action should be recoreded in our inventory database with the details of the user name, database name, action time etc. 

## Method

To start the process, running the driver script as follows:

```
drop_user_driver.sh hosts.cfg

```

The driver script loops through each host in the hosts.cfg and invokes the Ansible Playbook command to push scripts to the target host, then run against each database on the host to drop the users.
