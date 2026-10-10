# R8 Optimization & Obfuscation Enhancements
-optimizationpasses 5
-allowaccessmodification
-repackageclasses ''

# Standard Flutter rules (Optimized)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep our MainActivity but allow obfuscation of internal methods if possible
-keep class com.rusobrg.roastnrizz.MainActivity { <init>(); }
-keep public class * extends android.app.Activity

# Google Play Services / AdMob (Aggressive Optimization)
-keep public class com.google.android.gms.ads.** { public *; }
-keep public class com.google.ads.mediation.** { public *; }
-dontwarn com.google.android.gms.**

# Firebase (Aggressive Optimization)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Prevent stripping of essential components while allowing class shrinking
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# General safety
-dontnote **
-dontwarn **
-ignorewarnings

# Enable aggressive resource shrinking compatibility
-keepattributes SourceFile,LineNumberTable,Signature,EnclosingMethod,InnerClasses,AnnotationDefault,*Annotation*
