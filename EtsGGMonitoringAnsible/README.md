ETS GG Monitoring Ansible Deployment
====================================

# Overview

In this project, a set of monitoring scripts for Oracle GoldenGate replication have been developed to collect related metrics and event data. Those data are then loaded into a repository Oracle database and presented in a dashboard, which is a component of a web applicaiton called DBAETS developed by Python Flask framework.

An automatic approach has been developed using Ansible playbook and Gitlab CI/CD capability to deploy the monitoring scripts to multiple target hosts.


# Automatic Deployment workflow

The automation workflow now taking place is as following:

1. On the control server, make any changes to the source code files, including any of the monitoring scripts, ansible and gitlab-ci yaml configuration files, hosts files. and then commit the changes.

2. Push to the remote Gitlab repository using "git push"

3. Gitlab CI/CD pipeline job kicks in automatically  and somehow wakes up the gitlab-runner on the control server.

4. The gitlab-runner on the control server fetches all the source code from gitlab master branch to a local working space, runs all the tasks defined in the .gitlab-ci.yml file.

5. Those gitlab-ci tasks are simply some shell commands, including calling ansible-playbook to run the tasks defined in the playbooks.

6. Ansible playbook tasks include sending monitoring scripts to all target hosts and set up the cron job automatically. 

# Monitoring scripts


* ets_gg_agent_5min.sh
* gg_error.sh
* gg_info_all.sh
* gg_log_chk.sh
* gg_mgr_alive.sh
* gg_operations.sh
* gg_params.sh
* ggconf.sh


# Deployment

Linux and Solaris target should be deployed separately

1. Create zip file

    To deplpoy need to first create  zip file in /tmp for Ets GG Monitoring Ansible deployment

```

	-- for Linux
	$ cd /dba/ansible/EtsGGMonitoringAnsible/ets_gg_monitoring
	$ zip /tmp/ets_gg_monitoring.zip * .dbpass

      
	-- for Solaris 
	$ cd /dba/ansible/EtsGGMonitoringAnsible/ets_gg_monitoring_sol
	$ zip /tmp/ets_gg_monitoring_sol.zip * .dbpass
```

2. Run playbook


```
   -- Linux   
   ansible-playbook -i inventory_dir/ deploy_etsGGMonitoring.yml

   -- Solaris   
   ansible-playbook -i inventory_dir/ deploy_etsGGMonitoring_sol.yml


```

    note: edit inventory_dir/hosts_gg file to comment/uncomment hosts as needed

# MISC

## ansible-playbook reference

```

    ansible-playbook -i hosts_gg  test_deploy.yml

    $ ansible [pattern] -m [module] -a "[module options]"


	ansible dbservers -i hosts  -m ping 

	ansible all -i hosts  -m ping 

	ansible all -i hosts  -a "uname -a" 

	ansible all -i hosts  -a "id -a "

```

## Dashbord UI screenshots


![Alt text](/EtsGGMonitoringAnsible/img/gg1.png "fig 1")

![Alt text](/EtsGGMonitoringAnsible/img/gg2.png "fig 2")

![Alt text](/EtsGGMonitoringAnsible/img/gg3.png "fig 3")