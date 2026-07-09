allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force every Android module (app + plugins such as flutter_webrtc, sqflite,
// url_launcher) to compile against SDK 36. Plugin modules otherwise inherit a
// lower flutter.compileSdkVersion (android-31 here), which fails AAR-metadata
// checks for recent AndroidX libraries that require 34/36.
fun forceCompileSdk36(project: org.gradle.api.Project) {
    val android = project.extensions.findByName("android") ?: return
    val setCompileSdk = android.javaClass.methods.firstOrNull {
        it.name == "setCompileSdk" && it.parameterTypes.size == 1
    }
    if (setCompileSdk != null) {
        setCompileSdk.invoke(android, 36)
    } else {
        android.javaClass.methods.firstOrNull {
            it.name == "compileSdkVersion" && it.parameterTypes.size == 1 &&
                it.parameterTypes[0] == Integer.TYPE
        }?.invoke(android, 36)
    }
}

subprojects {
    // :app is already evaluated (others depend on it) and pins compileSdk 36
    // itself; only the not-yet-evaluated plugin modules need the override.
    if (state.executed) {
        forceCompileSdk36(project)
    } else {
        afterEvaluate { forceCompileSdk36(project) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
