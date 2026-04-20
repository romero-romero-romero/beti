# ═══════════════════════════════════════════════════════════
# Beti — ProGuard / R8 rules
# ═══════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────
# Flutter (core engine)
# ───────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# ───────────────────────────────────────────────────────────
# Google ML Kit — Text Recognition
# Beti solo usa el reconocedor "latin" (español mexicano),
# pero el plugin referencia las clases de otros idiomas
# (chino, japonés, coreano, devanagari). Como no instalamos
# sus pods, le decimos a R8 que es OK que no existan.
# ───────────────────────────────────────────────────────────
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# ───────────────────────────────────────────────────────────
# Isar Database
# Isar usa reflection para generar adaptadores de schemas.
# Sin estas reglas, las colecciones se rompen en release.
# ───────────────────────────────────────────────────────────
-keep class dev.isar.** { *; }
-keep class io.isar.** { *; }

# ───────────────────────────────────────────────────────────
# Supabase / GoTrue / Realtime
# Usan reflection para serialización/deserialización JSON.
# ───────────────────────────────────────────────────────────
-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }
-dontwarn io.supabase.**

# ───────────────────────────────────────────────────────────
# Kotlin Metadata (usado por librerías Kotlin nativas)
# ───────────────────────────────────────────────────────────
-keep class kotlin.Metadata { *; }
-keep class kotlin.reflect.** { *; }

# ───────────────────────────────────────────────────────────
# Play Core (requerido por Flutter release builds)
# ───────────────────────────────────────────────────────────
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ───────────────────────────────────────────────────────────
# flutter_local_notifications
# Usa serialización JSON para persistir notificaciones
# programadas a través de reboots.
# ───────────────────────────────────────────────────────────
-keep class com.dexterous.** { *; }
-keep class androidx.core.app.** { *; }

# ───────────────────────────────────────────────────────────
# speech_to_text (Android Speech Recognition)
# ───────────────────────────────────────────────────────────
-keep class androidx.lifecycle.** { *; }

# ───────────────────────────────────────────────────────────
# connectivity_plus
# ───────────────────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.** { *; }

# ───────────────────────────────────────────────────────────
# AndroidX (evita warnings de dependencias transitivas)
# ───────────────────────────────────────────────────────────
-dontwarn androidx.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**