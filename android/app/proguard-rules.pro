# WorkManager creates its Room database implementation reflectively at startup.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
