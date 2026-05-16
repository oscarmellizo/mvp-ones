package com.ones.api.configuration;

import java.net.URI;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.util.StringUtils;

import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.DynamoDbClientBuilder;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.sesv2.SesV2Client;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;

@Configuration
public class AwsConfig {

    @Bean
    Region awsRegion(@Value("${AWS_REGION:us-east-1}") String region) {
        return Region.of(region);
    }

    @Bean
    DynamoDbClient dynamoDbClient(
            Region awsRegion,
            @Value("${ones.dynamodb.endpoint:}") String endpoint
    ) {
        DynamoDbClientBuilder builder = DynamoDbClient.builder()
                .region(awsRegion);

        if (StringUtils.hasText(endpoint)) {
            builder = builder.endpointOverride(URI.create(endpoint));
        }

        return builder.build();
    }

    @Bean
    DynamoDbEnhancedClient dynamoDbEnhancedClient(DynamoDbClient dynamoDbClient) {
        return DynamoDbEnhancedClient.builder()
                .dynamoDbClient(dynamoDbClient)
                .build();
    }

    @Bean
    S3Client s3Client(Region awsRegion) {
        return S3Client.builder()
                .region(awsRegion)
                .build();
    }

    @Bean
    S3Presigner s3Presigner(Region awsRegion) {
        return S3Presigner.builder()
                .region(awsRegion)
                .build();
    }

    @Bean
    SecretsManagerClient secretsManagerClient(Region awsRegion) {
        return SecretsManagerClient.builder()
                .region(awsRegion)
                .build();
    }

    @Bean
    SesV2Client sesV2Client(Region awsRegion) {
        return SesV2Client.builder()
                .region(awsRegion)
                .build();
    }
}
