package com.cc.project1.S3;

import java.io.File;

import org.apache.commons.io.FileUtils;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;

@Service
public class S3 {

	@Value("${vs_s3_bucket_name}")
	String s3BucketName;

	public void uploadToS3Bucket(String fileName) {
		
		AmazonS3 s3 = AmazonS3ClientBuilder.standard().build();
		
		File file = new File("result_label");

		s3.putObject(this.s3BucketName, fileName, file);

		FileUtils.deleteQuietly(file);

	}
}
