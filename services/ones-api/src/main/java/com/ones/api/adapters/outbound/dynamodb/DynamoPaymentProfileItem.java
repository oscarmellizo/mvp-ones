package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondaryPartitionKey;

@DynamoDbBean
public class DynamoPaymentProfileItem {

    private String userId;
    private String mercadoPagoEmail;
    private String mercadoPagoEmailLower;
    private String country;
    private String documentType;
    private String documentNumber;
    private String phoneNumber;
    private String fullName;
    private String createdAt;
    private String updatedAt;
    private String verifiedAt;

    @DynamoDbPartitionKey
    @DynamoDbAttribute("userId")
    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    @DynamoDbAttribute("mercadoPagoEmail")
    public String getMercadoPagoEmail() { return mercadoPagoEmail; }
    public void setMercadoPagoEmail(String mercadoPagoEmail) { this.mercadoPagoEmail = mercadoPagoEmail; }

    @DynamoDbSecondaryPartitionKey(indexNames = "byMercadoPagoEmailLower")
    @DynamoDbAttribute("mercadoPagoEmailLower")
    public String getMercadoPagoEmailLower() { return mercadoPagoEmailLower; }
    public void setMercadoPagoEmailLower(String mercadoPagoEmailLower) { this.mercadoPagoEmailLower = mercadoPagoEmailLower; }

    @DynamoDbAttribute("country")
    public String getCountry() { return country; }
    public void setCountry(String country) { this.country = country; }

    @DynamoDbAttribute("documentType")
    public String getDocumentType() { return documentType; }
    public void setDocumentType(String documentType) { this.documentType = documentType; }

    @DynamoDbAttribute("documentNumber")
    public String getDocumentNumber() { return documentNumber; }
    public void setDocumentNumber(String documentNumber) { this.documentNumber = documentNumber; }

    @DynamoDbAttribute("phoneNumber")
    public String getPhoneNumber() { return phoneNumber; }
    public void setPhoneNumber(String phoneNumber) { this.phoneNumber = phoneNumber; }

    @DynamoDbAttribute("fullName")
    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }

    @DynamoDbAttribute("createdAt")
    public String getCreatedAt() { return createdAt; }
    public void setCreatedAt(String createdAt) { this.createdAt = createdAt; }

    @DynamoDbAttribute("updatedAt")
    public String getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(String updatedAt) { this.updatedAt = updatedAt; }

    @DynamoDbAttribute("verifiedAt")
    public String getVerifiedAt() { return verifiedAt; }
    public void setVerifiedAt(String verifiedAt) { this.verifiedAt = verifiedAt; }
}
