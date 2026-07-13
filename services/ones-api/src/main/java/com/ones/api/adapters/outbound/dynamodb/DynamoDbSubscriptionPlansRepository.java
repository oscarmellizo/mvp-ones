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

    private static Map<String, DynamoPlanFeatureItem> toFeatureItems(Map<String, PlanFeature> features) {
        if (features == null || features.isEmpty()) {
            return Collections.emptyMap();
        }
        Map<String, DynamoPlanFeatureItem> items = new HashMap<>();
        features.forEach((key, feature) -> {
            DynamoPlanFeatureItem item = new DynamoPlanFeatureItem();
            item.setValue(feature.value());
            item.setType(feature.type());
            item.setLabel(feature.label());
            items.put(key, item);
        });
        return items;
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

    private static Map<String, PlanFeature> toFeatures(Map<String, DynamoPlanFeatureItem> items) {
        if (items == null || items.isEmpty()) {
            return Collections.emptyMap();
        }
        Map<String, PlanFeature> features = new HashMap<>();
        items.forEach((key, item) -> features.put(key,
                new PlanFeature(item.getValue(), item.getType(), item.getLabel())));
        return features;
    }
}
