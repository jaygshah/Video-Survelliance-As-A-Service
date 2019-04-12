package com.cc.project1.SQS;

import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.amazonaws.services.sqs.AmazonSQS;
import com.amazonaws.services.sqs.AmazonSQSClientBuilder;
import com.amazonaws.services.sqs.model.Message;

@Service
public class SQS {

	@Value("${vs_input_queue_url}")
	String inputQueueUrl;

	@Value("${vs_output_queue_url}")
	String outputQueueUrl;

	public void sendMessage(String message) {

		AmazonSQS sqs = AmazonSQSClientBuilder.standard().build();

		String outputQueueUrl = this.outputQueueUrl;

		sqs.sendMessage(outputQueueUrl, message);
		
	}

	public String receiveMessage() throws InterruptedException {

		AmazonSQS sqs = AmazonSQSClientBuilder.standard().build();

		String inputQueueUrl = this.inputQueueUrl;

		List<Message> messages = sqs.receiveMessage(inputQueueUrl).getMessages();
		if (messages.size() > 0) {
			this.deleteMessage(messages.get(0));
			return messages.get(0).getBody();
		} else {
			return "";
		}

	}

	public void deleteMessage(Message message) {

		AmazonSQS sqs = AmazonSQSClientBuilder.standard().build();

		String inputQueueUrl = this.inputQueueUrl;

		String messageReceiptHandle = message.getReceiptHandle();
		sqs.deleteMessage(inputQueueUrl, messageReceiptHandle);

	}

}
