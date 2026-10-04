# Keepi release keep rules.
#
# Room and WorkManager create these classes reflectively. With AGP 9 / R8
# strict full mode, old transitive keep rules are not sufficient and release
# builds can crash before the first Activity is created.

-keep class * extends androidx.room.RoomDatabase {
    <init>();
}

-keep class * extends androidx.work.InputMerger {
    <init>();
}

# WorkManager's generated Room database must keep its runtime name and
# no-argument constructor because Room resolves it reflectively.
-keep class androidx.work.impl.WorkDatabase_Impl {
    <init>();
}
