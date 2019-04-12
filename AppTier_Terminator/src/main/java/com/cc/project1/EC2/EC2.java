package com.cc.project1.EC2;

import org.springframework.stereotype.Service;

import com.amazonaws.services.ec2.AmazonEC2;
import com.amazonaws.services.ec2.AmazonEC2ClientBuilder;
import com.amazonaws.services.ec2.model.TerminateInstancesRequest;
import com.amazonaws.util.EC2MetadataUtils;

@Service
public class EC2 {
	
	public void endInstance() {
		AmazonEC2 amazonEC2 = AmazonEC2ClientBuilder.standard().build();
		
		String myId = EC2MetadataUtils.getInstanceId();
		TerminateInstancesRequest request = new TerminateInstancesRequest().withInstanceIds(myId);
		amazonEC2.terminateInstances(request);
	}
	
}
