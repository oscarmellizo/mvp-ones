package com.ones.api.application.invitations.ports;

import java.util.List;
import java.util.Optional;

import com.ones.api.domain.invitations.Invitation;

public interface InvitationsRepository {

    Optional<Invitation> findByInviteeEmailAndEventId(String inviteeEmail, String eventId);

    Invitation upsert(Invitation invitation);

    List<Invitation> listByInviteeEmail(String inviteeEmail, int limit);

    List<Invitation> listByEventId(String eventId, int limit);

    List<Invitation> listAcceptedByInviteeEmail(String inviteeEmail, int limit);
}
