package com.cc.project1.WebTier;

import java.io.IOException;
import java.util.concurrent.TimeUnit;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;

import com.amazonaws.services.ec2.model.AmazonEC2Exception;
import com.cc.project1.EC2.EC2;
import com.cc.project1.SQS.SQS;

@Configuration
@ComponentScan("com.cc.project1.*")
@EnableAutoConfiguration
@PropertySource("aws-resources.properties")
public class WebTierInitializer {

	public static void main(String args[]) throws IOException, InterruptedException {

		ApplicationContext context = SpringApplication.run(WebTierInitializer.class, args);

		System.out.println("##############################################");
		System.out.println("########### WEB TIER IS RUNNING ##############");
		System.out.println("##############################################");

		scaleOut(context);

	}

	public static void scaleOut(ApplicationContext context) throws InterruptedException {

		SQS sqs = context.getBean(SQS.class);
		EC2 ec2 = context.getBean(EC2.class);
		
		while (true) {
			
			int numberOfMsgs = sqs.getNumberOfMessages();
			System.out.println("[Autoscaling] Number of messages in the input queue: " + numberOfMsgs);
			
			int num_of_live_ec2s = ec2.getNumInstances();
			System.out.println("[Autoscaling] Number of running instances: " + num_of_live_ec2s);
			
			int num_of_App = num_of_live_ec2s - 1;
			System.out.println("[Autoscaling] Number of app instances: " + num_of_App);
			
			if (numberOfMsgs > 0 && numberOfMsgs > num_of_App) {
				
				int possible_Appinstances_to_bcreated = 19 - num_of_App;
				System.out.println("[Autoscaling] Possible app instances to be created: " + possible_Appinstances_to_bcreated);
				
				if (possible_Appinstances_to_bcreated > 0) {
					
					int req_Appinstances = numberOfMsgs - num_of_App;
					System.out.println("[Autoscaling] Required app instances: " + req_Appinstances);
					
					if (req_Appinstances >= possible_Appinstances_to_bcreated) {
						
						System.out.println("[Autoscaling] Creating " + possible_Appinstances_to_bcreated + " instances");
						try {
							ec2.cloneInstances(possible_Appinstances_to_bcreated);
						} catch (AmazonEC2Exception e){
							
						}
					} else if (req_Appinstances < possible_Appinstances_to_bcreated) {
						
						System.out.println("[Autoscaling] Creating " + req_Appinstances + " instances");
						try {
							ec2.cloneInstances(req_Appinstances);
						} catch (AmazonEC2Exception e) {
							
						}
					}
				}
			}
			
			TimeUnit.SECONDS.sleep(3);
			
		}
	}
}
