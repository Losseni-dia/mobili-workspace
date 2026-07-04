package com.mobili.backend.module.user.service;

import java.util.Collections;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.module.partner.dto.PartnerRegisterDTO;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.partner.dto.PartnerChauffeurCreateRequest;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.repository.PartnerRepository;
import com.mobili.backend.module.station.entity.Station;
import com.mobili.backend.module.station.repository.StationRepository;
import com.mobili.backend.module.partner.service.PartnerService;
import com.mobili.backend.module.user.dto.RegisterCompanyPublicDTO;
import com.mobili.backend.module.user.dto.ApplyCovoiturageDriverDTO;
import com.mobili.backend.module.user.dto.RegisterCarpoolChauffeurDTO;
import com.mobili.backend.module.user.dto.UpdateCovoiturageProfileDTO;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.role.CovoiturageKycStatus;
import com.mobili.backend.module.user.role.Role;
import com.mobili.backend.module.user.role.RoleRepository;
import com.mobili.backend.module.user.role.UserRole;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;
import com.mobili.backend.shared.sharedService.UploadService;

import jakarta.transaction.Transactional;

@Service
@Transactional
public class UserService {

    private final UserRepository userRepository;
    private final PartnerRepository partnerRepository;
    private final StationRepository stationRepository;
    private final RoleRepository roleRepository;
    private final PasswordEncoder passwordEncoder;
    private final UploadService uploadService;
    private final PartnerService partnerService;
    private final InboxNotificationService inboxNotificationService;

    public UserService(
            UserRepository userRepository,
            PartnerRepository partnerRepository,
            StationRepository stationRepository,
            RoleRepository roleRepository,
            PasswordEncoder passwordEncoder,
            UploadService uploadService,
            PartnerService partnerService,
            @org.springframework.context.annotation.Lazy InboxNotificationService inboxNotificationService) {
        this.userRepository = userRepository;
        this.partnerRepository = partnerRepository;
        this.stationRepository = stationRepository;
        this.roleRepository = roleRepository;
        this.passwordEncoder = passwordEncoder;
        this.uploadService = uploadService;
        this.partnerService = partnerService;
        this.inboxNotificationService = inboxNotificationService;
    }

    public Optional<User> findFirstAdmin() {
        return userRepository.findAdmins().stream().findFirst();
    }

    @Transactional
    public void updateFcmToken(Long userId, String fcmToken) {
        User user = findById(userId);
        user.setFcmToken(fcmToken);
        userRepository.save(user);
    }

    @Transactional
    public void updateCovoiturageKycStatus(Long id, String status) {
        User user = findById(id);
        CovoiturageKycStatus kycStatus = CovoiturageKycStatus.valueOf(status.toUpperCase());
        user.setCovoiturageKycStatus(kycStatus);
        if (kycStatus == CovoiturageKycStatus.APPROVED) {
            user.setEnabled(true);
            userRepository.save(user);
            inboxNotificationService.notifyUser(
                    user,
                    "Dossier covoiturage approuvé ✅",
                    "Votre dossier conducteur a été validé par l'équipe Mobili. Vous pouvez maintenant proposer des trajets covoiturage.",
                    com.mobili.backend.module.notification.entity.MobiliNotificationType.COV_KYC_APPROVED);
        } else if (kycStatus == CovoiturageKycStatus.REJECTED) {
            userRepository.save(user);
            inboxNotificationService.notifyUser(
                    user,
                    "Dossier covoiturage rejeté",
                    "Votre dossier conducteur n'a pas pu être validé. Vérifiez vos documents et contactez le support Mobili.",
                    com.mobili.backend.module.notification.entity.MobiliNotificationType.COV_KYC_REJECTED);
        } else {
            userRepository.save(user);
        }
    }

    public User findById(Long id) {
        // 💡 On utilise la méthode avec FETCH pour éviter la
        // LazyInitializationException
        return userRepository.findByIdWithEverything(id)
                .orElseThrow(() -> new MobiliException(
                        MobiliErrorCode.RESOURCE_NOT_FOUND,
                        "Utilisateur introuvable (ID: " + id + ")"));
    }

    /** Référence légère (clé) pour clés étrangères, sans requête complète. */
    public User getReference(Long id) {
        return userRepository.getReferenceById(id);
    }

    public List<User> findAllUsers() {
        // Charge rôles + partenaire + gare (pour fiche admin : société / gare)
        return userRepository.findAllForProfileDto();
    }

    public List<User> findCovoiturageSoloProfileUsersOrderByName() {
        return userRepository.findCovoiturageSoloProfileUsersOrderByName();
    }

