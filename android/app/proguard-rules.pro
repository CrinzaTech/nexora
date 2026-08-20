# ──────────────────────────────────────────────────────────────────────
# Crinza App — ProGuard / R8 rules
#
# Reflection-heavy plugins crash when R8 strips classes they look up by
# name at runtime. Each block below documents which dependency it
# protects so adding new plugins is straightforward: bring the plugin
# in, ship one debug release, watch the logcat for `ClassNotFoundException`
# or `NoSuchMethodError`, add the matching -keep rule here.
# ──────────────────────────────────────────────────────────────────────

# Flutter framework — embedded plugins do their own reflection
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }

# ── Razorpay (payments) — reflects on annotations + uses ProGuard map
-keep class com.razorpay.** { *; }
-keepattributes *Annotation*,Signature,InnerClasses
-dontwarn com.razorpay.**
-keep class proguard.annotation.Keep
-keep class proguard.annotation.KeepClassMembers
-keep @proguard.annotation.Keep class * { *; }
-keepclassmembers class * {
    @proguard.annotation.Keep *;
}

# ── Syncfusion PDF Viewer — reflection over widget construction
-keep class com.syncfusion.** { *; }
-dontwarn com.syncfusion.**

# ── Firebase (core, messaging, crashlytics) — uses reflection for
# token registration + crash deserialization
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Google Sign-In + smart_auth (SMS OTP autofill)
-dontwarn com.google.android.gms.auth.api.credentials.**
-keep class com.google.android.gms.auth.api.credentials.** { *; }
-dontwarn com.google.android.gms.common.**
-keep class com.google.android.gms.common.** { *; }

# ── video_player / ExoPlayer — uses reflection for renderer selection
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# ── better_player_plus (live class) — bundles its own AndroidX Media3
# player (not the legacy exoplayer2 namespace above) — same renderer
# reflection concern.
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# ── file_picker — bridges native MIME types via reflection
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# ── Gson / serialization — keep model classes' fields if any package
# uses Gson reflection (Firebase and Razorpay both ship it transitively)
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers class * { @com.google.gson.annotations.SerializedName <fields>; }
-keep class com.google.gson.** { *; }

# ── Kotlin coroutines + reflection
-keepclassmembers class kotlin.coroutines.** { *; }
-keep class kotlin.Metadata { *; }

# ── Keep all native methods (JNI bridges)
-keepclasseswithmembernames class * {
    native <methods>;
}

# ── Keep enum lookup methods (used by serialization)
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ── Keep custom application + activity entry points
-keep public class * extends android.app.Application
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# ── Flutter Play Core deferred-component shims — Flutter's embedding
# references com.google.android.play.core.splitinstall.* and
# com.google.android.play.core.tasks.* unconditionally, but we don't
# ship Play Core (no deferred components). Silence the missing-class
# errors so R8 can complete.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
