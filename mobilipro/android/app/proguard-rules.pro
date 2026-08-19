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

# Attributs nécessaires pour que les stack traces obfusquées restent
# ré-associables via --split-debug-info (voir deploy-mobilipro.yml).
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
