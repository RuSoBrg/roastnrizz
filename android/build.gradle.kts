allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // Force a single Android Preferences location to fix AndroidLocationsBuildService conflicts
    System.setProperty("ANDROID_USER_HOME", System.getenv("USERPROFILE") + "/.android")
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
