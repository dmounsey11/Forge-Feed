# AndroidX Startup / WorkManager (pulled in transitively by google_mobile_ads)
# ship a Room-backed WorkDatabase whose generated implementation classes R8
# would otherwise strip or rename, causing a crash on app launch before any
# Dart code runs: "Failed to create an instance of androidx.work.impl.WorkDatabase".
-keep public class * extends androidx.startup.Initializer
-keep class androidx.work.** { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class * { *; }
-dontwarn androidx.work.**
