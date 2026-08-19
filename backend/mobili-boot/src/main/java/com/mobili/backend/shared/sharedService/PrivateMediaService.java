package com.mobili.backend.shared.sharedService;

import java.io.IOException;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.admincom.repository.AdminComMessageRepository;
import com.mobili.backend.module.claim.repository.ClaimRepository;
import com.mobili.backend.module.partner.entity.Partner;
import com.mobili.backend.module.partner.repository.PartnerRepository;
import com.mobili.backend.module.trip.repository.TripRepository;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;

/**
 * Résolution et contrôle d’accès des fichiers sensibles (KYC covoiturage, etc.) hors exposition statique.
 */
@Service
public class PrivateMediaService {

    private final UserRepository userRepository;
    private final TripRepository tripRepository;
    private final ClaimRepository claimRepository;
    private final AdminComMessageRepository adminComMessageRepository;
    private final PartnerRepository partnerRepository;

    @Value("${mobili.backend.upload.root-directory}")
    private String rootDirectory;

    /**
     * Dossier PDF / pièces hors arborescence {@code sensitive/…} — pas de diffusion
     * statique publique.
     */
    @Value("${mobili.backend.upload.documents-folder:documents}")
    private String documentsFolder;

    public PrivateMediaService(UserRepository userRepository,
            com.mobili.backend.module.trip.repository.TripRepository tripRepository,
            ClaimRepository claimRepository,
            AdminComMessageRepository adminComMessageRepository,
            PartnerRepository partnerRepository) {
        this.userRepository = userRepository;
        this.tripRepository = tripRepository;
        this.claimRepository = claimRepository;
        this.adminComMessageRepository = adminComMessageRepository;
        this.partnerRepository = partnerRepository;
    }

    /**
     * Retourne le chemin absolu si le fichier existe et que {@code principal} peut le lire ; sinon exception HTTP métier.
     */
    @Transactional(readOnly = true)
    public Path requireReadableFile(UserPrincipal principal, String relQueryParam) {
        String decoded = URLDecoder.decode(relQueryParam == null ? "" : relQueryParam, StandardCharsets.UTF_8);
        String relative = sanitizeRelativePath(decoded);
        if (relative.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Paramètre rel invalide.");
        }
        if (!isSensitiveRelativePath(relative)) {
            throw new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Fichier introuvable.");
        }

        Path rootPath = Paths.get(rootDirectory).toAbsolutePath().normalize();
        Path file = resolveUnderRoot(rootPath, relative);
        if (!mayAccess(principal, relative)) {
            throw new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Fichier introuvable.");
        }
        if (!Files.isRegularFile(file)) {
            throw new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Fichier introuvable.");
        }
        return file;
    }

    private boolean matchesNormalized(String relative, String storedField) {
        if (storedField == null || storedField.isBlank()) {
            return false;
        }
        try {
            String n = sanitizeRelativePath(storedField);
            return !n.isEmpty() && n.equals(relative);
        } catch (MobiliException e) {
            return false;
        }
    }

    private static String sanitizeRelativePath(String raw) {
        String r = raw.trim().replace('\\', '/');
        while (r.startsWith("/")) {
            r = r.substring(1);
        }
        if (r.isBlank()) {
            return "";
        }
        List<String> parts = new ArrayList<>();
        for (String seg : r.split("/")) {
            if (seg.isEmpty() || ".".equals(seg)) {
                continue;
            }
            if ("..".equals(seg)) {
                throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Chemin relatif invalide.");
            }
            parts.add(seg);
        }
        if (parts.isEmpty()) {
            return "";
        }
        return String.join("/", parts);
    }

    /**
     * Préfixes autorisés : {@code sensitive/}, anciens chemins KYC, dossier configuré des PDF ({@code mobili.backend.upload.documents-folder}).
     */
    private boolean isSensitiveRelativePath(String relative) {
        return relative.startsWith("sensitive/")
                || relative.startsWith("covoiturage-ids/")
                || relative.startsWith("covoiturage-drivers/")
                || relative.startsWith("covoiturage-vehicles/")
                || relative.startsWith(documentsFolderPrefix());
    }

    /** Premier segment du dossier documents (aligné sur la config YAML). */
    private String documentsFolderPrefix() {
        String base = documentsFolder == null ? "" : documentsFolder.trim().replace('\\', '/');
        base = base.replaceAll("^/+", "");
        int slash = base.indexOf('/');
        if (slash >= 0) {
            base = base.substring(0, slash);
        }
        if (base.isBlank()) {
            base = "documents";
        }
        return base + "/";
    }

