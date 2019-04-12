#!/bin/bash

# TODO: echos and piping to null
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get update
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
sudo apt-get install -y oracle-java8-installer
sudo apt-get install -y maven
mvn clean package
mv ./target/WebTier-1.0.0.jar .
java -jar WebTier-1.0.0.jar