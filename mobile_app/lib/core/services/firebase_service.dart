import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobili/core/network/api_client.dart';

// Handler pour les messages en background (top-level function obligatoire)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Message background: ${message.notification?.title}');
}

class FirebaseService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'mobili_high_importance',
    'Notifications Mobili',
    description: 'Notifications importantes de Mobili',
    importance: Importance.high,
  );

  /// Initialise Firebase + FCM + notifications locales
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> initialize() async {
    await Firebase.initializeApp();

    // Tout ce qui suit dépend de Firebase Cloud Messaging, un service tiers
    // qui peut échouer (réseau, config manquante, quota...). On ne doit
    // JAMAIS laisser une panne FCM bloquer le démarrage de l'app.
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

      await _localNotifications.resolvePlatformSpecificImplementation;
      AndroidFlutterLocalNotificationsPlugin 
          ()?.createNotificationChannel(_channel);

      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      );
      await _localNotifications.initialize(initSettings);

      final token = await _messaging.getToken();
      if (token != null) {
        await _safeWrite('fcm_token', token);
        debugPrint('[FCM] Token stocké: ${token.substring(0, 20)}...');
      }

      _messaging.onTokenRefresh.listen((newToken) async {
        await _safeWrite('fcm_token', newToken);
        debugPrint('[FCM] Token rafraîchi et stocké');
        try {
          await ApiClient.instance.dio.patch(
            '/auth/me/fcm-token',
            data: {'fcmToken': newToken},
          );
          debugPrint('[FCM] Token rafraîchi renvoyé au backend');
        } catch (e) {
          debugPrint('[FCM] Erreur renvoi token rafraîchi: $e');
        }
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final android = message.notification?.android;
        if (notification != null && android != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                importance: Importance.high,
                priority: Priority.high,
                icon: '@mipmap/launcher',
              ),
            ),
          );
        }
      });

      debugPrint('[FCM] Initialisé avec succès');
    } catch (e) {
      // Ne jamais bloquer le démarrage de l'app si FCM échoue
      // (réseau, config Firebase manquante, quota, FIS_AUTH_ERROR, etc.)
      debugPrint(
          '[FCM] Initialisation échouée, app continue sans notifications push: $e');
    }
  }

  /// Envoie le token FCM stocké au backend — à appeler après login
  static Future<void> sendTokenToBackend(Dio dio) async {
    try {
      final token = await _safeRead('fcm_token');
      if (token != null) {
        await dio.patch('/auth/me/fcm-token', data: {'fcmToken': token});
        debugPrint('[FCM] Token envoyé au backend');
      }
    } catch (e) {
      debugPrint('[FCM] Erreur envoi token backend: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Stockage sécurisé résilient — même logique que ApiClient.
  // Sur certains appareils Android, l'Android Keystore peut invalider sa
  // clé de chiffrement (AEADBadTagException) ; on efface le stockage
  // corrompu au lieu de laisser l'exception remonter et bloquer FCM.
  // ─────────────────────────────────────────────────────────────

  static Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      try {
        await _storage.deleteAll();
        await _storage.write(key: key, value: value);
      } catch (_) {
        // Rien de plus à faire ici.
      }
    }
  }

  static Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      try {
        await _storage.deleteAll();
      } catch (_) {
        // Rien de plus à faire ici.
      }
      return null;
    }
  }
}
