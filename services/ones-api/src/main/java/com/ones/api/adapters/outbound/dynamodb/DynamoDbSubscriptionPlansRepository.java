package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.subscriptions.ports.SubscriptionPlansRepository;
import com.ones.api.domain.subscriptions.PlanFeature;
import com.ones.api.domain.subscriptions.SubscriptionPlan;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Expression;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.ScanEnhancedRequest;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;

@Repository
public class DynamoDbSubscriptionPlansRepository implements SubscriptionPlansRepository {

    private final DynamoDbTable<DynamoSubscriptionPlanItem> table;

    public DynamoDbSubscriptionPlansRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.plans-table-name:ones-plans}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoSubscriptionPlanItem.class));
    }

    @Override
    public Optional<SubscriptionPlan> findById(String planId) {
        if (planId == null || planId.isBlank()) {
            return Optional.empty();
        }
        DynamoSubscriptionPlanItem item = table.getItem(
                Key.builder().partitionValue(planId.trim()).build()
        );
        return Optional.ofNullable(item).map(DynamoDbSubscriptionPlansRepository::toDomain);
    }

    @Override
    public List<SubscriptionPlan> findAllActive() {
        Expression filter = Expression.builder()
                .expression("active = :active")
                .expressionValues(Map.of(":active", AttributeValue.builder().bool(true).build()))
                .build();

        ScanEnhancedRequest request = ScanEnhancedRequest.builder()
                .filterExpression(filter)
                .build();

        List<SubscriptionPlan> plans = new ArrayList<>();
        table.scan(request).items().forEach(item -> plans.add(toDomain(item)));
        plans.sort((a, b) -> Integer.compare(a.getSortOrder(), b.getSortOrder()));
        return plans;
    }

    @Override
    public SubscriptionPlan upsert(SubscriptionPlan plan) {
        table.putItem(toItem(plan));
        return plan;
    }

    @Override
    public void deleteById(String planId) {
        if (planId == null || planId.isBlank()) {
            return;
        }
        table.deleteItem(Key.builder().partitionValue(planId.trim()).build());
    }

    private static DynamoSubscriptionPlanItem toItem(SubscriptionPlan plan) {
        DynamoSubscriptionPlanItem item = new DynamoSubscriptionPlanItem();
        item.setPlanId(plan.getPlanId());
        item.setName(plan.getName());
        item.setShortDescription(plan.getShortDescription());
        item.setTier(plan.getTier());
        item.setPriceCents(plan.getPriceCents());
        item.setCurrency(plan.getCurrency());
        item.setBillingInterval(plan.getBillingInterval());
        item.setMercadoPagoPlanId(plan.getMercadoPagoPlanId());
        item.setFeatures(toFeatureItems(plan.getFeatures()));
        item.setActive(plan.isActive());
        item.setSortOrder(plan.getSortOrder());
        item.setCreatedAt(plan.getCreatedAt().toString());
        item.setUpdatedAt(plan.getUpdatedAt().toString());
        return item;
    }

    private static Map<String, AttributeValue> toFeatureItems(Map<String, PlanFeature> features) {
        if (features == null || features.isEmpty()) {
            return Collections.emptyMap();
        }
        Map<String, AttributeValue> items = new HashMap<>();
        features.forEach((key, feature) -> {
            Map<String, AttributeValue> attributeMap = new HashMap<>();
            attributeMap.put("type", AttributeValue.builder().s(feature.type()).build());
            attributeMap.put("label", AttributeValue.builder().s(feature.label()).build());
            attributeMap.put("value", toFeatureValue(feature.value()));
            items.put(key, AttributeValue.builder().m(attributeMap).build());
        });
        return items;
    }

    private static AttributeValue toFeatureValue(Object value) {
        if (value == null) {
            return AttributeValue.builder().nul(true).build();
        }
        if (value instanceof Number number) {
            return AttributeValue.builder().n(number.toString()).build();
        }
        if (value instanceof Boolean bool) {
            return AttributeValue.builder().bool(bool).build();
        }
        return AttributeValue.builder().s(value.toString()).build();
    }

    private static SubscriptionPlan toDomain(DynamoSubscriptionPlanItem item) {
        return new SubscriptionPlan(
                item.getPlanId(),
                item.getName(),
                item.getShortDescription(),
                item.getTier(),
                item.getPriceCents(),
                item.getCurrency(),
                item.getBillingInterval(),
                item.getMercadoPagoPlanId(),
                toFeatures(item.getFeatures()),
                item.isActive(),
                item.getSortOrder(),
                Instant.parse(item.getCreatedAt()),
                Instant.parse(item.getUpdatedAt())
        );
    }

    private static Map<String, PlanFeature> toFeatures(Map<String, AttributeValue> items) {
        if (items == null || items.isEmpty()) {
            return Collections.emptyMap();
        }
        Map<String, PlanFeature> features = new HashMap<>();
        items.forEach((key, item) -> {
            Map<String, AttributeValue> m = item.m();
            if (m == null) {
                return;
            }
            String type = s(m.get("type"));
            String label = s(m.get("label"));
            Object value = fromFeatureValue(m.get("value"));
            features.put(key, new PlanFeature(value, type, label));
        });
        return features;
    }

    private static Object fromFeatureValue(AttributeValue value) {
        if (value == null) {
            return null;
        }
        if (value.n() != null) {
            return Long.parseLong(value.n());
        }
        if (value.bool() != null) {
            return value.bool();
        }
        if (value.s() != null) {
            return value.s();
        }
        return null;
    }

    private static String s(AttributeValue value) {
        return value != null && value.s() != null ? value.s() : "";
    }
}
