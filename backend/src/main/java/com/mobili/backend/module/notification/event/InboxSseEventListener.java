package com.mobili.backend.module.notification.event;

import com.mobili.backend.module.notification.service.InboxSseService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

@Component
@RequiredArgsConstructor
public class InboxSseEventListener {

    private final InboxSseService inboxSseService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onInboxRefresh(InboxRefreshEvent event) {
        inboxSseService.broadcastRefresh(event.userIds());
    }
}
