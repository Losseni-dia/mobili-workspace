package com.mobili.backend.shared.sharedService;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Locale;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.mobili.backend.shared.MobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.MobiliError.exception.MobiliException;

/**
 * Stockage fichiers sous {@code mobili.backend.upload.root-directory}.
 * <p>
 * Les PDF ({@link #saveDocument}) ne doivent pas être mis dans des balises {@code <img>} ni rendus inline sans précaution :
 * exposer un téléchargement avec {@code Content-Disposition: attachment} et préférer des URLs contrôlées / signées.
 */
@Service
public class UploadService {

    /** KYC covoiturage — hors exposition statique {@code /uploads/**} publique. */
    public static final String FOLDER_SENSITIVE_COVOITURAGE_IDS = "sensitive/covoiturage/ids";

    public static final String FOLDER_SENSITIVE_COVOITURAGE_DRIVERS = "sensitive/covoiturage/drivers";

    public static final String FOLDER_SENSITIVE_COVOITURAGE_VEHICLES = "sensitive/covoiturage/vehicles";

    /**
     * Pièces légales partenaire (KBIS, etc.) — prévoir une colonne URL sur {@link com.mobili.backend.module.partner.entity.Partner}
     * et le même contrôle d’accès que les autres préfixes {@code sensitive/}.
     */
    public static final String FOLDER_SENSITIVE_PARTNER_LEGAL = "sensitive/partners/legal";

    @Value("${mobili.backend.upload.root-directory}")
    private String rootDirectory;

    /** Taille max par fichier image (octets). */
    @Value("${mobili.backend.upload.max-bytes-per-file:12582912}")
    private long maxBytesPerFile;

    /** Taille max par document PDF (octets). */
    @Value("${mobili.backend.upload.max-bytes-per-document:5242880}")
    private long maxBytesPerDocument;

    /** Dossier relatif par défaut pour les PDF (ex. {@code documents}). */
    @Value("${mobili.backend.upload.documents-folder:documents}")
    private String documentsFolderDefault;

    /**
     * Sous-dossier conseillé pour les pièces PDF — éviter de réutiliser les dossiers « images ».
     *
     * @see #saveDocument(MultipartFile, String)
     */
    public String documentsFolderDefault() {
        return documentsFolderDefault;
    }

    public String saveImage(MultipartFile file, String folder) {
        validateImage(file);
        return writeFile(file, folder, false);
    }

    /**
     * Enregistre un PDF : extension {@code .pdf}, signature {@code %PDF}, MIME {@code application/pdf} si fourni.
     * Stocké sous {@code folder} relatif au répertoire d’upload (utiliser typiquement {@link #documentsFolderDefault()}).
     */
    public String saveDocument(MultipartFile file, String folder) {
        validatePdf(file);
        return writeFile(file, folder, true);
    }

    private String writeFile(MultipartFile file, String folder, boolean forcePdfExtension) {
        try {
            Path rootPath = Paths.get(rootDirectory).toAbsolutePath().normalize();
            Path targetDir = rootPath.resolve(folder);

            if (!Files.exists(targetDir)) {
                Files.createDirectories(targetDir);
            }

            String original = file.getOriginalFilename();
            String base = original == null || original.isBlank() ? "document" : original.replace("\\", "/");
            int slash = base.lastIndexOf('/');
            if (slash >= 0) {
                base = base.substring(slash + 1);
            }
            base = base.replaceAll("[^a-zA-Z0-9._-]", "_");
            if (base.isBlank()) {
                base = forcePdfExtension ? "document" : "file";
            }
            if (forcePdfExtension) {
                int dot = base.lastIndexOf('.');
                String stem = dot > 0 ? base.substring(0, dot) : base;
                if (stem.isBlank()) {
                    stem = "document";
                }
                base = stem + ".pdf";
            }

            String filename = UUID.randomUUID() + "_" + base;
            Path dest = targetDir.resolve(filename).normalize();
            if (!dest.startsWith(targetDir.normalize())) {
                throw new IOException("Chemin de fichier refusé");
            }
            try (InputStream in = file.getInputStream()) {
                Files.copy(in, dest);
            }

            return folder + "/" + filename;
        } catch (IOException e) {
            throw new RuntimeException("Erreur de stockage dans le dossier " + folder, e);
        }
    }

    private void validateImage(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Fichier image vide.");
        }
        if (file.getSize() > maxBytesPerFile) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Fichier trop volumineux (max " + maxBytesPerFile / (1024 * 1024) + " Mo).");
        }
        String ct = file.getContentType();
        if (ct != null && !ct.isBlank()) {
            String lower = ct.toLowerCase(Locale.ROOT);
            if (!(lower.startsWith("image/jpeg") || lower.startsWith("image/jpg") || lower.equals("image/png")
                    || lower.equals("image/webp"))) {
                throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                        "Type MIME non autorisé (JPEG, PNG ou WebP uniquement).");
            }
        }
        byte[] sig;
        try (InputStream in = file.getInputStream()) {
            sig = in.readNBytes(16);
        } catch (IOException e) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Lecture du fichier impossible.");
        }
        if (!looksLikeAllowedImage(sig)) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Le fichier ne correspond pas à une image JPEG, PNG ou WebP.");
        }
    }

    private void validatePdf(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Fichier PDF vide.");
        }
        if (file.getSize() > maxBytesPerDocument) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "PDF trop volumineux (max " + maxBytesPerDocument / (1024 * 1024) + " Mo).");
        }
        String ct = file.getContentType();
        if (ct != null && !ct.isBlank()) {
            String lower = ct.toLowerCase(Locale.ROOT);
            if (!lower.contains("pdf")) {
                throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                        "Type MIME attendu : application/pdf.");
            }
        }
        String name = file.getOriginalFilename();
        if (name != null && !name.isBlank() && !name.toLowerCase(Locale.ROOT).endsWith(".pdf")) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Le fichier doit avoir l’extension .pdf.");
        }
        byte[] head;
        try (InputStream in = file.getInputStream()) {
            head = in.readNBytes(5);
        } catch (IOException e) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR, "Lecture du fichier impossible.");
        }
        if (!looksLikePdf(head)) {
            throw new MobiliException(MobiliErrorCode.VALIDATION_ERROR,
                    "Le fichier ne commence pas par la signature PDF attendue (%PDF).");
        }
    }

    private static boolean looksLikePdf(byte[] b) {
        return b.length >= 5 && b[0] == '%' && b[1] == 'P' && b[2] == 'D' && b[3] == 'F' && (b[4] == '-' || Character.isDigit(b[4]));
    }

    private static boolean looksLikeAllowedImage(byte[] b) {
        if (b.length < 8) {
            return false;
        }
        if (b[0] == (byte) 0xFF && b[1] == (byte) 0xD8 && b[2] == (byte) 0xFF) {
            return true;
        }
        if (b.length >= 8 && b[0] == (byte) 0x89 && b[1] == 'P' && b[2] == 'N' && b[3] == 'G' && b[4] == '\r' && b[5] == '\n'
                && b[6] == 0x1A && b[7] == '\n') {
            return true;
        }
        return b.length >= 12 && b[0] == 'R' && b[1] == 'I' && b[2] == 'F' && b[3] == 'F' && b[8] == 'W' && b[9] == 'E'
                && b[10] == 'B' && b[11] == 'P';
    }
}
