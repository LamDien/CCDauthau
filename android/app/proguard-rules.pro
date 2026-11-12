# Keep Flutter wrapper & platform channels
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Room 2.2.5 (used by WorkManager 2.7.0 pulled in via google_mobile_ads):
# Keep generated *_Impl no-arg constructors under R8 full mode.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}

