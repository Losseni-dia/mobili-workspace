package com.mobili.backend.shared.sharedService;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class UploadService {

    @Value("${mobili.backend.upload.root-directory}")
    private String rootDirectory;

    @Value("${mobili.backend.upload.users}")
    private String usersFolder;

    public String saveImage(MultipartFile file, String folder) {
        try {
            // Utilise le dossier parent .uploads
            Path rootPath = Paths.get(rootDirectory);
            Path targetDir = rootPath.resolve(folder);

            if (!Files.exists(targetDir)) {
                Files.createDirectories(targetDir);
            }

            String original = file.getOriginalFilename();
            String base = original == null || original.isBlank()
                    ? "file"
                    : original.replace("\\", "/");
            int slash = base.lastIndexOf('/');
            if (slash >= 0) {
                base = base.substring(slash + 1);
            }
            base = base.replaceAll("[^a-zA-Z0-9._-]", "_");
            if (base.isBlank()) {
                base = "file";
            }
            String filename = UUID.randomUUID() + "_" + base;
            Path dest = targetDir.resolve(filename).normalize();
            if (!dest.startsWith(targetDir.normalize())) {
                throw new IOException("Chemin de fichier refusé");
            }
            Files.copy(file.getInputStream(), dest);

            // Retourne "users/image.jpg" pour la base de données
            return folder + "/" + filename;
        } catch (IOException e) {
            throw new RuntimeException("Erreur de stockage dans le dossier " + folder, e);
        }
    }
}