    @Transactional
    public User registerUser(User user, MultipartFile avatarFile) {
        // Vérification des doublons
        String normalizedEmail = (user.getEmail() != null && !user.getEmail().trim().isEmpty())
                ? user.getEmail().trim().toLowerCase()
                : null;
        user.setEmail(normalizedEmail);

        String normalizedLogin = user.getLogin() != null ? user.getLogin().trim().toLowerCase() : null;
        user.setLogin(normalizedLogin);

        if (normalizedEmail != null && userRepository.existsByEmailIgnoreCase(normalizedEmail)) {
            throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Cet email est déjà utilisé.",
                    Map.of("email", "Cet email est déjà utilisé."));
        }
        if (normalizedLogin != null && userRepository.existsByLoginIgnoreCase(normalizedLogin)) {
            throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Ce login est déjà utilisé.",
                    Map.of("login", "Ce login est déjà utilisé."));
        }

        user.setPassword(passwordEncoder.encode(user.getPassword()));
        user.setEnabled(true);

        assignRoles(user, Collections.singleton(UserRole.USER));

        // Utilisation du service partagé pour l'avatar
        if (avatarFile != null && !avatarFile.isEmpty()) {
            // CHANGEMENT ICI : On passe "users" au lieu de "avatars"
            String path = uploadService.saveImage(avatarFile, "users");
            user.setAvatarUrl(path);
        }

        return userRepository.save(user);
    }

    /**
     * Inscription publique dirigeant : compte utilisateur + fiche société en
     * attente validation admin
     * (même règle que création compagnie depuis un compte déjà connecté).
     */
    @Transactional
    public User registerCompanyPublic(RegisterCompanyPublicDTO dto,
            org.springframework.web.multipart.MultipartFile logo) {
        if (userRepository.existsByEmailIgnoreCase(dto.getEmail())) {
            throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Cet email dirigeant est déjà utilisé.");
        }
        if (userRepository.existsByLogin(dto.getLogin())) {
            throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Ce login est déjà utilisé.");
        }

        User user = new User();
        user.setFirstname(dto.getFirstname());
        user.setLastname(dto.getLastname());
        user.setLogin(dto.getLogin());
        user.setEmail(dto.getEmail());
        user.setPassword(passwordEncoder.encode(dto.getPassword()));
        user.setEnabled(true);
        assignRoles(user, Collections.singleton(UserRole.USER));
        user = userRepository.save(user);

        PartnerRegisterDTO pr = new PartnerRegisterDTO();
        pr.setName(dto.getCompanyName());
        pr.setEmail(dto.getCompanyEmail());
        pr.setPhone(dto.getCompanyPhone());
        if (dto.getBusinessNumber() != null && !dto.getBusinessNumber().isBlank()) {
            pr.setBusinessNumber(dto.getBusinessNumber().trim());
        }

        partnerService.createPartnerForOwner(user, pr, logo);

        return userRepository.findByIdWithEverything(user.getId())
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND,
                        "Utilisateur introuvable après inscription."));
    }

    /**
     * Inscription **chauffeur covoiturage** : rôles USER + CHAUFFEUR, pièce
     * d’identité recto/verso, date
     * de fin de validité, statut KYC {@link CovoiturageKycStatus#PENDING}.
     */
    @Transactional
    public User registerCarpoolChauffeur(
            RegisterCarpoolChauffeurDTO dto,
            MultipartFile idFront,
            MultipartFile idBack,
            MultipartFile driverPhoto,
            MultipartFile vehiclePhoto) {
        if (idFront == null || idFront.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Le recto de la pièce d'identité est obligatoire.");
        }
        if (idBack == null || idBack.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Le verso de la pièce d'identité est obligatoire.");
        }
        if (driverPhoto == null || driverPhoto.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "La photo du conducteur est obligatoire.");
        }
        if (vehiclePhoto == null || vehiclePhoto.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "La photo du véhicule est obligatoire.");
        }
        if (userRepository.existsByEmailIgnoreCase(dto.getEmail())) {
            throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Cet email est déjà utilisé.");
        }
        if (userRepository.existsByLogin(dto.getLogin())) {
            throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Ce login est déjà utilisé.");
        }

        User user = new User();
        user.setFirstname(dto.getFirstname());
        user.setLastname(dto.getLastname());
        user.setLogin(dto.getLogin());
        user.setEmail(dto.getEmail());
        user.setPassword(passwordEncoder.encode(dto.getPassword()));
        /**
         * Désactivé tant que l’admin n’active pas le compte (login impossible). KYC =
         * PENDING.
         */
        user.setEnabled(false);
        user.setCovoiturageIdValidUntil(dto.getIdValidUntil());
        user.setCovoiturageKycStatus(CovoiturageKycStatus.PENDING);
        user.setCovoiturageVehicleBrand(dto.getVehicleBrand().trim());
        user.setCovoiturageVehiclePlate(dto.getVehiclePlate().trim().toUpperCase());
        user.setCovoiturageVehicleColor(dto.getVehicleColor().trim());
        user.setCovoiturageGreyCardNumber(dto.getGreyCardNumber().trim());

        String frontPath = saveCarpoolIdentityScan(idFront);
        String backPath = saveCarpoolIdentityScan(idBack);
        user.setCovoiturageIdFrontUrl(frontPath);
        user.setCovoiturageIdBackUrl(backPath);
        String driverPath = uploadService.saveImage(driverPhoto, UploadService.FOLDER_SENSITIVE_COVOITURAGE_DRIVERS);
        user.setCovoiturageDriverPhotoUrl(driverPath);
        String vehPath = uploadService.saveImage(vehiclePhoto, UploadService.FOLDER_SENSITIVE_COVOITURAGE_VEHICLES);
        user.setCovoiturageVehiclePhotoUrl(vehPath);
        user.setCovoiturageKycExpiringNotifiedFor(null);
        user.setCovoiturageKycExpiredNotified(false);
        user.setCovoiturageSoloProfile(true);

        assignRoles(user, Set.of(UserRole.USER, UserRole.CHAUFFEUR));
        return userRepository.save(user);
    }

    @Transactional
    public User updateUser(Long id, User updatedInfo, String oldPassword, Set<UserRole> roleNames,
            MultipartFile avatarFile) {
        User existingUser = findById(id);

        existingUser.setFirstname(updatedInfo.getFirstname());
        existingUser.setLastname(updatedInfo.getLastname());
        existingUser.setEmail(updatedInfo.getEmail());
        existingUser.setLogin(updatedInfo.getLogin());
        if (updatedInfo.getPhone() != null) {
            existingUser.setPhone(updatedInfo.getPhone());
        }
        // Hashage du mot de passe seulement s'il est fourni
        if (updatedInfo.getPassword() != null && !updatedInfo.getPassword().isBlank()) {
            // Vérifier l'ancien mot de passe
            if (oldPassword == null || oldPassword.isBlank()) {
                throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                        "L'ancien mot de passe est requis pour changer le mot de passe.");
            }
            if (!passwordEncoder.matches(oldPassword, existingUser.getPassword())) {
                throw new MobiliException(MobiliErrorCode.INVALID_CREDENTIALS,
                        "Ancien mot de passe incorrect.");
            }
            existingUser.setPassword(passwordEncoder.encode(updatedInfo.getPassword()));
        }
        // Gestion des rôles (si passés, sinon on garde les anciens)
        if (roleNames != null && !roleNames.isEmpty()) {
            assignRoles(existingUser, roleNames);
        }

        // Gestion de l'avatar dans le dossier "users" (configuré dans ton YAML)
        if (avatarFile != null && !avatarFile.isEmpty()) {
            String path = uploadService.saveImage(avatarFile, "users");
            existingUser.setAvatarUrl(path);
        }

        return userRepository.save(existingUser);
    }

    @Transactional
    public User updateCovoiturageProfile(
            Long userId, UpdateCovoiturageProfileDTO dto,
            MultipartFile driverPhoto, MultipartFile vehiclePhoto) {
        User user = findById(userId);
        if (!Boolean.TRUE.equals(user.getCovoiturageSoloProfile())) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Profil covoiturage particulier requis.");
        }
        if (dto.getVehicleBrand() != null && !dto.getVehicleBrand().isBlank()) {
            user.setCovoiturageVehicleBrand(dto.getVehicleBrand().trim());
        }
        if (dto.getVehiclePlate() != null && !dto.getVehiclePlate().isBlank()) {
            user.setCovoiturageVehiclePlate(dto.getVehiclePlate().trim().toUpperCase(Locale.ROOT));
        }
        if (dto.getVehicleColor() != null && !dto.getVehicleColor().isBlank()) {
            user.setCovoiturageVehicleColor(dto.getVehicleColor().trim());
        }
        if (dto.getGreyCardNumber() != null && !dto.getGreyCardNumber().isBlank()) {
            user.setCovoiturageGreyCardNumber(dto.getGreyCardNumber().trim());
        }
        if (driverPhoto != null && !driverPhoto.isEmpty()) {
            user.setCovoiturageDriverPhotoUrl(uploadService.saveImage(driverPhoto, "covoiturage/drivers"));
        }
        if (vehiclePhoto != null && !vehiclePhoto.isEmpty()) {
            user.setCovoiturageVehiclePhotoUrl(uploadService.saveImage(vehiclePhoto, "vehicles"));
        }
        return userRepository.save(user);
    }

    /**
     * Un voyageur déjà inscrit (compte existant, actif) soumet un dossier
     * conducteur covoiturage — contrairement à {@link #registerCarpoolChauffeur}
     * qui crée un tout nouveau compte. Le compte reste actif et utilisable
     * normalement pendant l'attente de validation ; seule la publication de
     * trajets covoiturage est bloquée tant que le KYC n'est pas APPROVED
     * (cf. {@code TripService#createCovoiturageSoloTrip}).
     */
    public User applyAsCovoiturageDriver(
            Long userId,
            ApplyCovoiturageDriverDTO dto,
            MultipartFile idFront,
            MultipartFile idBack,
            MultipartFile driverPhoto,
            MultipartFile vehiclePhoto) {
        if (idFront == null || idFront.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Le recto de la pièce d'identité est obligatoire.");
        }
        if (idBack == null || idBack.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Le verso de la pièce d'identité est obligatoire.");
        }
        if (driverPhoto == null || driverPhoto.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "La photo du conducteur est obligatoire.");
        }
        if (vehiclePhoto == null || vehiclePhoto.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "La photo du véhicule est obligatoire.");
        }

        User user = findById(userId);
        CovoiturageKycStatus current = user.getCovoiturageKycStatus();
        if (current == CovoiturageKycStatus.PENDING || current == CovoiturageKycStatus.APPROVED) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Vous avez déjà un dossier conducteur covoiturage en cours ou validé.");
        }

        user.setCovoiturageIdValidUntil(dto.getIdValidUntil());
        user.setCovoiturageKycStatus(CovoiturageKycStatus.PENDING);
        user.setCovoiturageVehicleBrand(dto.getVehicleBrand().trim());
        user.setCovoiturageVehiclePlate(dto.getVehiclePlate().trim().toUpperCase(Locale.ROOT));
        user.setCovoiturageVehicleColor(dto.getVehicleColor().trim());
        user.setCovoiturageGreyCardNumber(dto.getGreyCardNumber().trim());

        user.setCovoiturageIdFrontUrl(saveCarpoolIdentityScan(idFront));
        user.setCovoiturageIdBackUrl(saveCarpoolIdentityScan(idBack));
        user.setCovoiturageDriverPhotoUrl(
                uploadService.saveImage(driverPhoto, UploadService.FOLDER_SENSITIVE_COVOITURAGE_DRIVERS));
        user.setCovoiturageVehiclePhotoUrl(
                uploadService.saveImage(vehiclePhoto, UploadService.FOLDER_SENSITIVE_COVOITURAGE_VEHICLES));
        user.setCovoiturageKycExpiringNotifiedFor(null);
        user.setCovoiturageKycExpiredNotified(false);
        user.setCovoiturageSoloProfile(true);

        addChauffeurRoleIfMissing(user);

        return userRepository.save(user);
    }

    /**
     * Ajoute CHAUFFEUR sans retirer les rôles déjà détenus (PARTNER, GARE, ADMIN,
     * etc.).
     */
    private void addChauffeurRoleIfMissing(User user) {
        boolean hasChauffeur = user.getRoles().stream().anyMatch(r -> r.getName() == UserRole.CHAUFFEUR);
        if (hasChauffeur) {
            return;
        }
        Role chauffeurRole = roleRepository.findByName(UserRole.CHAUFFEUR)
                .orElseThrow(
                        () -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Rôle CHAUFFEUR inexistant"));
        Set<Role> roles = new java.util.HashSet<>(user.getRoles());
        roles.add(chauffeurRole);
        user.setRoles(roles);
    }

    public void toggleUserStatus(Long id, boolean enabled) {
        User user = findById(id);
        user.setEnabled(enabled);
        if (enabled && user.getCovoiturageKycStatus() == CovoiturageKycStatus.PENDING) {
            user.setCovoiturageKycStatus(CovoiturageKycStatus.APPROVED);
        }
        userRepository.save(user);
    }

    /**
     * Chauffeur société créé par le dirigeant ou un compte gare (espace
     * partenaire).
     */
    @Transactional
    public User registerCompanyChauffeur(Partner employer, PartnerChauffeurCreateRequest dto, MultipartFile avatar) {
        if (employer.isCovoiturageSoloPool()) {
            throw new MobiliException(
                    MobiliErrorCode.VALIDATION_ERROR,
                    "Opération interdite pour le partenaire piscine covoiturage.");
        }
        String email = dto.email() != null ? dto.email().trim().toLowerCase() : null;
        String login = dto.login().trim();
        if (email != null && userRepository.existsByEmailIgnoreCase(email)) {
            throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Cet email est déjà utilisé.");
        }
        if (userRepository.existsByLogin(login)) {
            throw new MobiliException(MobiliErrorCode.DUPLICATE_RESOURCE, "Ce login est déjà utilisé.");
        }
        User u = new User();
        u.setFirstname(dto.firstname().trim());
        u.setLastname(dto.lastname().trim());
        u.setEmail(email);
        u.setPhone(dto.phone() != null ? dto.phone().trim() : null);
        u.setLogin(login);
        u.setPassword(passwordEncoder.encode(dto.password()));
        u.setEnabled(true);
        u.setEmployerPartner(employer);
        u.setCovoiturageSoloProfile(false);
        u.setCovoiturageKycStatus(CovoiturageKycStatus.NONE);
        u.setBalance(0.0);
        assignRoles(u, Set.of(UserRole.USER, UserRole.CHAUFFEUR));
        if (dto.stationId() != null) {
            Station st = stationRepository
                    .findByIdAndPartnerId(dto.stationId(), employer.getId())
                    .orElseThrow(() -> new MobiliException(
                            MobiliErrorCode.RESOURCE_NOT_FOUND,
                            "Gare inconnue ou ne dépend pas de cette compagnie."));
            u.setChauffeurAffiliationStation(st);

        }
        if (avatar != null && !avatar.isEmpty()) {
            String path = uploadService.saveImage(avatar, "users");
            u.setAvatarUrl(path);
        }
        return userRepository.save(u);
    }

    /**
     * Rattachement chauffeur / salarié à une fiche compagnie (hors covo. solo).
     * {@code null} = retirer.
     */
    public void setEmployerPartnerForUser(Long userId, Long partnerIdOrNull) {
        User u = findById(userId);
        if (Boolean.TRUE.equals(u.getCovoiturageSoloProfile())) {
            throw new MobiliException(
                    MobiliErrorCode.VALIDATION_ERROR,
                    "Compte covoiturage particulier : pas de société employeuse (piscine Mobili).");
        }
        if (partnerIdOrNull == null) {
            u.setEmployerPartner(null);
        } else {
            Partner p = partnerRepository.findById(partnerIdOrNull)
                    .orElseThrow(
                            () -> new MobiliException(
                                    MobiliErrorCode.RESOURCE_NOT_FOUND,
                                    "Partenaire introuvable (ID " + partnerIdOrNull + ")"));
            if (p.isCovoiturageSoloPool()) {
                throw new MobiliException(
                        MobiliErrorCode.VALIDATION_ERROR,
                        "Sélectionnez une compagnie de transport, pas le partenaire piscine covoiturage.");
            }
            u.setEmployerPartner(p);
        }
        userRepository.save(u);
    }

    private void assignRoles(User user, Set<UserRole> roleNames) {
        Set<Role> roles = roleNames.stream()
                .map(name -> roleRepository.findByName(name)
                        .orElseThrow(() -> new MobiliException(
                                MobiliErrorCode.RESOURCE_NOT_FOUND, "Rôle " + name + " inexistant")))
                .collect(Collectors.toSet());
        user.setRoles(roles);
    }

    /**
     * Recto / verso pièce d’identité : JPEG/PNG/WebP ou PDF — dossier sensible
     * {@link UploadService#FOLDER_SENSITIVE_COVOITURAGE_IDS}.
     */
    private String saveCarpoolIdentityScan(MultipartFile file) {
        if (looksLikePdfUpload(file)) {
            return uploadService.saveDocument(file, UploadService.FOLDER_SENSITIVE_COVOITURAGE_IDS);
        }
        return uploadService.saveImage(file, UploadService.FOLDER_SENSITIVE_COVOITURAGE_IDS);
    }

    private static boolean looksLikePdfUpload(MultipartFile file) {
        String ct = file.getContentType();
        if (ct != null && ct.toLowerCase(Locale.ROOT).contains("pdf")) {
            return true;
        }
        String name = file.getOriginalFilename();
        return name != null && name.toLowerCase(Locale.ROOT).endsWith(".pdf");
    }

    @Transactional
    public User findByLogin(String login) {
        return userRepository.findByLogin(login)
                .orElseThrow(() -> new MobiliException(
                        MobiliErrorCode.RESOURCE_NOT_FOUND,
                        "Utilisateur avec le login " + login + " introuvable."));
    }

}