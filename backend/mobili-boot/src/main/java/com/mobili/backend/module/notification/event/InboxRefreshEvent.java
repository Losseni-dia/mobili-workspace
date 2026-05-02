package com.mobili.backend.module.notification.event;

import java.util.Set;

/**
 * Publié après persistance ; le push temps réel est émis après commit (voir
 * {@link com.mobili.backend.module.notification.event.InboxSseEventListener}).
 */
public record InboxRefreshEvent(Set<Long> userIds) {}
