#!/bin/bash
# modified version from https://github.com/AnisBidhani/US_Baby_Names_Analytics
set +x

USERNAME=hdadmin
PASSWORD=hdadmin
GROUPNAME=hive-ingest-users

user_exists=$(id -u $USERNAME > /dev/null 2>&1; echo $?)

if [ $user_exists -eq 1 ]; then
sudo useradd $USERNAME

echo "********* Creating a new user $USERNAME. *********"

read -s -p "Enter password : " PASSWORD
echo $USERNAME:$PASSWORD | sudo chpasswd
echo ""
echo "********* User $USERNAME has been successfully created and password changed. *********"

echo "Creating a Hive Data Ingestion group and assigning the new user to it."
sudo groupadd $GROUPNAME
sudo usermod -a -G $GROUPNAME $USERNAME
sudo usermod -aG wheel $USERNAME
sudo usermod -aG hadoop $USERNAME

echo "********* User $USERNAME has been assigned to newly created group $GROUPNAME. *********"

egrep "^$USERNAME" /etc/passwd >/dev/null
echo "Creating a HDFS home directory for hdadmin"
sudo -u hdfs hdfs dfs -mkdir /user/hdadmin
sudo -u hdfs hdfs dfs -chown -R hdadmin:hdfs /user/hdadmin

echo "********* The HDFS home directory for user $USERNAME has been successfully created. *********"

sleep 15
else
echo "$USERNAME already exists"
fi

echo "Creating a HDFS data ingestion directory"
sudo -u hdfs hdfs dfs -mkdir -p /user/hdadmin/USBabyNamesAnalytics/RawData/National
sudo -u hdfs hdfs dfs -mkdir -p /user/hdadmin/USBabyNamesAnalytics/RawData/State

echo "********* The data ingestion directories have been successfully created under HDFS. *********"
echo " make sure latest csv"
sudo rm -fr /var/tmp/*.csv
wget https://castillo.cloud/NationalNames.csv https://castillo.cloud/StateNames.csv -P /var/tmp/

echo "Removing files header and Copying the raw data files to the HDFS data ingestion directory"
sudo sed -i 1d /var/tmp/NationalNames.csv /var/tmp/StateNames.csv
sudo head /var/tmp/NationalNames.csv /var/tmp/StateNames.csv
sudo -u hdfs hdfs dfs -copyFromLocal /var/tmp/NationalNames.csv /user/hdadmin/USBabyNamesAnalytics/RawData/National
sudo -u hdfs hdfs dfs -copyFromLocal /var/tmp/StateNames.csv /user/hdadmin/USBabyNamesAnalytics/RawData/State

echo "********* The raw CSV files were successfully placed into HDFS data ingestion directories. *********"

echo "Setting the necessary ACLs for the newly created user $USERNAME "
sudo -u hdfs hdfs dfs -setfacl -m user:hdadmin:rwx /user/hdadmin
sudo -u hdfs hdfs dfs -setfacl -m group:hdfs:rwx /user/hdadmin
sudo -u hdfs hdfs dfs -getfacl -R /user/hdadmin

echo "********* The ACLs have been set for user $USERNAME in HDFS. *********"

echo "Setting the necessary ACLs for the group hive-ingest-users to access the data ingestion directory"
sudo -u hdfs hdfs dfs -setfacl -m user:hdadmin:rwx /user/hdadmin/USBabyNamesAnalytics
sudo -u hdfs hdfs dfs -setfacl -m group:hive-ingest-users:rwx /user/hdadmin/USBabyNamesAnalytics
sudo -u hdfs hdfs dfs -getfacl -R /user/hdadmin/USBabyNamesAnalytics

echo "********* The ACLs have been set for group $GROUPNAME in HDFS. *********"

echo "Restricting Root access and add new users to sudoers."
echo "hdadmin ALL=(ALL) ALL" >> /etc/sudoers
echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
service sshd reload

echo "********* Config changes have been made to SSH service and service reloaded. *********"

echo "********* Running a Hive script called: Data_Ingestion_Script. *********"
sudo -u hdadmin rm -fr /home/hdadmin/Data_Ingestion_Script.hive
sudo -u hdadmin wget https://raw.githubusercontent.com/AnisBidhani/US_Baby_Names_Analytics/master/Data_Ingestion_Script.hive -P /home/hdadmin/
sudo -u hdadmin sed -i -e 's/\r$//' /home/hdadmin/Data_Ingestion_Script.hive
sudo -u hdadmin hive -f /home/hdadmin/Data_Ingestion_Script.hive

echo "********* Hive Data Ingestion Script has successfully completed. *********"

echo "automated ingestion setup"
echo "*/30 * * * * su - hdadmin -c '/usr/bin/hive -f /home/hdadmin/Data_Ingestion_Script.hive'" | tee -a /var/spool/cron/root