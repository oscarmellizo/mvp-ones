package com.ones.api.application.collections;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

import org.junit.jupiter.api.Test;

import com.ones.api.application.collections.ports.CollectionMembersRepository;
import com.ones.api.application.collections.ports.CollectionsRepository;
import com.ones.api.application.invitations.email.InvitationActionTokenService;
import com.ones.api.application.invitations.email.InvitationEmailService;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.collections.Collection;
import com.ones.api.domain.collections.CollectionInvitation;
import com.ones.api.domain.collections.CollectionMember;
import com.ones.api.domain.collections.CollectionType;

class CollectionServiceIncomingInvitationsTest {
    private static final Instant NOW = Instant.parse("2026-11-27T12:00:00Z");

    @Test
    void listsPendingInvitationsByNormalizedEmailAndBatchesCollectionDetails() {
        CollectionsRepository collections = mock(CollectionsRepository.class);
        CollectionMembersRepository members = mock(CollectionMembersRepository.class);
        Collection collection = new Collection(
                "collection-1", "owner-1", "Family", null, CollectionType.FAMILY,
                null, null, NOW, NOW, false, null, false, null);
        CollectionMember pending = new CollectionMember(
                "collection-1", "EMAIL#guest@example.com", null,
                "guest@example.com", CollectionMember.Status.PENDING,
                "owner-1", NOW, NOW);
        when(members.pagePendingByInviteeEmail("guest@example.com", 50, null))
                .thenReturn(new CollectionMembersRepository.PageResult<>(
                        List.of(pending), "next"));
        when(collections.findByIds(List.of("collection-1")))
                .thenReturn(List.of(collection));
        CollectionService service = new CollectionService(
                collections,
                members,
                mock(UsersRepository.class),
                mock(CollectionJoinTokenService.class),
                mock(InvitationEmailService.class),
                Clock.fixed(NOW, ZoneOffset.UTC));

        var page = service.listIncomingInvitations(
                " Guest@Example.com ", 50, null);

        assertEquals(List.of(new CollectionInvitation(
                "collection-1", "Family", "owner-1", NOW)), page.items());
        assertEquals("next", page.nextToken());
        verify(members).pagePendingByInviteeEmail("guest@example.com", 50, null);
        verify(collections).findByIds(List.of("collection-1"));
    }
}
