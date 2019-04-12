package com.cc.project1.AppTierInitializer;

import java.io.IOException;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;

import com.cc.project1.AppTierInitializer.AppTierInitializer;

@Configuration
@ComponentScan("com.cc.project1.*")
@EnableAutoConfiguration
@PropertySource("classpath:aws-resources.properties")
public class AppTierInitializer {

	public static void main(String args[]) throws IOException, InterruptedException {
		ApplicationContext context = SpringApplication.run(AppTierInitializer.class, args);

		System.out.println("###########################################################");
		System.out.println("########### APP TIER - TERMINATOR IS RUNNING ##############");
		System.out.println("###########################################################");

		Listener listener = context.getBean(Listener.class);

		listener.listen_and_giveOutput();

	}
}