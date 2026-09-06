## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

## Gson rules
# Gson uses generic type information stored in a class file when working with fields. Proguard
# removes such information by default, so configure it to keep all of it.
-keepattributes Signature

# For using GSON @Expose annotation
-keepattributes *Annotation*

# Gson specific classes
-dontwarn sun.misc.**
#-keep class com.google.gson.stream.** { *; }

# Prevent proguard from stripping interface information from TypeAdapter, TypeAdapterFactory,
# JsonSerializer, JsonDeserializer instances (so they can be used in @JsonAdapter)
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent R8 from leaving Data object members always null
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

-keepclassmembers enum * { *; }

## Crashlytics
# R8 renames classes and drops line numbers, which turns every release stack
# trace into noise. Keeping these attributes lets the mapping file that
# build.gradle uploads put the original frames back.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

## flutter_local_notifications
# Scheduled notifications are rebuilt from state persisted before the process
# died, and the plugin reads that state back reflectively.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class * extends com.dexterous.flutterlocalnotifications.** { *; }

## audio_service / just_audio_background
# The service and the media button receiver are instantiated by the system
# from the names in AndroidManifest.xml. AGP keeps manifest components on its
# own; this covers the classes they reach through the media session, which it
# does not see.
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }

## Glance app widgets
# Same shape: the receivers are in the manifest, but Glance resolves the
# GlanceAppWidget each one names at runtime.
-keep class com.developer110.shiacompanion.widgets.** { *; }
-keep class androidx.glance.appwidget.** { *; }
