package com.cc.project1.AppTierInitializer;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URL;
import java.net.URLConnection;
import org.apache.commons.io.FileUtils;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.cc.project1.S3.S3;
import com.cc.project1.SQS.SQS;

@Service
public class Listener {

	@Autowired
	SQS sqs;

	@Autowired
	S3 s3;

	public void listen_and_giveOutput() throws IOException, InterruptedException {

		while(true) {
			String messageBody = sqs.receiveMessage();
			
			if(messageBody.length() > 0) {
				System.out.println("[APPTIER] OBTAINED MESSAGE IS: " + messageBody);
				dark_classification();
			}
			
		}
	}

	public void dark_classification() throws IOException, InterruptedException {

		String fileName = downloadFile();
		System.out.println("[APPTIER] CREATED FILE NAME IS: " + fileName);

		String output = runPythonScripts(fileName);
		System.out.println("[APPTIER] OUTPUT OBTAINED IS: " + output);

		s3.uploadToS3Bucket(fileName);
		System.out.println("[APPTIER] UPLOADED TO S3 BUCKET!");

		sqs.sendMessage(output + "__" + fileName);
		System.out.println("[APPTIER] MESSAGE SENT TO OUTPUT QUEUE!");

	}

	private String downloadFile() throws IOException {

		String url = "http://206.207.50.7/getvideo";
		
		URL obj = new URL(url);
		URLConnection conn = obj.openConnection();
		String str=(conn.getHeaderField("Content-Disposition"));
		String temp[]=str.split("=");
		
		String fileName = temp[1];

		System.out.println("[APPTIER] FILE NAME CREATED IS: " + fileName);

		FileUtils.copyURLToFile(obj, new File(fileName), 10000, 10000);

		return fileName;

	}

	private String runPythonScripts(String fileName) throws IOException, InterruptedException {

		Process p = new ProcessBuilder("/bin/bash", "-c",
				"Xvfb :1 & export DISPLAY=:1; ./darknet detector demo cfg/coco.data cfg/yolov3-tiny.cfg yolov3-tiny.weights "
						+ fileName + " -dont_show > result; python darknet_test.py; cat result_label").start();
		p.waitFor();

		BufferedReader br = new BufferedReader(new InputStreamReader(p.getInputStream()));
		String output = br.readLine();
		p.destroy();

		return output;

	}

}