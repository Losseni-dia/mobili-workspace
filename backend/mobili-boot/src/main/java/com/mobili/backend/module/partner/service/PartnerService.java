package com.mobili.backend.module.partner.service;

import java.security.SecureRandom;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.partner.dto.PartnerRegisterDTO;
import com.mobili.backend.module.partner.dto.mapper.PartnerMapper;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.repository.PartnerRepository;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.role.Role;
import com.mobili.backend.module.user.role.RoleRepository;
import com.mobili.backend.module.user.role.UserRole;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;
import com.mobili.backend.shared.sharedService.UploadService;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class PartnerService {

    private static final char[] REG_CODE_ALPHANUM = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".toCharArray();
    private static final SecureRandom RANDOM = new SecureRandom();

    private final PartnerRepository partenaireRepository;
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final UploadService uploadService;
    private final PartnerMapper partnerMapper;

    public Partner getCurrentPartner() {
        Object principal = org.springframework.security.core.context.SecurityContextHolder
                .getContext().getAuthentication().getPrincipal();

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
     * Dirigeant (propriétaire fiche) ou compte gare rattaché à une gare de la compagnie (ex. enregistrer des chauffeurs).
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
    public Partner createPartnerForOwner(User owner, PartnerRegisterDTO dto, MultipartFile logoFile) {
        if (owner == null || owner.getId() == null) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Utilisateur invalide pour la société.");
        }
        Partner partenaire = partnerMapper.toEntity(dto);
        partenaire.setOwner(owner);

        Role partnerRole = roleRepository.findByName(UserRole.PARTNER).get();
        owner.getRoles().add(partnerRole);
        userRepository.save(owner);

        handleLogoUpload(partenaire, logoFile);

        if (partenaire.getRegistrationCode() == null || partenaire.getRegistrationCode().isBlank()) {
            partenaire.setRegistrationCode(generateUniqueRegistrationCode());
        }
        partenaire.setEnabled(false);
        return partenaireRepository.save(partenaire);
    }

    @Transactional
    public Partner save(Partner partenaire, MultipartFile logoFile, UserPrincipal principal) {
        if (partenaire.getId() == null) {
            User user = userRepository.findByLogin(principal.getUsername())
                    .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "User non trouvé"));

            PartnerRegisterDTO dto = new PartnerRegisterDTO();
            dto.setName(partenaire.getName());
            dto.setEmail(partenaire.getEmail());
            dto.setPhone(partenaire.getPhone());
            dto.setBusinessNumber(partenaire.getBusinessNumber());
            return createPartnerForOwner(user, dto, logoFile);
        }

        return partenaireRepository.findById(partenaire.getId())
                .map(existing -> {
                    existing.setName(partenaire.getName());
                    existing.setEmail(partenaire.getEmail());
                    existing.setPhone(partenaire.getPhone());
                    existing.setBusinessNumber(partenaire.getBusinessNumber());

                    handleLogoUpload(existing, logoFile);

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
