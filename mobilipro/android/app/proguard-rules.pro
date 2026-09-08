# AUDIT-MOBILI.md §4.6 — R8/ProGuard activé pour les builds release (minifyEnabled +
# shrinkResources). Règles de base : la plupart des plugins Flutter/Firebase modernes
# embarquent déjà leurs propres consumer-rules dans leur AAR (fusionnées automatiquement),
# donc ce fichier reste volontairement minimal — juste le socle historique recommandé pour
# ne jamais casser l'embedding Flutter lui-même, plus les libs de ce projet connues pour
# poser problème avec la réflexion (parsing JSON/notifications).

# Embedding Flutter — ne jamais obfusquer/supprimer, le moteur y accède par réflexion.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase Messaging — les payloads de notification push sont désérialisés par réflexion ;
# les stripper casserait la réception silencieusement (pas d'erreur de build, juste des
# notifications qui n'arrivent plus en prod).
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# flutter_local_notifications — sérialise ses payloads/receivers par réflexion.
-keep class com.dexterous.** { *; }

# mobile_scanner (Google ML Kit Barcode Scanning) — modèles ML chargés dynamiquement.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
-dontwarn com.google.mlkit.**

# cloud_firestore + firebase_auth (tracking temps réel, live-tracking-directions) — Firestore
# embarque gRPC/Protobuf, connus pour être cassés par R8 sans règles dédiées (crash au
# démarrage dès l'enregistrement du plugin par GeneratedPluginRegistrant, avant même le
# premier appel Dart — c'est le crash observé en prod tant que ces règles étaient absentes).
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class io.grpc.** { *; }
-keep class com.google.protobuf.** { *; }
-dontwarn io.grpc.**
-dontwarn com.google.protobuf.**

# flutter_background_geolocation (tracking GPS chauffeur) — s'appuie sur EventBus (réflexion
# sur les méthodes annotées @Subscribe, supprimées silencieusement par R8 sans ces règles) et
# sur ses propres classes natives Transistorsoft.
-keep class com.transistorsoft.** { *; }
-keepclassmembers class * {
    @org.greenrobot.eventbus.Subscribe <methods>;
}
-keep enum org.greenrobot.eventbus.ThreadMode { *; }
-keepclassmembers class * extends org.greenrobot.eventbus.util.ThrowableFailureEvent {
    <init>(java.lang.Throwable);
}

# Attributs nécessaires pour que les stack traces obfusquées restent
# ré-associables via --split-debug-info (voir deploy-mobilipro.yml).
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
