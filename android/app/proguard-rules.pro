# ============================================================
# Flutter CallKit Incoming — Keep Rules
# ============================================================
-keep class com.hiennv.flutter_callkit_incoming.** { *; }
-keep class com.hiennv.flutter_callkit_incoming.entities.** { *; }

# ============================================================
# Agora RTC Engine — Keep Rules
# ============================================================
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# ============================================================
# Firebase Messaging — Keep Rules
# ============================================================
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# ============================================================
# GSON / Serialization (যদি ব্যবহার করেন)
# ============================================================
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }