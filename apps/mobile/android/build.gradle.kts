fun requireGradleProperty(name: String): String {
    return providers.gradleProperty(name).orNull
        ?: error(
            "$name is required to download Mapbox Android artifacts. " +
                "Add it to %USERPROFILE%/.gradle/gradle.properties",
        )
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://api.mapbox.com/downloads/v2/releases/maven") {
            authentication {
                create<BasicAuthentication>("basic")
            }
            credentials {
                username = "mapbox"
                password = requireGradleProperty("MAPBOX_DOWNLOADS_TOKEN")
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