    private static Path resolveUnderRoot(Path rootPath, String relative) {
        Path cursor = rootPath;
        for (String seg : relative.split("/")) {
            if (seg.isEmpty()) {
                continue;
            }
            cursor = cursor.resolve(seg);
        }
        Path normalized = cursor.normalize();
        if (!normalized.startsWith(rootPath)) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Chemin hors répertoire d’upload.");
        }
        return normalized;
    }

    private boolean mayAccess(UserPrincipal principal, String relative) {
        if (principal == null) {
            return false;
        }
        if (isAdmin(principal)) {
            return true;
        }
        User u = userRepository.findById(principal.getUser().getId()).orElse(null);
        if (u == null) {
            return false;
        }
        // Preuves jointes réclamations : uniquement le propriétaire de la réclamation (ou admin, déjà géré ci-dessus).
        if (relative.startsWith(UploadService.FOLDER_SENSITIVE_CLAIM_ATTACHMENTS + "/")) {
            return claimRepository.existsByAttachmentPathAndUser_Id(relative, u.getId());
        }
        // Preuves jointes support/admin-com : les deux participants du fil (admin déjà géré ci-dessus).
        if (relative.startsWith(UploadService.FOLDER_SENSITIVE_SUPPORT_ATTACHMENTS + "/")) {
            return adminComMessageRepository.existsAccessibleAttachment(relative, u.getId());
        }
        if (matchesNormalized(relative, u.getCovoiturageIdFrontUrl())
                || matchesNormalized(relative, u.getCovoiturageIdBackUrl())
                || matchesNormalized(relative, u.getCovoiturageDriverPhotoUrl())
                || matchesNormalized(relative, u.getCovoiturageVehiclePhotoUrl())
                || matchesNormalized(relative, u.getCovoiturageLicenseFrontUrl())
                || matchesNormalized(relative, u.getCovoiturageLicenseBackUrl())
                || matchesNormalized(relative, u.getCovoiturageGreyCardFrontUrl())
                || matchesNormalized(relative, u.getCovoiturageGreyCardBackUrl())) {
            return true;
        }
        // Documents chauffeur société (CNI + permis) : le chauffeur lui-même, ou toute personne
        // de la même société (dirigeant propriétaire, ou gare/employé rattaché à cette société —
        // même périmètre que qui peut créer/gérer ce chauffeur, voir PartnerChauffeurController).
        if (relative.startsWith(UploadService.FOLDER_SENSITIVE_CHAUFFEUR_IDS + "/")
                || relative.startsWith(UploadService.FOLDER_SENSITIVE_CHAUFFEUR_LICENSE + "/")) {
            return mayAccessChauffeurDocument(u, relative);
        }
        // Carte de transporteur société : le dirigeant propriétaire ou un employé (gare) de la
        // même société.
        if (relative.startsWith(UploadService.FOLDER_SENSITIVE_PARTNER_LEGAL + "/")) {
            return mayAccessPartnerLegalDocument(u, relative);
        }
        // Tout utilisateur authentifié peut voir la photo du CONDUCTEUR (pas la
        // CNI) d'un trajet covoiturage publié — même logique d'ouverture que la
        // photo du véhicule, déjà publique sur la carte du trajet. Ça permet à
        // un passager de voir qui va le conduire avant de réserver.
        return isDriverPhotoOfAnyCovoiturageTrip(relative);
    }

    private boolean mayAccessChauffeurDocument(User principalUser, String relative) {
        User chauffeur = userRepository.findByChauffeurDocumentPath(relative).orElse(null);
        if (chauffeur == null) {
            return false;
        }
        if (chauffeur.getId().equals(principalUser.getId())) {
            return true;
        }
        Long chauffeurPartnerId = chauffeur.getEmployerPartner() != null
                ? chauffeur.getEmployerPartner().getId()
                : null;
        if (chauffeurPartnerId == null) {
            return false;
        }
        return chauffeurPartnerId.equals(samePartnerCompanyId(principalUser));
    }

    private boolean mayAccessPartnerLegalDocument(User principalUser, String relative) {
        Partner partner = partnerRepository.findByTransportCardPath(relative).orElse(null);
        if (partner == null) {
            return false;
        }
        return partner.getId().equals(samePartnerCompanyId(principalUser));
    }

    /** ID de la société (dirigeant propriétaire, ou société employeuse si gare/employé) — {@code null} sinon. */
    private Long samePartnerCompanyId(User u) {
        if (u.getPartner() != null) {
            return u.getPartner().getId();
        }
        if (u.getEmployerPartner() != null) {
            return u.getEmployerPartner().getId();
        }
        return null;
    }

    private boolean isDriverPhotoOfAnyCovoiturageTrip(String relative) {
        return tripRepository.existsByCovoiturageOrganizerCovoiturageDriverPhotoUrl(relative);
    }

    private static boolean isAdmin(UserPrincipal principal) {
        return principal.getAuthorities().stream().anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));
    }

    public static String probeContentType(Path file) {
        try {
            String ct = Files.probeContentType(file);
            if (ct != null && !ct.isBlank()) {
                return ct;
            }
        } catch (IOException ignored) {
            // fallback below
        }
        String name = file.getFileName().toString().toLowerCase();
        if (name.endsWith(".png")) {
            return "image/png";
        }
        if (name.endsWith(".jpg") || name.endsWith(".jpeg")) {
            return "image/jpeg";
        }
        if (name.endsWith(".webp")) {
            return "image/webp";
        }
        if (name.endsWith(".pdf")) {
            return "application/pdf";
        }
        return "application/octet-stream";
    }
}
