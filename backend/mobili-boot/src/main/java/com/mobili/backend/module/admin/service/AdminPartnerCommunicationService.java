package com.mobili.backend.module.admin.service;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.module.admin.dto.AdminPartnerCommunicationRequest;
import com.mobili.backend.module.admin.dto.AdminPartnerCommunicationRequest.AdminPartnerCommunicationSegment;
import com.mobili.backend.module.admin.dto.AdminPartnerCommunicationRequest.AdminPartnerCommunicationTarget;
import com.mobili.backend.module.admin.dto.AdminPartnerCommunicationResponse;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class AdminPartnerCommunicationService {

    private final PartnerService partnerService;
    private final UserRepository userRepository;
    private final InboxNotificationService inboxNotificationService;

    @Transactional
    public AdminPartnerCommunicationResponse send(AdminPartnerCommunicationRequest request) {
        if (request.getTarget() == AdminPartnerCommunicationTarget.PICK) {
            List<Long> ids = request.getPartnerIds();
            if (ids == null || ids.isEmpty()) {
                throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Sélectionnez au moins un partenaire.");
            }
        }

        Set<Long> ownerUserIds = new LinkedHashSet<>();
        if (request.getTarget() == AdminPartnerCommunicationTarget.BROADCAST) {
            for (Partner p : partnerService.findAll()) {
                if (p.getOwner() == null) {
                    continue;
                }
                if (!request.isIncludeDisabled() && !p.isEnabled()) {
                    continue;
                }
                boolean take = switch (request.getSegment()) {
                    case ALL -> true;
                    case COMPANIES -> !p.isCovoiturageSoloPool();
                    case COVOITURAGE_POOL -> p.isCovoiturageSoloPool();
                };
                if (take) {
                    ownerUserIds.add(p.getOwner().getId());
                }
            }
            if (request.getSegment() == AdminPartnerCommunicationSegment.ALL
                    || request.getSegment() == AdminPartnerCommunicationSegment.COVOITURAGE_POOL) {
                addCovoiturageChauffeurKycApprouves(ownerUserIds, request.isIncludeDisabled());
            }
        } else {
            for (Long partnerId : request.getPartnerIds()) {
                Partner p = partnerService.findById(partnerId);
                if (p.getOwner() == null) {
                    throw new MobiliException(
                            MobiliErrorCode.VALIDATION_ERROR,
                            "Le partenaire n°" + partnerId + " n’a pas de compte dirigeant associé.");
                }
                ownerUserIds.add(p.getOwner().getId());
            }
        }

        int n = inboxNotificationService.notifyPartnerOwnersInfoFromAdmin(ownerUserIds, request.getTitle(), request.getBody());
        return new AdminPartnerCommunicationResponse(n);
    }

    private void addCovoiturageChauffeurKycApprouves(Set<Long> target, boolean includeDisabled) {
        List<Long> ids = includeDisabled
                ? userRepository.findAllCovoiturageChauffeurKycApprovedUserIds()
                : userRepository.findEnabledCovoiturageChauffeurKycApprovedUserIds();
        target.addAll(ids);
    }
}
