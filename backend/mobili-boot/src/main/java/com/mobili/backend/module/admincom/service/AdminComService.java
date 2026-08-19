package com.mobili.backend.module.admincom.service;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.admincom.dto.AdminComMessageDTO;
import com.mobili.backend.module.admincom.dto.AdminComThreadDTO;
import com.mobili.backend.module.admincom.dto.CreateAdminComThreadRequest;
import com.mobili.backend.module.admincom.dto.PostAdminComMessageRequest;
import com.mobili.backend.module.admincom.entity.AdminComMessage;
import com.mobili.backend.module.admincom.entity.AdminComThread;
import com.mobili.backend.module.admincom.entity.AdminComType;
import com.mobili.backend.module.admincom.repository.AdminComMessageRepository;
import com.mobili.backend.module.admincom.repository.AdminComThreadRepository;
import com.mobili.backend.module.notification.entity.MobiliNotificationType;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import com.mobili.backend.module.user.entity.User;
import com.mobili.backend.module.user.repository.UserRepository;
import com.mobili.backend.module.user.service.UserService;
import com.mobili.backend.shared.mobiliError.exception.MobiliErrorCode;
import com.mobili.backend.shared.mobiliError.exception.MobiliException;
import com.mobili.backend.shared.sharedService.UploadService;

import lombok.RequiredArgsConstructor;

import org.springframework.web.multipart.MultipartFile;

@Service
@RequiredArgsConstructor
public class AdminComService {

    private static final DateTimeFormatter FR = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

    private final AdminComThreadRepository threadRepository;
    private final AdminComMessageRepository messageRepository;
    private final UserService userService;
    private final UserRepository userRepository;
    private final InboxNotificationService inboxNotificationService;
    private final UploadService uploadService;

    @Transactional
    public AdminComThreadDTO createThread(CreateAdminComThreadRequest req, UserPrincipal principal) {
        User caller = principal.getUser();
        boolean callerIsAdmin = caller.getRoles().stream()
                .anyMatch(r -> r.getName() == com.mobili.backend.module.user.role.UserRole.ADMIN);

        User admin;
        User partnerUser;

        if (callerIsAdmin) {
            // Admin crée le thread vers un partenaire/chauffeur/client
            admin = caller;
            partnerUser = userService.findById(req.getPartnerUserId());
        } else {
            // Client/partenaire/chauffeur crée une demande support
            partnerUser = caller;
            // Trouver le premier admin disponible
            admin = userService.findFirstAdmin()
                    .orElseThrow(() -> new MobiliException(
                            MobiliErrorCode.RESOURCE_NOT_FOUND, "Aucun admin disponible"));
        }

        // Déduire le type automatiquement si non fourni
        AdminComType type = resolveType(req.getType(), partnerUser);

        AdminComThread thread = new AdminComThread();
        thread.setSubject(req.getSubject().trim());
        thread.setType(type);
        thread.setAdminUser(admin);
        thread.setPartnerUser(partnerUser);
        thread.setLastActivityAt(LocalDateTime.now());
        thread = threadRepository.save(thread);

        AdminComMessage first = new AdminComMessage();
        first.setThread(thread);
        first.setAuthor(caller); // auteur = celui qui crée (admin ou client)
        first.setBody(req.getFirstMessage().trim());
        messageRepository.save(first);

        thread.setLastActivityAt(first.getCreatedAt() != null ? first.getCreatedAt() : LocalDateTime.now());
        threadRepository.save(thread);

        // Notifier le destinataire
        String preview = req.getFirstMessage().length() > 200
                ? req.getFirstMessage().substring(0, 197) + "…"
                : req.getFirstMessage();
        // Notifier le bon destinataire
        User recipient = callerIsAdmin ? partnerUser : admin;
        inboxNotificationService.notifyUser(
                recipient,
                callerIsAdmin
                        ? "Message de l'équipe Mobili : " + req.getSubject()
                        : "Nouvelle demande support : " + req.getSubject(),
                preview,
                MobiliNotificationType.MOBILI_ADMIN_INFO_PARTNER);

        // Message automatique d'accusé de réception si c'est un client qui ouvre le
        // ticket
        if (!callerIsAdmin) {
            AdminComMessage autoReply = new AdminComMessage();
            autoReply.setThread(thread);
            autoReply.setAuthor(admin);
            autoReply.setBody(
                    "Bonjour " + partnerUser.getFirstname() + " 👋\n\n" +
                            "Merci pour votre message. Notre équipe support a bien reçu votre demande concernant : \""
                            + req.getSubject() + "\".\n\n" +
                            "Un agent Mobili vous répondra dans les meilleurs délais (généralement sous 24h ouvrées).\n\n"
                            +
                            "L'équipe Mobili 🚌");
            messageRepository.save(autoReply);
            thread.setLastActivityAt(
                    autoReply.getCreatedAt() != null ? autoReply.getCreatedAt() : LocalDateTime.now());
            threadRepository.save(thread);

            // Notifier le client de l'accusé de réception
            inboxNotificationService.notifyUser(
                    partnerUser,
                    "✅ Demande reçue — " + req.getSubject(),
                    "Notre équipe support a bien reçu votre demande et vous répondra sous 24h.",
                    MobiliNotificationType.MOBILI_ADMIN_INFO_PARTNER);
        }

        return toDto(thread);

    }

