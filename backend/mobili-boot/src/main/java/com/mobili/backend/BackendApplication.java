package com.mobili.backend;

import com.mobili.backend.infrastructure.configuration.MobiliCorsSettings;
import com.mobili.backend.infrastructure.configuration.MobiliDotenvBootstrap;
import com.mobili.backend.infrastructure.configuration.MobiliRateLimitProperties;
import com.mobili.backend.infrastructure.configuration.MobiliSecurityRefreshSettings;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.data.web.config.EnableSpringDataWebSupport;
import org.springframework.scheduling.annotation.EnableScheduling;

import java.io.File;
import java.io.FileOutputStream;
import java.io.PrintStream;

@SpringBootApplication
@EnableScheduling
@EnableSpringDataWebSupport(pageSerializationMode = EnableSpringDataWebSupport.PageSerializationMode.VIA_DTO)
@EnableConfigurationProperties({
		MobiliCorsSettings.class,
		MobiliSecurityRefreshSettings.class,
		MobiliRateLimitProperties.class,
})
public class BackendApplication {
	public static void main(String[] args) {
		// Isole les System.out.println non maîtrisés du SDK FedaPay (données de
		// paiement sensibles) vers un fichier à accès restreint, sans toucher
		// au reste des logs applicatifs normaux (Logback continue vers journalctl).
		redirectSensitivePaymentOutput();

		// 1–2 .env → System properties (voir MobiliDotenvBootstrap)
		MobiliDotenvBootstrap.loadIntoSystemProperties();
		// 3. Lancer l'application normalement
		SpringApplication.run(BackendApplication.class, args);
	}

	private static void redirectSensitivePaymentOutput() {
		try {
			File sensitiveLog = new File("/home/ec2-user/fedapay-debug.log");
			PrintStream sensitiveOut = new PrintStream(new FileOutputStream(sensitiveLog, true), true);
			PrintStream originalOut = System.out;

			System.setOut(new PrintStream(originalOut) {
				@Override
				public void println(String x) {
					if (x != null && (x.contains("payment_token")
							|| x.contains("v1/transaction")
							|| x.contains("receipt_url"))) {
						sensitiveOut.println(x);
					} else {
						super.println(x);
					}
				}
			});
		} catch (Exception e) {
			// Échec silencieux : on garde le comportement par défaut plutôt
			// que de bloquer le démarrage de l'application pour ça.
		}
	}
}