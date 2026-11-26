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
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            val setCompileSdk = runCatching { androidExt.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType!!) }.getOrNull()
            if (setCompileSdk != null) {
                runCatching { setCompileSdk.invoke(androidExt, 36) }
            } else {
                val compileSdkVersion = runCatching { androidExt.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType!!) }.getOrNull()
                if (compileSdkVersion != null) {
                    runCatching { compileSdkVersion.invoke(androidExt, 36) }
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
