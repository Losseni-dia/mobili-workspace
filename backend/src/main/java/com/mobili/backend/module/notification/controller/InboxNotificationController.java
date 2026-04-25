package com.mobili.backend.module.notification.controller;

import com.mobili.backend.infrastructure.security.authentication.UserPrincipal;
import com.mobili.backend.module.notification.dto.InboxNotificationResponseDTO;
import com.mobili.backend.module.notification.service.InboxNotificationService;
import jakarta.validation.constraints.Min;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/v1/inbox")
@RequiredArgsConstructor
public class InboxNotificationController {

    private final InboxNotificationService inboxNotificationService;

    @GetMapping("/notifications")
    public Page<InboxNotificationResponseDTO> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") @Min(1) int size,
            @AuthenticationPrincipal UserPrincipal principal) {
        return inboxNotificationService.listForUser(principal,
                PageRequest.of(page, size, Sort.by("createdAt").descending()));
    }

    @GetMapping("/notifications/unread-count")
    public Map<String, Long> unreadCount(@AuthenticationPrincipal UserPrincipal principal) {
        return Map.of("count", inboxNotificationService.countUnread(principal));
    }

    @PatchMapping("/notifications/{id}/read")
    public void markRead(
            @PathVariable Long id,
            @AuthenticationPrincipal UserPrincipal principal) {
        inboxNotificationService.markRead(id, principal);
    }

    @PatchMapping("/notifications/read-all")
    public Map<String, Integer> markAllRead(@AuthenticationPrincipal UserPrincipal principal) {
        return Map.of("updated", inboxNotificationService.markAllRead(principal));
    }
}
