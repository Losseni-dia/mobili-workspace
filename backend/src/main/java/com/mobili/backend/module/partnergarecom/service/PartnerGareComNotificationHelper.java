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
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.notification.service.InboxNotificationService;

import lombok.RequiredArgsConstructor;

@Component
@RequiredArgsConstructor
class PartnerGareComNotificationHelper {

    private final UserRepository userRepository;
    private final InboxNotificationService inboxNotificationService;

    @Transactional
    public void notifyOnNewMessage(PartnerGareComThread thread, PartnerGareComMessage message, UserPrincipal author) {
        Long partnerId = thread.getPartner().getId();
        if (thread.getScope() == PartnerGareComThreadScope.TARGETED) {
            thread.getTargets().forEach(t -> t.getStation().getId());
        }
        Set<Long> recipientIds = new HashSet<>();
        var p = thread.getPartner();
        if (p.getOwner() != null) {
            Long oid = p.getOwner().getId();
            if (!oid.equals(author.getUser().getId())) {
                recipientIds.add(oid);
            }
        }
        if (thread.getScope() == PartnerGareComThreadScope.ALL) {
            for (Long gid : userRepository.findGareUserIdsByPartnerId(partnerId)) {
                if (!gid.equals(author.getUser().getId())) {
                    recipientIds.add(gid);
                }
            }
        } else {
            for (PartnerGareComThreadTarget tt : thread.getTargets()) {
                for (Long uid : userRepository.findGareUserIdsByStationId(tt.getStation().getId())) {
                    if (!uid.equals(author.getUser().getId())) {
                        recipientIds.add(uid);
                    }
                }
            }
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
        for (Long uid : recipientIds) {
            userRepository.findByIdWithEverything(uid).ifPresent(
                    (u) -> inboxNotificationService.notifyPartnerGareCom(u, thread, thread.getTitle(), line));
        }
    }
}
