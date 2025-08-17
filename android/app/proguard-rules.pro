# Keep ZegoCloud-related classes
-keep class **.zego.** { *; }
-keep class im.zego.** { *; }
-keep class com.zegocloud.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
# Vendor-Specific Push Services
# Uncomment these if you need push notifications for the corresponding vendors
# Remove any rules for vendors you are not targeting.
-keep class com.heytap.msp.** { *; }
-keep class com.huawei.hms.** { *; }
-keep class com.vivo.push.** { *; }
-keep class com.xiaomi.mipush.sdk.** { *; }

# Conscrypt (for secure connections)
-keep class org.conscrypt.** { *; }

# XML Parsing and SAX Support
-keep class org.xmlpull.** { *; }
-keep class org.xml.sax.** { *; }
-keep class org.w3c.dom.bootstrap.** { *; }

# Suppress warnings for unused vendor classes
-dontwarn com.heytap.**
-dontwarn com.huawei.**
-dontwarn com.vivo.**
-dontwarn com.xiaomi.**
-dontwarn okhttp3.internal.platform.ConscryptPlatform
-dontwarn okhttp3.internal.platform.Android10Platform

# Jackson JSON parser classes
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes Signature
-keepattributes Exceptions
-keep class com.fasterxml.jackson.** { *; }
-keepnames class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.databind.**
-keep class com.itgsa.opensdk.mediaunit.KaraokeMediaHelper { *; }
-keep class com.itgsa.opensdk.mediaunit.** { *; }

-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
# Keep Flutter core classes
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Keep Google Play Core classes (for deferred components and split installs)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep ITGSA OpenSDK classes (third-party SDK)
-keep class com.itgsa.opensdk.** { *; }
-dontwarn com.itgsa.opensdk.**

# Keep AndroidX classes (if used)
-keep class androidx.** { *; }
-dontwarn androidx.**
-dontwarn org.slf4j.impl.StaticLoggerBinder


# Ajout des règles pour Apache Tika et XML Stream
-keep class org.apache.tika.** { *; }
-keep class javax.xml.stream.** { *; }
-dontwarn org.apache.tika.**
-dontwarn javax.xml.stream.**

# Ajout pour les classes AndroidX manquantes
-keep class androidx.lifecycle.** { *; }
-keep class androidx.arch.core.** { *; }
