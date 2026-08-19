package com.mobili.backend.module.partner.service;

import java.security.SecureRandom;
import java.util.List;
import java.util.Map;

import org.springframework.context.annotation.Lazy;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.notification.entity.MobiliNotificationType;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.partner.dto.PartnerRegisterDTO;
import com.mobili.backend.module.partner.dto.mapper.PartnerMapper;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.repository.PartnerRepository;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.role.Role;
import com.mobili.backend.module.user.role.RoleRepository;
import com.mobili.backend.module.user.role.UserRole;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;
import com.mobili.backend.shared.sharedService.UploadService;


@Service
public class PartnerService {

    private static final char[] REG_CODE_ALPHANUM = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".toCharArray();
    private static final SecureRandom RANDOM = new SecureRandom();

    private final PartnerRepository partenaireRepository;
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final UploadService uploadService;
    private final PartnerMapper partnerMapper;
    private final InboxNotificationService inboxNotificationService;

    public PartnerService(
            PartnerRepository partenaireRepository,
            UserRepository userRepository,
            RoleRepository roleRepository,
            UploadService uploadService,
            PartnerMapper partnerMapper,
            @Lazy InboxNotificationService inboxNotificationService) {
        this.partenaireRepository = partenaireRepository;
        this.userRepository = userRepository;
        this.roleRepository = roleRepository;
        this.uploadService = uploadService;
        this.partnerMapper = partnerMapper;
        this.inboxNotificationService = inboxNotificationService;
    }

    public Partner getCurrentPartner() {
        Object principal = org.springframework.security.core.context.SecurityContextHolder
                .getContext().getAuthentication().getPrincipal();

        if (principal instanceof com.mobili.backend.infrastructure.security.authentication.StationPrincipal stationPrincipal) {
            Long partnerId = stationPrincipal.getPartnerId();
            if (partnerId == null) {
                throw new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND,
                        "Cette gare n'est rattachée à aucune compagnie.");
            }
            return partenaireRepository.findById(partnerId)
                    .orElseThrow(
                            () -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Partenaire non trouvé"));
        }

        if (!(principal instanceof UserPrincipal)) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Non authentifié");
        }

        UserPrincipal userPrincipal = (UserPrincipal) principal;