    @Transactional(readOnly = true)
    public List<AdminComThreadDTO> listThreads(UserPrincipal principal) {
        return threadRepository.findAllForUser(principal.getUser().getId())
                .stream().map(this::toDto).toList();
    }

    @Transactional(readOnly = true)
    public List<AdminComMessageDTO> listMessages(Long threadId, UserPrincipal principal) {
        AdminComThread thread = getThreadForUser(threadId, principal);
        return messageRepository.findByThread_IdOrderByCreatedAtAsc(thread.getId())
                .stream().map(this::toMessageDto).toList();
    }

    @Transactional
    public AdminComMessageDTO postMessage(Long threadId, PostAdminComMessageRequest req, UserPrincipal principal) {
        AdminComThread thread = getThreadForUser(threadId, principal);
        User author = principal.getUser();

        AdminComMessage msg = new AdminComMessage();
        msg.setThread(thread);
        msg.setAuthor(author);
        msg.setBody(req.getBody().trim());
        msg = messageRepository.save(msg);

        thread.setLastActivityAt(msg.getCreatedAt() != null ? msg.getCreatedAt() : LocalDateTime.now());
        threadRepository.save(thread);

        // Notifier l'autre participant
        User recipient = thread.getAdminUser().getId().equals(author.getId())
                ? thread.getPartnerUser()
                : thread.getAdminUser();

        String who = fullName(author);
        String preview = req.getBody().length() > 200 ? req.getBody().substring(0, 197) + "…" : req.getBody();

        inboxNotificationService.notifyUser(
                recipient,
                who + " : " + thread.getSubject(),
                preview,
                MobiliNotificationType.MOBILI_ADMIN_INFO_PARTNER);

        return toMessageDto(msg);
    }

    // Variante avec pièce jointe : le corps texte devient optionnel (un message peut n'être
    // qu'une preuve jointe) — même logique de notification que postMessage, factorisée via
    // buildAndSaveMessage.
    @Transactional
    public AdminComMessageDTO postMessageWithAttachment(Long threadId, String body, MultipartFile file,
            UserPrincipal principal) {
        AdminComThread thread = getThreadForUser(threadId, principal);
        User author = principal.getUser();

        String path = uploadService.saveAttachment(file, UploadService.FOLDER_SENSITIVE_SUPPORT_ATTACHMENTS);

        AdminComMessage msg = new AdminComMessage();
        msg.setThread(thread);
        msg.setAuthor(author);
        msg.setBody(body != null && !body.isBlank() ? body.trim() : "📎 Pièce jointe");
        msg.setAttachmentPath(path);
        msg.setAttachmentOriginalName(file.getOriginalFilename());
        msg.setAttachmentContentType(file.getContentType());
        msg = messageRepository.save(msg);

        thread.setLastActivityAt(msg.getCreatedAt() != null ? msg.getCreatedAt() : LocalDateTime.now());
        threadRepository.save(thread);

        User recipient = thread.getAdminUser().getId().equals(author.getId())
                ? thread.getPartnerUser()
                : thread.getAdminUser();
        inboxNotificationService.notifyUser(
                recipient,
                fullName(author) + " : " + thread.getSubject(),
                "📎 A envoyé une pièce jointe",
                MobiliNotificationType.MOBILI_ADMIN_INFO_PARTNER);

        return toMessageDto(msg);
    }

