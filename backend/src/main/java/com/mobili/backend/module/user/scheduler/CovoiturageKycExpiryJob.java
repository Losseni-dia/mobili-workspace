package com.mobili.backend.module.user.scheduler;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.List;

import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.module.notification.entity.MobiliNotificationType;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.role.CovoiturageKycStatus;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Vérifie quotidiennement la date de fin de validité CNI des chauffeurs covoiturage : alerte à 30 jours
 * (chauffeur + admins) puis passage {@link CovoiturageKycStatus#EXPIRED} le jour suivant la fin.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class CovoiturageKycExpiryJob {

    private static final DateTimeFormatter FR = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final UserRepository userRepository;
    private final InboxNotificationService inboxNotificationService;

    @Scheduled(cron = "0 0 7 * * *")
    @Transactional
    public void runDaily() {
        LocalDate today = LocalDate.now();
        List<User> chauffeurs = userRepository.findUsersWithChauffeurRole();
        for (User u : chauffeurs) {
            LocalDate end = u.getCovoiturageIdValidUntil();
            if (end == null) {
                continue;
            }
            CovoiturageKycStatus st = u.getCovoiturageKycStatus();
            if (st != CovoiturageKycStatus.APPROVED) {
                continue;
            }
            long days = ChronoUnit.DAYS.between(today, end);
            if (days < 0) {
                if (!Boolean.TRUE.equals(u.getCovoiturageKycExpiredNotified())) {
                    u.setCovoiturageKycStatus(CovoiturageKycStatus.EXPIRED);
                    u.setCovoiturageKycExpiredNotified(true);
                    userRepository.save(u);
                    String name = fullName(u);
                    inboxNotificationService.notifyCovoiturageKycExpired(u, end);
                    inboxNotificationService.notifyAdmins(
                            "CNI expirée (covoiturage)",
                            "Le chauffeur " + name + " (id " + u.getId() + ") : pièce d'identité expirée le "
                                    + end.format(FR) + ".",
                            MobiliNotificationType.COV_KYC_EXPIRED);
                    log.info("Covoiturage KYC expiré — userId={} fin={}", u.getId(), end);
                }
                continue;
            }
            if (days >= 1 && days <= 30) {
                if (u.getCovoiturageKycExpiringNotifiedFor() == null
                        || !u.getCovoiturageKycExpiringNotifiedFor().equals(end)) {
                    u.setCovoiturageKycExpiringNotifiedFor(end);
                    userRepository.save(u);
                    String name = fullName(u);
                    inboxNotificationService.notifyCovoiturageKycExpiringSoon(u, end);
                    inboxNotificationService.notifyAdmins(
                            "CNI covoiturage : expiration dans moins d'un mois",
                            "Chauffeur " + name + " (id " + u.getId() + ") — fin de validité le " + end.format(FR)
                                    + " (" + days + " jour(s)).",
                            MobiliNotificationType.COV_KYC_EXPIRING_SOON);
                    log.info("Alerte CNI covoiturage 30j — userId={} jours={} fin={}", u.getId(), days, end);
                }
            }
        }
    }

    private static String fullName(User u) {
        String a = u.getFirstname() == null ? "" : u.getFirstname().trim();
        String b = u.getLastname() == null ? "" : u.getLastname().trim();
        String n = (a + " " + b).trim();
        return n.isEmpty() ? u.getLogin() : n;
    }
}
