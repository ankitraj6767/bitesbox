# R8/ProGuard rules for the release build.
#
# The Flutter and Firebase Gradle plugins already contribute consumer rules for
# their own code. What is listed here is what R8 cannot infer from this project.

# Razorpay's checkout SDK is reached reflectively from its own WebView bridge.
-keep class com.razorpay.** { *; }
-keepclassmembers class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# proguard-android-optimize strips annotations that Razorpay's bridge relies on.
-keepattributes JavascriptInterface
-keepattributes *Annotation*

# Google Play Core is referenced by the Flutter deferred-components code path even
# when the app does not use deferred loading.
-dontwarn com.google.android.play.core.**

# Keep the entry points the platform instantiates by name.
-keep class in.bitesbox.bitesbox.MainActivity { *; }
