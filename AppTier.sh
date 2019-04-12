#!/bin/bash

# TODO: echos and piping to null
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get update
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
sudo apt-get install -y oracle-java8-installer
sudo apt-get install -y maven
sudo apt install -y xvfb

cd AppTier
mvn clean package
mv ./target/AppTier-1.0.0.jar ~/darknet

cd ../AppTier_Terminator
mvn clean package
mv ./target/AppTier_Terminator-1.0.0.jar ~/darknet

cd ../darknet
Xvfb :1 & export DISPLAY=:1
java -jar AppTier-1.0.0.jar