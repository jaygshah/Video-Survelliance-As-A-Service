package com.cc.project1.WebTier;

import org.springframework.web.bind.annotation.RestController;

import com.cc.project1.SQS.SQS;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.RequestMapping;

@RestController
public class WebTierController {
	
	@Autowired
	SQS sqs;
	
	@RequestMapping("/reqobj")
	public String request_object_detection() throws InterruptedException {
		
		sqs.sendMessage("Video surveillance request");

		String messageBody = sqs.receiveMessage();
		String out[] = messageBody.split("__");
		
		System.out.println("[WebTier] Response is: " + "(" + out[1] + "," + out[0] + ")");
		return "(" + out[1] + "," + out[0] + ")";

	}

}
