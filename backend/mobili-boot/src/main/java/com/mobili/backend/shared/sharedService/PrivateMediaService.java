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
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

/**
 * Résolution et contrôle d’accès des fichiers sensibles (KYC covoiturage, etc.) hors exposition statique.
 */
@Service
public class PrivateMediaService {

    private final UserRepository userRepository;

    @Value("${mobili.backend.upload.root-directory}")
    private String rootDirectory;

    /** Dossier PDF / pièces hors arborescence {@code sensitive/…} — pas de diffusion statique publique. */
    @Value("${mobili.backend.upload.documents-folder:documents}")
    private String documentsFolder;

    public PrivateMediaService(UserRepository userRepository) {
        this.userRepository = userRepository;
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
        return matchesNormalized(relative, u.getCovoiturageIdFrontUrl())
                || matchesNormalized(relative, u.getCovoiturageIdBackUrl())
                || matchesNormalized(relative, u.getCovoiturageDriverPhotoUrl())
                || matchesNormalized(relative, u.getCovoiturageVehiclePhotoUrl());
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
