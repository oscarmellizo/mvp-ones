package com.ones.api.adapters.outbound.dynamodb;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;

import org.junit.jupiter.api.Test;

import software.amazon.awssdk.core.pagination.sync.SdkIterable;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.model.Page;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;

class DynamoDbPhotoLikesRepositoryTest {

    @Test
    @SuppressWarnings("unchecked")
    void deleteAllByUserId_failingDelete_attemptsAllThenThrows() {
        DynamoDbEnhancedClient client = mock(DynamoDbEnhancedClient.class);
        DynamoDbTable<DynamoPhotoLikeItem> table = mock(DynamoDbTable.class);
        DynamoDbIndex<DynamoPhotoLikeItem> index = mock(DynamoDbIndex.class);
        when(client.table(any(String.class), any(software.amazon.awssdk.enhanced.dynamodb.TableSchema.class)))
                .thenReturn(table);
        when(table.index("gsi1")).thenReturn(index);
        Page<DynamoPhotoLikeItem> page = Page.create(List.of(like("p1"), like("p2"), like("p3")));
        when(index.query(any(QueryEnhancedRequest.class))).thenReturn((SdkIterable<Page<DynamoPhotoLikeItem>>) () -> List.of(page).iterator());
        doThrow(new RuntimeException("boom")).when(table)
                .deleteItem(Key.builder().partitionValue("p1").sortValue("u1").build());

        DynamoDbPhotoLikesRepository repo = new DynamoDbPhotoLikesRepository(client, "likes");

        assertThrows(IllegalStateException.class, () -> repo.deleteAllByUserId("u1"));
        verify(table, times(3)).deleteItem(any(Key.class));
    }

    private static DynamoPhotoLikeItem like(String photoId) {
        DynamoPhotoLikeItem item = new DynamoPhotoLikeItem();
        item.setPhotoId(photoId);
        item.setUserId("u1");
        return item;
    }
}
