#!/bin/bash

vs_s3_bucket_name="vs-result-bucket-adi"

vs_input_queue_name="vs_input_queue"
vs_output_queue_name="vs_output_queue"

vs_vpc_name="vs_vpc"
vs_internet_gateway_name="vs_internet_gateway"
vs_subnet_name="vs_subnet"
vs_security_group_name="vs_security_group"
vs_key_pair_name="vs_key_pair"

vs_instance_profile_name="vs_instance_profile"
vs_role_name="vs_role"

vs_web_instance_name="web_instance"
vs_app_instance_name="app_instance_1"

vs_app_instance_ami_name="vs_app_instance_ami"

vs_vpc_cidr_block="10.0.0.0/16"
vs_subnet_cidr_block="10.0.0.0/24"

vs_web_image_id="ami-06397100adf427136"
vs_web_instance_type="t2.micro"
vs_web_instance_count=1

vs_app_image_id="ami-0e355297545de2f82"
vs_app_instance_type="t2.micro"
vs_app_instance_count=1


if [ "$1" == "create" ]; then
	echo 'BUILDING UP THE INFRASTRUCTURE'

	# TODO: code for non available s3 bucket

	echo 'creating S3 bucket...'
	aws_region=`aws configure get region`
	s3_bucket_url=`aws s3api create-bucket --bucket $vs_s3_bucket_name --region $aws_region --create-bucket-configuration LocationConstraint=$aws_region --query 'Location' --output text`
	echo "vs_s3_bucket_name=$vs_s3_bucket_name" > aws-resources.properties

	echo 'creating SQS input queue...'
	input_queue_url=`aws sqs create-queue --queue-name $vs_input_queue_name --query 'QueueUrl' --output text`
	echo "vs_input_queue_url=$input_queue_url" >> aws-resources.properties

	echo 'creating SQS output queue...'
	output_queue_url=`aws sqs create-queue --queue-name $vs_output_queue_name --query 'QueueUrl' --output text`
	echo "vs_output_queue_url=$output_queue_url" >> aws-resources.properties

	echo 'creating VPC...'
	vpc_id=`aws ec2 create-vpc --cidr-block $vs_vpc_cidr_block --query 'Vpc.VpcId' --output text`
	aws ec2 create-tags --resources $vpc_id --tags "Key=\"Name\",Value=\"$vs_vpc_name\""

	echo 'enabling DNS for VPC...'
	aws ec2 modify-vpc-attribute --vpc-id $vpc_id --enable-dns-support "{\"Value\":true}"
	aws ec2 modify-vpc-attribute --vpc-id $vpc_id --enable-dns-hostnames "{\"Value\":true}"

	echo 'creating internet gateway...'
	internet_gateway_id=`aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text`
	aws ec2 create-tags --resources $internet_gateway_id --tags "Key=\"Name\",Value=\"$vs_internet_gateway_name\""

	echo 'attaching internet gateway to VPC...'
	aws ec2 attach-internet-gateway --internet-gateway-id $internet_gateway_id --vpc-id $vpc_id

	echo 'creating subnet...'
	subnet_id=`aws ec2 create-subnet --vpc-id $vpc_id --cidr-block $vs_subnet_cidr_block --query 'Subnet.SubnetId' --output text`
	aws ec2 create-tags --resources $subnet_id --tags "Key=\"Name\",Value=\"$vs_subnet_name\""
	echo "vs_subnet_id=$subnet_id" >> aws-resources.properties

	echo 'creating routes...'
	route_table_id=`aws ec2 describe-route-tables --filters Name=vpc-id,Values=$vpc_id --query 'RouteTables[0].RouteTableId' --output text`
	aws ec2 create-route --route-table-id $route_table_id --destination-cidr-block 0.0.0.0/0 --gateway-id $internet_gateway_id > /dev/null

	echo 'creating security group...'
	security_group_id=`aws ec2 create-security-group --group-name $vs_security_group_name --description $vs_security_group_name --vpc-id $vpc_id --query 'GroupId' --output text`
	aws ec2 create-tags --resources $security_group_id --tags "Key=\"Name\",Value=\"$vs_security_group_name\""
	echo "vs_security_group_id=$security_group_id" >> aws-resources.properties

	echo 'allowing incoming traffic...'
	aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 22 --cidr 0.0.0.0/0
	aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 80 --cidr 0.0.0.0/0
	aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 443 --cidr 0.0.0.0/0
	aws ec2 authorize-security-group-ingress --group-id $security_group_id --protocol tcp --port 8080 --cidr 0.0.0.0/0

	echo 'creating key pair...'
	aws ec2 create-key-pair --key-name $vs_key_pair_name --query 'KeyMaterial' --output text > ~/.ssh/$vs_key_pair_name.pem
	chmod 400 ~/.ssh/$vs_key_pair_name.pem
	echo "vs_key_pair_name=$vs_key_pair_name" >> aws-resources.properties

	echo 'creating instance profile...'
	aws iam create-instance-profile --instance-profile-name $vs_instance_profile_name > /dev/null
	echo "vs_instance_profile_name=$vs_instance_profile_name" >> aws-resources.properties

	echo 'creating role...'
	aws iam create-role --role-name $vs_role_name --assume-role-policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":[\"ec2.amazonaws.com\"]},\"Action\":[\"sts:AssumeRole\"]}]}" > /dev/null

	echo 'attaching policies to role...'
	aws iam attach-role-policy --role-name $vs_role_name --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
	aws iam attach-role-policy --role-name $vs_role_name --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess
	aws iam attach-role-policy --role-name $vs_role_name --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
	aws iam attach-role-policy --role-name $vs_role_name --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

	echo 'attaching role to instance profile...'
	aws iam add-role-to-instance-profile --instance-profile-name $vs_instance_profile_name --role-name $vs_role_name

	# to avoid race condition of using run-instances just after creating instance profile
	sleep 10

	echo 'creating web instance...'
	web_instance_id=`aws ec2 run-instances --iam-instance-profile Name=$vs_instance_profile_name --image-id $vs_web_image_id --count $vs_web_instance_count --instance-type $vs_web_instance_type --key-name $vs_key_pair_name --security-group-ids $security_group_id --subnet-id $subnet_id --associate-public-ip-address --query "Instances[0].InstanceId" --output text`
	aws ec2 create-tags --resources $web_instance_id --tags "Key=\"Name\",Value=\"$vs_web_instance_name\""

	echo 'creating first app instance...'
	app_instance_id=`aws ec2 run-instances --iam-instance-profile Name=$vs_instance_profile_name --image-id $vs_app_image_id --count $vs_app_instance_count --instance-type $vs_app_instance_type --key-name $vs_key_pair_name --security-group-ids $security_group_id --subnet-id $subnet_id --associate-public-ip-address  --query "Instances[0].InstanceId" --output text`
	aws ec2 create-tags --resources $app_instance_id --tags "Key=\"Name\",Value=\"$vs_app_instance_name\""

	# for proper creation of ec2 instances
	echo "finalizing creation..."
	sleep 60 # TODO: can be reduced?


