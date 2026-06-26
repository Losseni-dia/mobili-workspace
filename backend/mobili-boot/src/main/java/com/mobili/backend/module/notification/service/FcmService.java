package com.mobili.backend.module.notification.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class FcmService {

    public void sendToToken(String fcmToken, String title, String body) {
        if (fcmToken == null || fcmToken.isBlank())
            return;
        try {
            Message message = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(Notification.builder()
                            .setTitle(title)
                            .setBody(body)
                            .build())
                    .putData("click_action", "FLUTTER_NOTIFICATION_CLICK")
                    .build();
            String response = FirebaseMessaging.getInstance().send(message);
            log.info("[FCM] Envoyée token={}... response={}", fcmToken.substring(0, 10), response);
        } catch (Exception e) {
            log.warn("[FCM] Échec token={} error={}", fcmToken, e.getMessage());
        }
    }
}