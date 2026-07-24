package com.ones.api.adapters.outbound.dynamodb;

import com.ones.api.application.subscriptions.ports.SubscriptionPaymentsRepository;
import com.ones.api.domain.subscriptions.SubscriptionPayment;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

import java.util.Optional;

@Repository
public class DynamoDbSubscriptionPaymentsRepository implements SubscriptionPaymentsRepository {

    private final DynamoDbTable<DynamoSubscriptionPaymentItem> table;

    public DynamoDbSubscriptionPaymentsRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.subscription-payments-table-name:ones-subscription-payments}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoSubscriptionPaymentItem.class));
    }

    @Override
    public Optional<SubscriptionPayment> findByPaymentId(String paymentId) {
        if (paymentId == null || paymentId.isBlank()) return Optional.empty();
        DynamoSubscriptionPaymentItem item = table.getItem(Key.builder().partitionValue(paymentId.trim()).build());
        return Optional.ofNullable(item).map(DynamoDbSubscriptionPaymentsRepository::toDomain);
    }

    @Override
    public SubscriptionPayment upsert(SubscriptionPayment payment) {
        table.putItem(toItem(payment));
        return payment;
    }

    private static DynamoSubscriptionPaymentItem toItem(SubscriptionPayment p) {
        DynamoSubscriptionPaymentItem i = new DynamoSubscriptionPaymentItem();
        i.setPaymentId(p.getPaymentId());
        i.setCreatedAt(p.getCreatedAt().toString());
        i.setMpDateCreated(p.getMpDateCreated());
        i.setStatus(p.getStatus());
        i.setStatusDetail(p.getStatusDetail());
        i.setTransactionAmountCents(p.getTransactionAmountCents());
        i.setCurrency(p.getCurrency());
        i.setPayerEmail(p.getPayerEmail());
        i.setPayerId(p.getPayerId());
        i.setPreapprovalId(p.getPreapprovalId());
        i.setPreapprovalPlanId(p.getPreapprovalPlanId());
        i.setUserId(p.getUserId());
        i.setPlanId(p.getPlanId());
        i.setCheckoutAttemptId(p.getCheckoutAttemptId());
        return i;
    }

    private static SubscriptionPayment toDomain(DynamoSubscriptionPaymentItem i) {
        return new SubscriptionPayment(
                i.getPaymentId(),
                java.time.Instant.parse(i.getCreatedAt()),
                i.getMpDateCreated(),
                i.getStatus(),
                i.getStatusDetail(),
                i.getTransactionAmountCents(),
                i.getCurrency(),
                i.getPayerEmail(),
                i.getPayerId(),
                i.getPreapprovalId(),
                i.getPreapprovalPlanId(),
                i.getUserId(),
                i.getPlanId(),
                i.getCheckoutAttemptId()
        );
    }
}
