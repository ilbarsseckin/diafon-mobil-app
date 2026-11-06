-keep class com.hiennv.flutter_callkit_incoming.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.messaging.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keepclassmembers class * {
    @com.google.firebase.messaging.FirebaseMessagingService <methods>;
}
-dontwarn com.google.firebase.**
-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod,Exceptions

# flutter_webrtc (JNI ile çağrılıyor)
-keep class org.webrtc.** { *; }
-keep class com.cloudwebrtc.webrtc.** { *; }
-dontwarn org.webrtc.**

# flutter_local_notifications (Gson ile zamanlanmış bildirimleri saklıyor)
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken

# flutter_background_service
-keep class id.flutter.flutter_background_service.** { *; }

# Flutter deferred components (Play Core kullanılmıyor)
-dontwarn com.google.android.play.core.**