    // ─── Résolution du type ───────────────────────────────────────────────────

    private AdminComType resolveType(String rawType, User user) {
        if (rawType != null && !rawType.isBlank()) {
            try {
                return AdminComType.valueOf(rawType.toUpperCase());
            } catch (IllegalArgumentException ignored) {
            }
        }
        // Déduction automatique
        if (Boolean.TRUE.equals(user.getCovoiturageSoloProfile()))
            return AdminComType.COVOITURAGE;
        if (user.getPartner() != null || user.getEmployerPartner() != null)
            return AdminComType.PARTNER;
        return AdminComType.SUPPORT;
    }

    // ─── Accès sécurisé ──────────────────────────────────────────────────────

    private AdminComThread getThreadForUser(Long threadId, UserPrincipal principal) {
        AdminComThread thread = threadRepository.findById(threadId)
                .orElseThrow(() -> new MobiliException(MobiliErrorCode.RESOURCE_NOT_FOUND, "Fil introuvable"));
        Long userId = principal.getUser().getId();
        if (!thread.getAdminUser().getId().equals(userId) && !thread.getPartnerUser().getId().equals(userId)) {
            throw new MobiliException(MobiliErrorCode.ACCESS_DENIED, "Accès refusé");
        }
        return thread;
    }

    // ─── Mapping DTO ─────────────────────────────────────────────────────────

    private AdminComThreadDTO toDto(AdminComThread t) {
        User a = t.getAdminUser();
        User p = t.getPartnerUser();

        String partnerName = fullName(p);
        String companyName = resolveCompanyName(p);
        String displayLabel = buildDisplayLabel(t.getType(), partnerName, companyName);

        return new AdminComThreadDTO(
                t.getId(),
                t.getSubject(),
                t.getType().name(),
                a.getId(),
                fullName(a),
                p.getId(),
                partnerName,
                companyName,
                displayLabel,
                t.getLastActivityAt(),
                t.getLastActivityAt() != null ? t.getLastActivityAt().format(FR) : "");
    }

    private AdminComMessageDTO toMessageDto(AdminComMessage m) {
        return new AdminComMessageDTO(
                m.getId(),
                m.getAuthor().getId(),
                fullName(m.getAuthor()),
                m.getBody(),
                m.getCreatedAt(),
                m.getCreatedAt() != null ? m.getCreatedAt().format(FR) : "",
                m.getAttachmentPath(),
                m.getAttachmentOriginalName(),
                m.getAttachmentContentType());
    }

    private String resolveCompanyName(User u) {
        // Dirigeant propriétaire de la fiche partenaire
        if (u.getPartner() != null && !u.getPartner().isCovoiturageSoloPool()) {
            return u.getPartner().getName();
        }
        // Chauffeur/employé rattaché à une compagnie
        if (u.getEmployerPartner() != null && !u.getEmployerPartner().isCovoiturageSoloPool()) {
            return u.getEmployerPartner().getName();
        }
        return null;
    }

    private String buildDisplayLabel(AdminComType type, String partnerName, String companyName) {
        return switch (type) {
            case PARTNER -> companyName != null ? companyName + " — " + partnerName : partnerName;
            case COVOITURAGE -> partnerName; // juste le nom du chauffeur
            case SUPPORT -> partnerName; // juste le nom du client
        };
    }

    private String fullName(User u) {
        if (u == null)
            return "—";
        String n = ((u.getFirstname() != null ? u.getFirstname() : "") + " " +
                (u.getLastname() != null ? u.getLastname() : "")).trim();
        return n.isBlank() ? (u.getLogin() != null ? u.getLogin() : "—") : n;
    }

  
}