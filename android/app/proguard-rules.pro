-keep class io.flutter.plugin.editing.** { *; }

# shared_preferences_android 2.5.x and package:jni look up these Kotlin types by
# name. Preserve them and their members so release optimization keeps JNI calls valid.
# https://github.com/flutter/flutter/issues/194649
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