elif [ "$1" == "deploy-project" ]; then

	vpc_id=`aws ec2 describe-vpcs --filters Name=tag:Name,Values=$vs_vpc_name  --query 'Vpcs[0].VpcId' --output text`

	# # echo "###################################"
	# # echo "###### DEPLOYING APP-TIER #########"
	# # echo "###################################"

	cp aws-resources.properties ./AppTier/src/main/resources
	cp aws-resources.properties ./AppTier_Terminator/src/main/resources

	app_instance_ip=`aws ec2 describe-instances --filters Name=tag:Name,Values=$vs_app_instance_name Name=vpc-id,Values=$vpc_id --query 'Reservations[0].Instances[0].PublicIpAddress' --output text`
	ssh    -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no ubuntu@$app_instance_ip <<-HERE
		mkdir AppTier
		mkdir AppTier_Terminator
		exit
	HERE
	scp    -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no    darknet_test.py ubuntu@$app_instance_ip:~/darknet/
	scp    -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no    yolov3-tiny.weights ubuntu@$app_instance_ip:~/darknet/
	scp    -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no    ./AppTier/pom.xml ubuntu@$app_instance_ip:~/AppTier/
	scp -r -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no    ./AppTier/src ubuntu@$app_instance_ip:~/AppTier/
	scp -r -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no    ./AppTier_Terminator/pom.xml ubuntu@$app_instance_ip:~/AppTier_Terminator/
	scp -r -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no    ./AppTier_Terminator/src ubuntu@$app_instance_ip:~/AppTier_Terminator/
	scp    -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no    AppTier.sh ubuntu@$app_instance_ip:~/
	ssh    -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no -t ubuntu@$app_instance_ip bash AppTier.sh &
	
	# ssh    -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no ubuntu@$app_instance_ip <<-HERE
	# 	sudo add-apt-repository -y ppa:webupd8team/java
	# 	sudo apt-get update
	# 	echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
	# 	sudo apt-get install -y oracle-java8-installer
	# 	sudo apt-get install -y maven
	# 	sudo apt install -y xvfb
	# 	mvn clean package
	# 	mv ./target/AppTier-1.0.0.jar ./darknet
	# 	cd darknet
	# 	Xvfb :1 & export DISPLAY=:1
	# 	java -jar AppTier-1.0.0.jar > /dev/null &
	# 	exit
	# HERE
	
	# echo "########################################"
	# echo "###### CREATING APP-TIER IMAGE #########"
	# echo "########################################"
	
	sleep 120

	# put app tier terminating in this
	app_instance_id=`aws ec2 describe-instances --filters Name=tag:Name,Values=$vs_app_instance_name Name=vpc-id,Values=$vpc_id --query 'Reservations[0].Instances[0].InstanceId' --output text`
	app_instance_ami_id=`aws ec2 create-image --instance-id $app_instance_id --name $vs_app_instance_ami_name --no-reboot --query 'ImageId' --output text`
	aws ec2 create-tags --resources $app_instance_ami_id --tags "Key=\"Name\",Value=\"$vs_app_instance_ami_name\""
	echo "vs_app_instance_ami_id=$app_instance_ami_id" >> aws-resources.properties

	mv aws-resources.properties ./WebTier/src/main/resources

	# echo "###################################"
	# echo "###### DEPLOYING WEB-TIER #########"
	# echo "###################################"
	web_instance_ip=`aws ec2 describe-instances --filters Name=tag:Name,Values=$vs_web_instance_name Name=vpc-id,Values=$vpc_id --query 'Reservations[0].Instances[0].PublicIpAddress' --output text`
	scp    -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no    ./WebTier/pom.xml ubuntu@$web_instance_ip:~/
	scp -r -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no    ./WebTier/src ubuntu@$web_instance_ip:~/
	scp -r -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no    WebTier.sh ubuntu@$web_instance_ip:~/
	echo "starting web tier application..."
	ssh    -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no -t ubuntu@$web_instance_ip bash WebTier.sh &
	# ssh    -i ~/.ssh/$vs_key_pair_name.pem -o StrictHostKeyChecking=no ubuntu@$web_instance_ip <<-HERE
	# 	sudo add-apt-repository -y ppa:webupd8team/java
	# 	sudo apt-get update
	# 	echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
	# 	sudo apt-get install -y oracle-java8-installer
	# 	sudo apt-get install -y maven
	# 	mvn clean package
	# 	mv ./target/WebTier-1.0.0.jar .
	# 	java -jar WebTier-1.0.0.jar > /dev/null &
	# 	exit
	# HERE
	

