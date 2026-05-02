package com.mobili.backend.infrastructure.configuration;

import io.github.cdimascio.dotenv.Dotenv;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/** Charge le fichier {@code .env} (racine projet ou dossiers parents), comme les outils Maven / IDE. */
public final class MobiliDotenvBootstrap {

	private MobiliDotenvBootstrap() {
	}

	public static void loadIntoSystemProperties() {
		Path cwd = Paths.get(System.getProperty("user.dir")).toAbsolutePath().normalize();
		Path probe = cwd;
		int depth = 0;
		while (!Files.isRegularFile(probe.resolve(".env")) && probe.getParent() != null && depth < 6) {
			probe = probe.getParent().normalize();
			depth++;
		}
		Path loadDir = Files.isRegularFile(probe.resolve(".env")) ? probe : cwd;
		Dotenv dotenv = Dotenv.configure().directory(loadDir.toString()).ignoreIfMissing().load();
		dotenv.entries().forEach(entry -> System.setProperty(entry.getKey(), entry.getValue()));
	}
}
