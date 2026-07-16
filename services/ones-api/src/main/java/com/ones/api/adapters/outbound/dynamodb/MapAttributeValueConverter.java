package com.ones.api.adapters.outbound.dynamodb;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

import software.amazon.awssdk.enhanced.dynamodb.AttributeConverter;
import software.amazon.awssdk.enhanced.dynamodb.AttributeValueType;
import software.amazon.awssdk.enhanced.dynamodb.EnhancedType;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;

public class MapAttributeValueConverter implements AttributeConverter<Map<String, AttributeValue>> {

    @Override
    public AttributeValue transformFrom(Map<String, AttributeValue> input) {
        if (input == null) {
            return AttributeValue.builder().m(Collections.emptyMap()).build();
        }
        return AttributeValue.builder().m(new HashMap<>(input)).build();
    }

    @Override
    public Map<String, AttributeValue> transformTo(AttributeValue input) {
        if (input == null || !input.hasM() || input.m() == null) {
            return Collections.emptyMap();
        }
        return new HashMap<>(input.m());
    }

    @Override
    @SuppressWarnings("unchecked")
    public EnhancedType<Map<String, AttributeValue>> type() {
        return (EnhancedType<Map<String, AttributeValue>>) (EnhancedType<?>) EnhancedType.mapOf(String.class, AttributeValue.class);
    }

    @Override
    public AttributeValueType attributeValueType() {
        return AttributeValueType.M;
    }
}