elif [ "$1" == "destroy" ]; then
	echo 'BREAKING DOWN THE INFRASTRUCTURE'

	app_instance_ami_id=`aws ec2 describe-images --filters Name=tag:Name,Values=$vs_app_instance_ami_name --query 'Images[0].ImageId' --output text`
	ami_snapshot_id=`aws ec2 describe-images --filters Name=tag:Name,Values=$vs_app_instance_ami_name --query 'Images[0].BlockDeviceMappings[0].Ebs.SnapshotId' --output text`

	echo 'deleting app instance AMI image...'
	aws ec2 deregister-image --image-id $app_instance_ami_id

	echo 'deleting AMI snapshot...'
	aws ec2 delete-snapshot --snapshot-id $ami_snapshot_id

	vpc_id=`aws ec2 describe-vpcs --filters Name=tag:Name,Values=$vs_vpc_name  --query 'Vpcs[0].VpcId' --output text`

	echo 'deleting instances...'
	aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances --filters  Name=vpc-id,Values=$vpc_id --query "Reservations[].Instances[].[InstanceId]" --output text | tr '\n' ' ') > /dev/null

	# enough time for instances to be marked as shutdown
	sleep 60

	echo 'detaching role from instance profile...'
	aws iam remove-role-from-instance-profile --instance-profile-name $vs_instance_profile_name --role-name $vs_role_name
	
	echo 'detaching policies from role...'
	aws iam detach-role-policy --role-name $vs_role_name --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
	aws iam detach-role-policy --role-name $vs_role_name --policy-arn arn:aws:iam::aws:policy/AmazonSQSFullAccess
	aws iam detach-role-policy --role-name $vs_role_name --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
	aws iam detach-role-policy --role-name $vs_role_name --policy-arn arn:aws:iam::aws:policy/IAMFullAccess

	echo 'deleting role...'
	aws iam delete-role --role-name $vs_role_name

	echo 'deleting instance profile...'
	aws iam delete-instance-profile --instance-profile-name $vs_instance_profile_name

	echo 'deleting key pair...'
	aws ec2 delete-key-pair --key-name $vs_key_pair_name
	rm -f ~/.ssh/$vs_key_pair_name.pem

	echo 'deleting security group...'
	security_group_id=`aws ec2 describe-security-groups --filter Name=group-name,Values=$vs_security_group_name --query 'SecurityGroups[0].GroupId' --output text`
	aws ec2 delete-security-group --group-id $security_group_id
	
	echo 'deleting routes...'
	route_table_id=`aws ec2 describe-route-tables --filters Name=vpc-id,Values=$vpc_id --query 'RouteTables[0].RouteTableId' --output text`
	aws ec2 delete-route --route-table-id $route_table_id --destination-cidr-block 0.0.0.0/0

	echo 'deleting subnet...'
	subnet_id=`aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpc_id --query 'Subnets[0].SubnetId' --output text`
	aws ec2 delete-subnet --subnet-id $subnet_id 

	echo 'detaching internet gateway from VPC...'
	internet_gateway_id=`aws ec2 describe-internet-gateways --filters Name=attachment.vpc-id,Values=$vpc_id --query 'InternetGateways[0].InternetGatewayId' --output text`
	aws ec2 detach-internet-gateway --internet-gateway-id $internet_gateway_id --vpc-id $vpc_id

	echo 'deleting internet gateway...'
	aws ec2 delete-internet-gateway --internet-gateway-id $internet_gateway_id

	echo 'deleting VPC...'
	aws ec2 delete-vpc --vpc-id $vpc_id

	echo 'deleting SQS output queue...'
	output_queue_url=`aws sqs get-queue-url --queue-name $vs_output_queue_name --query 'QueueUrl' --output text`
	aws sqs delete-queue --queue-url $output_queue_url
	
	echo 'deleting SQS input queue...'
	input_queue_url=`aws sqs get-queue-url --queue-name $vs_input_queue_name --query 'QueueUrl' --output text`
	aws sqs delete-queue --queue-url $input_queue_url

	# TODO: delete objects in bucket to successfully delete bucket
	echo 'deleting S3 bucket...'
	aws_region=`aws configure get region`
	aws s3api delete-bucket --bucket $vs_s3_bucket_name --region $aws_region

	echo "finalizing destruction..."
	sleep 60 # TODO: needed?


else
	echo "use \"create\" argument to create infrastructure"
	echo "use \"deploy-project\" argument to  deploy the project"
	echo "use \"destroy\" argument to destroy infrastructure"
fi