# Test Horton

My time was kind of limited for this test after the Ansible one, I was lucky I found this repo (https://github.com/AnisBidhani/US_Baby_Names_Analytics) that contains most of the thing I needed for the test and for me to have an easy start.

hdadmin shell script was modified to add some step, like crontjob, downloading data, fix ssh section, drop some ^M from scripts...

to change perms from Ambari, changing dfs.namenode.acls.enabled in /etc/hadoop/conf was useless, i didn't find better solution than doing it directly from the console : HDFS -> Configs -> Advanced -> Custom hdfs-site.xml then add dfs.namenode.acls.enabled=true and then Save.

Then our hdadmin.sh could run.


## Use http://hortonworks.com/products/sandbox/

Website and documentation from Hortonworks is quite nice :

- install docker
- download https://downloads-hortonworks.akamaized.net/sandbox-hdp-2.6.4/start-sandbox-hdp-standalone_2-6-4.sh.zip
- unzip it
- `sh start-sandbox-hdp-standalone_2-6-4.sh`

## Setup scheduled automated ingest to hive tables

It was hard to get the data from cli from kaggle, a python package kaggle-cli exist but it's not working with datasets, only with competitions.

It would have been possible to download it with extracting the cookie from my browser and use it in wget, but I didn't want to go that far, and I will just suppose the data is on https://castillo.cloud/

```
#!/bin/bash                                                                                                                   
# make sure latest csv                                                                                                
sudo rm -fr /var/tmp/*.csv                                                                                                    
wget https://castillo.cloud/NationalNames.csv https://castillo.cloud/StateNames.csv -P /var/tmp/                              
echo "Removing files header and Copying the raw data files to the HDFS data ingestion directory"                              
sed -i 1d /var/tmp/NationalNames.csv /var/tmp/StateNames.csv                                                             
head /var/tmp/NationalNames.csv /var/tmp/StateNames.csv
# move our local csv's to hdfs and force the move (-f)
sudo -u hdfs hdfs dfs -copyFromLocal -f /var/tmp/NationalNames.csv /user/hdadmin/USBabyNamesAnalytics/RawData/National           
sudo -u hdfs hdfs dfs -copyFromLocal -f /var/tmp/StateNames.csv /user/hdadmin/USBabyNamesAnalytics/RawData/State
# Make sure to have the latest Ingestion script
sudo -u hdadmin rm -fr /home/hdadmin/*.hive                                                                                   
sudo -u hdadmin wget https://raw.githubusercontent.com/AnisBidhani/US_Baby_Names_Analytics/master/Data_Ingestion_Script.hive -P /home/hdadmin/
# Make sure to drop weird ^M in script.
sudo -u hdadmin sed -i -e 's/\r$//' /home/hdadmin/Data_Ingestion_Script.hive
# Ingest data to hive.
sudo -u hdadmin hive -f /home/hdadmin/Data_Ingestion_Script.hive
```

Add this script to crontab (every 30 minutes) :

- `echo "*/30 * * * * /root/scripts/ingestscript.sh" | tee -a /var/spool/cron/root`


## As result the customer wants to see simple query on Hive showing the most popular female and male names for each year

I changed as well the SQL to find the most popular female and male names for each year. (took me a while as i never really learned SQL)

```
SELECT
    n.name,
    am.gender,
    am.year,
    am.count
FROM
    us_baby_names_db.mynationalnames n
INNER JOIN (
    SELECT
        gender,
        year,
        MAX(count) as count
    FROM
        us_baby_names_db.mynationalnames
    GROUP BY
        year, gender
) am ON n.count = am.count AND n.year = am.year AND n.gender = am.gender
ORDER BY am.year DESC, am.gender DESC
```

![Result from request](https://image.ibb.co/hb1max/unknown.png)


## Add new user with the admin permissions and ban connecting to the server as root, only admins can use sudo

user hdadmin has been added.
```
echo "hdadmin ALL=(ALL) ALL" >> /etc/sudoers
echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
service sshd reload
```

## Allow access to ingested data only for “hive-ingest-users” group

I'm not sure it's *only* for hive-ingest-users.
```
sudo -u hdfs hdfs dfs -setfacl -m user:hdadmin:rwx /user/hdadmin/USBabyNamesAnalytics
sudo -u hdfs hdfs dfs -setfacl -m group:hive-ingest-users:rwx /user/hdadmin/USBabyNamesAnalytics
sudo -u hdfs hdfs dfs -getfacl -R /user/hdadmin/USBabyNamesAnalytics
```

## Show cluster performance stats (at onsite demo)

It's available directly on : http://sandbox-hdp.hortonworks.com:8080/#/main/dashboard/metrics

## (OPTIONAL) Provide way for doing transformation after the ingest into Hive

I'm not sure what you mean by *transformation*.

## (OPTIONAL) Provide way for data retention - i.e. how to move older data to lower redundancy(cheaper) storage and eventually delete them.

I will propose to move the older data files to s3 reduced redundacy(cheap), eventually  in Glacier if you can afford to wait 2-3 hours to retrive data (even cheaper) and then eventually delete them.

It can be set with a lifecycle policy in AWS.

![lifecycle](https://www.cloudberrylab.com/blog/wp-content/uploads/2016/04/amazon-s3-amazon-glacier-lifecycle-example.png)