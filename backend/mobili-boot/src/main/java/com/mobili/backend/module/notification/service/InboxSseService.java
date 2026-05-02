package com.mobili.backend.module.notification.service;

import com.mobili.backend.module.notification.repository.MobiliInboxNotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

@Service
@RequiredArgsConstructor
@Slf4j
public class InboxSseService {

    private static final long SSE_TIMEOUT_MS = 3_600_000L;

    private final MobiliInboxNotificationRepository inboxRepository;

    private final Map<Long, CopyOnWriteArrayList<SseEmitter>> emittersByUser = new ConcurrentHashMap<>();

    public SseEmitter subscribe(Long userId) {
        SseEmitter emitter = new SseEmitter(SSE_TIMEOUT_MS);
        emittersByUser.computeIfAbsent(userId, k -> new CopyOnWriteArrayList<>()).add(emitter);

        Runnable remove = () -> removeEmitter(userId, emitter);
        emitter.onCompletion(remove);
        emitter.onTimeout(remove);
        emitter.onError(e -> remove.run());

        try {
            long unread = inboxRepository.countByUserIdAndReadAtIsNull(userId);
            emitter.send(SseEmitter.event()
                    .id("init")
                    .name("unread")
                    .data("{\"unread\":" + unread + "}", MediaType.APPLICATION_JSON));
        } catch (IOException e) {
            log.debug("SSE init failed for user {}: {}", userId, e.getMessage());
            remove.run();
            emitter.completeWithError(e);
        }
        return emitter;
    }

    /**
     * Notifie les clients connectés que la boîte a changé (après commit).
     */
    public void broadcastRefresh(Collection<Long> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return;
        }
        for (Long userId : userIds) {
            if (userId == null) {
                continue;
            }
            CopyOnWriteArrayList<SseEmitter> list = emittersByUser.get(userId);
            if (list == null || list.isEmpty()) {
                continue;
            }
            for (SseEmitter em : new ArrayList<>(list)) {
                try {
                    em.send(SseEmitter.event().name("refresh").data("{}", MediaType.APPLICATION_JSON));
                } catch (Exception ex) {
                    list.remove(em);
                    try {
                        em.completeWithError(ex);
                    } catch (Exception ignored) {
                        // ignore
                    }
                }
            }
        }
    }

    private void removeEmitter(Long userId, SseEmitter emitter) {
        CopyOnWriteArrayList<SseEmitter> list = emittersByUser.get(userId);
        if (list != null) {
            list.remove(emitter);
            if (list.isEmpty()) {
                emittersByUser.remove(userId);
            }
        }
    }
}
