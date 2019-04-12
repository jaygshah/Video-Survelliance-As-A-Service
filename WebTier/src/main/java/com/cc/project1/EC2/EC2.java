package com.cc.project1.EC2;

import java.util.ArrayList;
import java.util.Collection;
import java.util.Iterator;
import java.util.List;
import java.util.concurrent.TimeUnit;

import org.apache.commons.codec.binary.Base64;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.amazonaws.services.ec2.AmazonEC2;
import com.amazonaws.services.ec2.AmazonEC2ClientBuilder;
import com.amazonaws.services.ec2.model.CreateTagsRequest;
import com.amazonaws.services.ec2.model.DescribeInstanceStatusRequest;
import com.amazonaws.services.ec2.model.DescribeInstanceStatusResult;
import com.amazonaws.services.ec2.model.IamInstanceProfileSpecification;
import com.amazonaws.services.ec2.model.Instance;
import com.amazonaws.services.ec2.model.InstanceNetworkInterfaceSpecification;
import com.amazonaws.services.ec2.model.InstanceState;
import com.amazonaws.services.ec2.model.InstanceStateName;
import com.amazonaws.services.ec2.model.InstanceStatus;
import com.amazonaws.services.ec2.model.InstanceType;
import com.amazonaws.services.ec2.model.RunInstancesRequest;
import com.amazonaws.services.ec2.model.RunInstancesResult;
import com.amazonaws.services.ec2.model.Tag;

@Service
public class EC2 {

	@Value("${vs_subnet_id}")
	String subnetId;
	
	@Value("${vs_security_group_id}")
	String securityGroupId;
	
	@Value("${vs_key_pair_name}")
	String keyPairName;
	
	@Value("${vs_instance_profile_name}")
	String instanceProfileName;
	
	@Value("${vs_app_instance_ami_id}")
	String appInstanceImageId;
	
	public void cloneInstances(int num) throws InterruptedException {
		
		AmazonEC2 ec2 = AmazonEC2ClientBuilder.defaultClient();

		int minInstanceCount = Math.max(1, num - 1);
		int maxInstanceCount = num;
		
		InstanceNetworkInterfaceSpecification interfaceSpecification = new InstanceNetworkInterfaceSpecification()
			    .withSubnetId(this.subnetId)
			    .withAssociatePublicIpAddress(true)
			    .withGroups(this.securityGroupId)
			    .withDeviceIndex(0);
		
		RunInstancesRequest runInstancesRequest = new RunInstancesRequest()
				.withIamInstanceProfile(new IamInstanceProfileSpecification().withName(this.instanceProfileName))
				.withImageId(this.appInstanceImageId)
				.withMinCount(minInstanceCount)
				.withMaxCount(maxInstanceCount)
				.withInstanceType(InstanceType.T2Micro)
				.withKeyName(this.keyPairName)
				.withUserData(getUserDataScript())
				.withNetworkInterfaces(interfaceSpecification);
		
		RunInstancesResult runInstancesResult = ec2.runInstances(runInstancesRequest);
		
		List<Instance> resultInstances = runInstancesResult.getReservation().getInstances();

		Collection<String> resources = new ArrayList<>();
		Collection<Tag> tags = new ArrayList<>();
		
		int i = 1;
		for (Instance instance : resultInstances) {
			
			i++;
			String instanceId = instance.getInstanceId();
			System.out.println("[Autoscaling] New instances has been created:" +instanceId);
			
			resources.add(instanceId);
			tags.add(new Tag("Name", "app_instance_" + i));
		}
		
		CreateTagsRequest createTagsRequest = new CreateTagsRequest();
		createTagsRequest.setResources(resources);
		createTagsRequest.setTags(tags);
		ec2.createTags(createTagsRequest);
		
		TimeUnit.SECONDS.sleep(20);
	}

	private static String getUserDataScript() {
		
		ArrayList<String> lines = new ArrayList<String>();
		lines.add("#! /bin/bash");
		lines.add("cd /home/ubuntu/darknet; java -jar AppTier_Terminator-1.0.0.jar > file1 2>&1 &");
		
		String userData = new String(Base64.encodeBase64(join(lines, "\n").getBytes()));
		return userData;
		
	}

	private static String join(Collection<String> s, String delimiter) {
		
		StringBuilder builder = new StringBuilder();
		Iterator<String> iter = s.iterator();
		
		while (iter.hasNext()) {
			builder.append(iter.next());
			if (!iter.hasNext()) {
				break;
			}
			builder.append(delimiter);
		}
		
		return builder.toString();
	
	}

	public int getNumInstances() {
		
		AmazonEC2 ec2 = AmazonEC2ClientBuilder.defaultClient();

		DescribeInstanceStatusRequest describeRequest = new DescribeInstanceStatusRequest();
		describeRequest.setIncludeAllInstances(true);
		
		DescribeInstanceStatusResult describeInstances = ec2.describeInstanceStatus(describeRequest);
		List<InstanceStatus> instanceStatusList = describeInstances.getInstanceStatuses();
		
		Integer countOfRunningInstances = 0;

		for (InstanceStatus instanceStatus : instanceStatusList) {
			InstanceState instanceState = instanceStatus.getInstanceState();

			if (instanceState.getName().equals(InstanceStateName.Running.toString())) {
				countOfRunningInstances++;
			}
			
		}

		return countOfRunningInstances;
		
	}

}