        if (userPrincipal.getPartnerId() != null) {
            return partenaireRepository.findById(userPrincipal.getPartnerId())
                    .orElseThrow(
                            () -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Partenaire non trouvé"));
        }
        Long userId = userPrincipal.getUser().getId();
        return partenaireRepository.findByOwnerId(userId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND,
                        "Aucune entreprise liée à cet utilisateur"));
    }

    /**
     * Même que {@link #getCurrentPartner()} mais interdit toute opération si la compagnie n’est pas
     * validée (activée) par l’admin.
     */
    public Partner getCurrentPartnerForOperations() {
        Partner p = getCurrentPartner();
        assertPartnerCanOperate(p);
        return p;
    }

    public void assertPartnerCanOperate(Partner partner) {
        if (partner == null || !partner.isEnabled()) {
            throw new MobiliException(
                    MobiliErrorCode.ACCESS_DENIED,
                    "Votre compagnie n'est pas encore validée par un administrateur. Vous serez notifié lorsque l'accès sera activé.");
        }
    }

    /**
     * Propriétaire de la fiche compagnie uniquement (pas le compte gare, pas un employé rattaché).
     * Même règle que la création de gares / comptes gare côté partenaire.
     */
    public void requirePartnerDirigeant(UserPrincipal principal) {
        User u = principal.getUser();
        if (u.getStation() != null) {
            throw new MobiliException(
                    MobiliErrorCode.ACCESS_DENIED,
                    "Réservé au dirigeant de la compagnie");
        }
        if (u.getPartner() == null) {
            throw new MobiliException(
                    MobiliErrorCode.ACCESS_DENIED,
                    "Réservé au dirigeant de la compagnie");
        }
        if (u.getPartner().getOwner() == null || !u.getPartner().getOwner().getId().equals(u.getId())) {
            throw new MobiliException(
                    MobiliErrorCode.ACCESS_DENIED,
                    "Réservé au dirigeant de la compagnie");
        }
    }

    /**
     * Variante acceptant aussi une connexion "gare" (StationPrincipal) : la gare
     * elle-même
     * appartient forcément à sa compagnie, donc toujours autorisée ici.
     */
    public void requireDirigeantOuGareDeLaCompagnie(Object principal) {
        if (principal instanceof com.mobili.backend.infrastructure.security.authentication.StationPrincipal) {
            return;
        }
        if (principal instanceof UserPrincipal up) {
            requireDirigeantOuGareDeLaCompagnie(up);
            return;
        }
        throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Non authentifié");
    }

    /**
     * Dirigeant (propriétaire fiche) ou compte gare rattaché à une gare de la
     * compagnie (ex. enregistrer des chauffeurs).
     */
    public void requireDirigeantOuGareDeLaCompagnie(UserPrincipal principal) {
        User u = principal.getUser();
        if (u.getStation() == null
                && u.getPartner() != null
                && u.getPartner().getOwner() != null
                && u.getPartner().getOwner().getId().equals(u.getId())) {
            return;
        }
        if (u.getStation() != null
                && u.getStation().getPartner() != null
                && u.getRoles() != null
                && u.getRoles().stream().anyMatch(r -> r.getName() == UserRole.GARE)) {
            return;
        }
        throw new MobiliException(
                MobiliErrorCode.ACCESS_DENIED,
                "Réservé au dirigeant ou à un compte gare de la compagnie.");
    }


    /**
     * Résout l’entreprise courante (comme {@link #getCurrentPartner()}) et crée
     * un {@link Partner#getRegistrationCode() code} s’il est encore absent (affichage / API).
     */
    @Transactional
    public Partner getCurrentPartnerEnsuringRegistrationCode() {
        Partner p = getCurrentPartner();
        if (p.getRegistrationCode() == null || p.getRegistrationCode().isBlank()) {
            p.setRegistrationCode(generateUniqueRegistrationCode());
            p = partenaireRepository.save(p);
        }
        return p;
    }

    @Transactional(readOnly = true)
    public List<Partner> findAll() {
        return partenaireRepository.findAll();
    }

    @Transactional(readOnly = true)
    public Partner findById(Long id) {
        return partenaireRepository.findById(id)
                .orElseThrow(() -> new MobiliException(
                        MobiliErrorCode.RESOURCE_NOT_FOUND,
                        "Partenaire introuvable (ID: " + id + ")"));
    }

    /**
     * Création fiche société pour un utilisateur déjà persisté (inscription publique dirigeant),
     * même logique métier que {@link #save} sans JWT.
     */
    @Transactional
    public Partner createPartnerForOwner(User owner, PartnerRegisterDTO dto, MultipartFile logoFile,
            MultipartFile kycFrontFile, MultipartFile kycBackFile,
            MultipartFile transportCardFrontFile, MultipartFile transportCardBackFile) {
        if (owner == null || owner.getId() == null) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Utilisateur invalide pour la société.");
        }
        if (dto.getPhone() != null) {
            boolean exists = partenaireRepository.existsByPhone(dto.getPhone().trim());
            if (exists) {
                throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE,
                        "Ce numéro de téléphone est déjà utilisé par une autre société.",
                        Map.of("companyPhone", "Ce numéro est déjà utilisé par une autre société."));
            }
        }
        if (dto.getEmail() != null && !dto.getEmail().isBlank()
                && partenaireRepository.existsByEmailIgnoreCase(dto.getEmail().trim())) {
            throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE,
                    "Cet email est déjà utilisé par une autre société.",
                    Map.of("companyEmail", "Cet email est déjà utilisé par une autre société."));
        }
        if (kycFrontFile == null || kycFrontFile.isEmpty() || kycBackFile == null || kycBackFile.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Les photos recto et verso de la carte d'identité du gérant sont obligatoires.");
        }
        if (transportCardFrontFile == null || transportCardFrontFile.isEmpty()
                || transportCardBackFile == null || transportCardBackFile.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Les photos recto et verso de la carte de transporteur sont obligatoires.");
        }

        Partner partenaire = partnerMapper.toEntity(dto);
        partenaire.setOwner(owner);

        Role partnerRole = roleRepository.findByName(UserRole.PARTNER).get();
        owner.getRoles().add(partnerRole);
        userRepository.save(owner);

        handleLogoUpload(partenaire, logoFile);
        handleKycUpload(partenaire, kycFrontFile, kycBackFile);
        handleTransportCardUpload(partenaire, transportCardFrontFile, transportCardBackFile);

        if (partenaire.getRegistrationCode() == null || partenaire.getRegistrationCode().isBlank()) {
            partenaire.setRegistrationCode(generateUniqueRegistrationCode());
        }
        partenaire.setEnabled(false);
        partenaire.setApprovalStatus(com.mobili.backend.module.partner.entity.PartnerApprovalStatus.PENDING);
        return partenaireRepository.save(partenaire);
    }

    @Transactional
    public Partner save(Partner partenaire, MultipartFile logoFile, UserPrincipal principal) {
        return save(partenaire, logoFile, null, null, null, null, principal);
    }

    @Transactional
    public Partner save(Partner partenaire, MultipartFile logoFile, MultipartFile kycFrontFile,
            MultipartFile kycBackFile, UserPrincipal principal) {
        return save(partenaire, logoFile, kycFrontFile, kycBackFile, null, null, principal);
    }

    @Transactional
    public Partner save(Partner partenaire, MultipartFile logoFile, MultipartFile kycFrontFile,
            MultipartFile kycBackFile, MultipartFile transportCardFrontFile, MultipartFile transportCardBackFile,
            UserPrincipal principal) {
        if (partenaire.getId() == null) {
            User user = userRepository.findByLogin(principal.getUsername())
                    .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "User non trouvé"));

            PartnerRegisterDTO dto = new PartnerRegisterDTO();
            dto.setName(partenaire.getName());
            dto.setEmail(partenaire.getEmail());
            dto.setPhone(partenaire.getPhone());
            dto.setBusinessNumber(partenaire.getBusinessNumber());
            return createPartnerForOwner(user, dto, logoFile, kycFrontFile, kycBackFile,
                    transportCardFrontFile, transportCardBackFile);
        }

        return partenaireRepository.findById(partenaire.getId())
                .map(existing -> {
                    if (partenaire.getPhone() != null
                            && !partenaire.getPhone().equals(existing.getPhone())
                            && partenaireRepository.existsByPhone(partenaire.getPhone().trim())) {
                        throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE,
                                "Ce numéro de téléphone est déjà utilisé par une autre société.",
                                Map.of("phone", "Ce numéro est déjà utilisé par une autre société."));
                    }
                    if (partenaire.getEmail() != null && !partenaire.getEmail().isBlank()
                            && !partenaire.getEmail().equalsIgnoreCase(existing.getEmail())
                            && partenaireRepository.existsByEmailIgnoreCase(partenaire.getEmail().trim())) {
                        throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE,
                                "Cet email est déjà utilisé par une autre société.",
                                Map.of("email", "Cet email est déjà utilisé par une autre société."));
                    }

                    existing.setName(partenaire.getName());
                    existing.setEmail(partenaire.getEmail());
                    existing.setPhone(partenaire.getPhone());
                    existing.setBusinessNumber(partenaire.getBusinessNumber());

                    handleLogoUpload(existing, logoFile);
                    handleKycUpload(existing, kycFrontFile, kycBackFile);
                    handleTransportCardUpload(existing, transportCardFrontFile, transportCardBackFile);

                    // Resoumission après rejet : repasse en attente, motif effacé.
                    if (existing
                            .getApprovalStatus() == com.mobili.backend.module.partner.entity.PartnerApprovalStatus.REJECTED) {
                        existing.setApprovalStatus(
                                com.mobili.backend.module.partner.entity.PartnerApprovalStatus.PENDING);
                        existing.setRejectionReason(null);
                        inboxNotificationService.notifyAdmins(
                                "Dossier corrigé et resoumis",
                                "« " + existing.getName() + " » a corrigé son dossier et le resoumet pour approbation.",
                                com.mobili.backend.module.notification.entity.MobiliNotificationType.PARTNER_SUBMISSION_PENDING,
                                existing);
                    }

                    return partenaireRepository.save(existing);
                })
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Partenaire introuvable"));
    }

    private String generateUniqueRegistrationCode() {
        for (int attempt = 0; attempt < 20; attempt++) {
            StringBuilder sb = new StringBuilder(8);
            for (int i = 0; i < 8; i++) {
                sb.append(REG_CODE_ALPHANUM[RANDOM.nextInt(REG_CODE_ALPHANUM.length)]);
            }
            String code = sb.toString();
            if (partenaireRepository.findByRegistrationCodeIgnoreCase(code).isEmpty()) {
                return code;
            }
        }
        throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Impossible de générer un code partenaire unique");
    }

    private void handleLogoUpload(Partner partner, MultipartFile file) {
        if (file != null && !file.isEmpty()) {
            String path = uploadService.saveImage(file, "partners");
            partner.setLogoUrl(path);
        }
    }

    private void handleKycUpload(Partner partner, MultipartFile front, MultipartFile back) {
        if (front != null && !front.isEmpty()) {
            partner.setKycFrontUrl(uploadService.saveImage(front, "partners/kyc"));
        }
        if (back != null && !back.isEmpty()) {
            partner.setKycBackUrl(uploadService.saveImage(back, "partners/kyc"));
        }
    }

    /** Carte de transporteur — image ou PDF, dossier sensible (contrairement à la CNI dirigeant ci-dessus, publique par historique). */
    private void handleTransportCardUpload(Partner partner, MultipartFile front, MultipartFile back) {
        if (front != null && !front.isEmpty()) {
            partner.setTransportCardFrontUrl(uploadService.saveAttachment(front, UploadService.FOLDER_SENSITIVE_PARTNER_LEGAL));
        }
        if (back != null && !back.isEmpty()) {
            partner.setTransportCardBackUrl(uploadService.saveAttachment(back, UploadService.FOLDER_SENSITIVE_PARTNER_LEGAL));
        }
    }

    @Transactional(readOnly = true)
    public Partner findByOwnerId(Long ownerId) {
        return partenaireRepository.findByOwnerId(ownerId)
                .orElseThrow(() -> new MobiliException(
                        MobiliErrorCode.RESOURCE_NOT_FOUND,
                        "Aucune entreprise n'est associée à cet utilisateur."));
    }

    @Transactional
    public void fillMissingRegistrationCodes() {
        for (Partner p : partenaireRepository.findAll()) {
            if (p.getRegistrationCode() == null || p.getRegistrationCode().isBlank()) {
                p.setRegistrationCode(generateUniqueRegistrationCode());
                partenaireRepository.save(p);
            }
        }
    }

    @Transactional
    public void toggleStatus(Long id) {
        Partner p = findById(id);
        p.setEnabled(!p.isEnabled());
        partenaireRepository.save(p);
        if (p.getOwner() != null) {
            if (p.isEnabled()) {
                inboxNotificationService.notifyUser(
                        p.getOwner(),
                        "Compagnie réactivée ✅",
                        "Votre compagnie « " + p.getName()
                                + " » a été réactivée. Vous pouvez à nouveau publier des trajets.",
                        com.mobili.backend.module.notification.entity.MobiliNotificationType.PARTNER_APPROVED,
                        p);
            } else {
                inboxNotificationService.notifyUser(
                        p.getOwner(),
                        "Compagnie suspendue",
                        "Votre compagnie « " + p.getName()
                                + " » a été temporairement suspendue par l'équipe Mobili. Contactez le support pour plus d'informations.",
                        com.mobili.backend.module.notification.entity.MobiliNotificationType.PARTNER_REJECTED,
                        p);
            }
        }
    }

    @Transactional
    public void approvePartner(Long id) {
        Partner p = findById(id);
        p.setApprovalStatus(com.mobili.backend.module.partner.entity.PartnerApprovalStatus.APPROVED);
        p.setEnabled(true);
        partenaireRepository.save(p);
        if (p.getOwner() != null) {
            inboxNotificationService.notifyUser(
                    p.getOwner(),
                    "Compagnie approuvée ✅",
                    "Votre compagnie « " + p.getName()
                            + " » a été approuvée par l'équipe Mobili. Vous pouvez maintenant publier des trajets.",
                    com.mobili.backend.module.notification.entity.MobiliNotificationType.PARTNER_APPROVED,
                    p);
        }
    }

    @Transactional
    public void rejectPartner(Long id, String reason) {
        if (reason == null || reason.isBlank()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Le motif de rejet est obligatoire.");
        }
        Partner p = findById(id);
        p.setApprovalStatus(com.mobili.backend.module.partner.entity.PartnerApprovalStatus.REJECTED);
        p.setEnabled(false);
        p.setRejectionReason(reason.trim());
        partenaireRepository.save(p);
        if (p.getOwner() != null) {
            inboxNotificationService.notifyUser(
                    p.getOwner(),
                    "Compagnie rejetée",
                    "Votre compagnie « " + p.getName() + " » n'a pas pu être validée. Motif : " + reason.trim(),
                    MobiliNotificationType.PARTNER_REJECTED,
                    p);
        }
    }

    @Transactional
    public void delete(Long id) {
        if (!partenaireRepository.existsById(id)) {
            throw new MobiliException(
                    MobiliErrorCode.RESOURCE_NOT_FOUND,
                    "Impossible de supprimer : Partenaire inexistant");
        }
        partenaireRepository.deleteById(id);
    }
}
