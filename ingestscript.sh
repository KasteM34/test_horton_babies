#!/bin/bash                                                                                                                   
# make sure latest csv                                                                                                
sudo rm -fr /var/tmp/*.csv                                                                                                    
wget https://castillo.cloud/NationalNames.csv https://castillo.cloud/StateNames.csv -P /var/tmp/                              
echo "Removing files header and Copying the raw data files to the HDFS data ingestion directory"                              
sudo sed -i 1d /var/tmp/NationalNames.csv /var/tmp/StateNames.csv                                                             
sudo head /var/tmp/NationalNames.csv /var/tmp/StateNames.csv
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
