package com.mobili.backend.module.partnergarecom.service;

import java.util.HashSet;
import java.util.Set;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.partnergarecom.entity.PartnerGareComMessage;
import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThread;
import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThreadScope;
import com.mobili.backend.module.partnergarecom.entity.PartnerGareComThreadTarget;
import com.mobili.backend.module.station.entity.Station;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.notification.service.InboxNotificationService;

import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
class PartnerGareComNotificationHelper {

    private final UserRepository userRepository;
    private final com.mobili.backend.module.station.repository.StationRepository stationRepository;
    private final InboxNotificationService inboxNotificationService;

    @Transactional
    public void notifyOnNewMessage(PartnerGareComThread thread, PartnerGareComMessage message, Object author) {
        Long partnerId = thread.getPartner().getId();
        Long authorUserId = (author instanceof UserPrincipal up) ? up.getUser().getId() : null;

        // Dirigeant : notifié comme avant (compte User classique).
        Set<Long> ownerRecipientIds = new HashSet<>();
        var p = thread.getPartner();
        if (p.getOwner() != null) {
            Long oid = p.getOwner().getId();
            if (authorUserId == null || !oid.equals(authorUserId)) {
                ownerRecipientIds.add(oid);
            }
        }

        // Gares : notifiées directement en tant que Station (plus via un compte chef de
        // gare).
        java.util.List<Station> targetStations;
        if (thread.getScope() == PartnerGareComThreadScope.ALL) {
            targetStations = stationRepository.findByPartnerIdOrderByCityAscNameAsc(partnerId);
        } else {
            targetStations = thread.getTargets().stream()
                    .map(PartnerGareComThreadTarget::getStation)
                    .toList();
        }

        String preview = message.getBody().length() > 200
                ? message.getBody().substring(0, 197) + "…"
                : message.getBody();
        User authorU = message.getAuthor();
        String who = (authorU.getFirstname() + " " + authorU.getLastname()).trim();
        if (who.isBlank()) {
            who = authorU.getLogin() != null ? authorU.getLogin() : "—";
        }
        String line = who + " : " + preview;

        for (Long uid : ownerRecipientIds) {
            userRepository.findByIdWithEverything(uid).ifPresent(
                    (u) -> inboxNotificationService.notifyPartnerGareCom(u, thread, thread.getTitle(), line));
        }
        for (var station : targetStations) {
            inboxNotificationService.notifyPartnerGareComForStation(station, thread, thread.getTitle(), line);
        }
    }
}