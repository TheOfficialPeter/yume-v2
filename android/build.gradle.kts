allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val flutterCompileSdkVersion = project.properties["flutter.compileSdkVersion"]?.toString()?.toIntOrNull() ?: 34
val flutterTargetSdkVersion = project.properties["flutter.targetSdkVersion"]?.toString()?.toIntOrNull() ?: 34
val flutterMinSdkVersion = project.properties["flutter.minSdkVersion"]?.toString()?.toIntOrNull() ?: 21

extra.apply {
    set("flutter", mapOf(
        "compileSdkVersion" to flutterCompileSdkVersion,
        "targetSdkVersion" to flutterTargetSdkVersion,
        "minSdkVersion" to flutterMinSdkVersion
    ))
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
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }

    if (project.name != "app") {
        afterEvaluate {
            if (project.plugins.hasPlugin("com.android.library")) {
                extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                    compileSdk = 34

                    defaultConfig {
                        minSdk = 21
                    }

                    compileOptions {
                        sourceCompatibility = JavaVersion.VERSION_11
                        targetCompatibility = JavaVersion.VERSION_11
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
