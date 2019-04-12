package com.cc.project1.SQS;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.amazonaws.services.sqs.AmazonSQS;
import com.amazonaws.services.sqs.AmazonSQSClientBuilder;
import com.amazonaws.services.sqs.model.GetQueueAttributesResult;
import com.amazonaws.services.sqs.model.Message;

@Service
public class SQS {

	@Value("${vs_input_queue_url}")
	String inputQueueUrl;

	@Value("${vs_output_queue_url}")
	String outputQueueUrl;

	public void sendMessage(String requestString) {

		AmazonSQS sqs = AmazonSQSClientBuilder.standard().build();

		String inputQueueUrl = this.inputQueueUrl;
		
		System.out.println("[WebTier] Sending request...");
		sqs.sendMessage(inputQueueUrl, requestString);
		System.out.println("[WebTier] Request sent!");
	}

	public String receiveMessage() throws InterruptedException {

		AmazonSQS sqs = AmazonSQSClientBuilder.standard().build();

		String outputQueueUrl = this.outputQueueUrl;

		while (true) {
			System.out.println("[WebTier] Waiting for response...");
			List<Message> messages = sqs.receiveMessage(outputQueueUrl).getMessages();
			if (messages.size() > 0) {
				System.out.println("[WebTier] Response received!");
				this.deleteMessage(messages.get(0));
				return messages.get(0).getBody();
			}
			TimeUnit.SECONDS.sleep(3);
		}
	}

	public void deleteMessage(Message responseMessage) {

		AmazonSQS sqs = AmazonSQSClientBuilder.standard().build();

		String outputQueueUrl = this.outputQueueUrl;

		String responseMessageReceiptHandle = responseMessage.getReceiptHandle();
		sqs.deleteMessage(outputQueueUrl, responseMessageReceiptHandle);

	}
	
	public int getNumberOfMessages() {

		AmazonSQS sqs = AmazonSQSClientBuilder.standard().build();

		String inputQueueUrl = this.inputQueueUrl;

		List<String> attributeNames = new ArrayList<String>();
		attributeNames.add("ApproximateNumberOfMessages");

		GetQueueAttributesResult getQueueAttributesResult = sqs.getQueueAttributes(inputQueueUrl, attributeNames);

		String numberOfMessagesString = getQueueAttributesResult.getAttributes().get("ApproximateNumberOfMessages");

		Integer numberOfMessages = Integer.valueOf(numberOfMessagesString);
		return numberOfMessages;

	}

}
