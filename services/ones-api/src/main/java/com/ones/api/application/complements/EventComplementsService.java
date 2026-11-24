package com.ones.api.application.complements;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.ones.api.adapters.outbound.dynamodb.DynamoDbEventComplementsRepository;
import com.ones.api.adapters.outbound.dynamodb.DynamoEventComplementItem;

@Service
public class EventComplementsService {

    private final DynamoDbEventComplementsRepository repository;
    private final Map<String, EventComplementModule> modules;
    private final Clock clock;

    public EventComplementsService(
            DynamoDbEventComplementsRepository repository,
            List<EventComplementModule> modules,
            Clock clock
    ) {
        this.repository = repository;
        this.modules = modules.stream().collect(Collectors.toUnmodifiableMap(
                EventComplementModule::id,
                Function.identity()));
        this.clock = clock;
    }

    public List<EventComplementView> list(String eventId) {
        Map<String, DynamoEventComplementItem> enabled = repository.listByEventId(eventId).stream()
                // Older rows may lack this attribute; their existence means the complement was enabled.
                .filter(item -> !Boolean.FALSE.equals(item.getEnabled()))
                .collect(Collectors.toMap(DynamoEventComplementItem::getComplementId, Function.identity()));

        return modules.values().stream()
                .map(module -> {
                    DynamoEventComplementItem state = enabled.get(module.id());
                    String label = state == null || state.getTabLabel() == null || state.getTabLabel().isBlank()
                            ? module.defaultTabLabel()
                            : state.getTabLabel();
                    return new EventComplementView(module.id(), module.displayName(), label, state != null);
                })
                .sorted((a, b) -> a.id().compareTo(b.id()))
                .toList();
    }

    public EventComplementView setEnabled(String eventId, String ownerId, String complementId, boolean enabled) {
        EventComplementModule module = modules.get(complementId);
        if (module == null) {
            throw new IllegalArgumentException("Unknown complement: " + complementId);
        }

        if (enabled) {
            module.initialize(eventId, ownerId);
        }

        DynamoEventComplementItem item = repository.find(eventId, complementId)
                .orElseGet(DynamoEventComplementItem::new);
        item.setEventId(eventId);
        item.setComplementId(complementId);
        item.setEnabled(enabled);
        if (item.getTabLabel() == null || item.getTabLabel().isBlank()) {
            item.setTabLabel(module.defaultTabLabel());
        }
        item.setUpdatedAt(Instant.now(clock).toString());
        repository.save(item);

        return new EventComplementView(
                module.id(),
                module.displayName(),
                item.getTabLabel(),
                enabled);
    }
}
