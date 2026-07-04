-keep class com.hiennv.flutter_callkit_incoming.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.messaging.** { *; }
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keepclassmembers class * {
    @com.google.firebase.messaging.FirebaseMessagingService <methods>;
}
-dontwarn com.google.firebase.**