package com.mobili.backend.api.passenger.inbox;

import com.mobili.backend.module.notification.dto.InboxNotificationResponseDTO;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/inbox")
@RequiredArgsConstructor
public class InboxNotificationController {

    private final InboxNotificationService inboxNotificationService;

    @GetMapping("/notifications")
    public Page<InboxNotificationResponseDTO> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") @Min(1) int size,
            org.springframework.security.core.Authentication authentication) {
        return inboxNotificationService.listForUser(authentication.getPrincipal(),
                PageRequest.of(page, size, Sort.by("createdAt").descending()));
    }

    @GetMapping("/notifications/unread-count")
    public Map<String, Long> unreadCount(org.springframework.security.core.Authentication authentication) {
        return Map.of("count", inboxNotificationService.countUnread(authentication.getPrincipal()));
    }

    @PatchMapping("/notifications/{id}/read")
    public void markRead(
            @PathVariable Long id,
            org.springframework.security.core.Authentication authentication) {
        inboxNotificationService.markRead(id, authentication.getPrincipal());
    }

    @PatchMapping("/notifications/read-all")
    public Map<String, Integer> markAllRead(org.springframework.security.core.Authentication authentication) {
        return Map.of("updated", inboxNotificationService.markAllRead(authentication.getPrincipal()));
    }

    @PatchMapping("/notifications/mark-all-seen")
    public Map<String, Integer> markAllSeen(org.springframework.security.core.Authentication authentication) {
        return Map.of("updated", inboxNotificationService.markAllSeen(authentication.getPrincipal()));
    }

    @DeleteMapping("/notifications/{id}")
    public ResponseEntity<Void> delete(
            @PathVariable Long id,
            org.springframework.security.core.Authentication authentication) {
        inboxNotificationService.delete(id, authentication.getPrincipal());
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/notifications")
    public ResponseEntity<Void> deleteAll(
            org.springframework.security.core.Authentication authentication) {
        inboxNotificationService.deleteAll(authentication.getPrincipal());
        return ResponseEntity.noContent().build();
    }
}