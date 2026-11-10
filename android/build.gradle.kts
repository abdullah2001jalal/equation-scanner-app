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

// رفع compileSdk لأي وحدة Android (إضافات pub) إلى 36 على الأقل
// لأن بعض المكتبات تتطلب compileSdk >= 36 في فحص AAR metadata.
// يُستخدم انعكاس (reflection) لتجنّب الاعتماد على أنواع AGP في سكربت الجذر.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        val current = runCatching {
            val getter = androidExt.javaClass.methods.firstOrNull {
                it.name == "getCompileSdk" && it.parameterCount == 0 &&
                    it.returnType == java.lang.Integer::class.java
            }
            getter?.invoke(androidExt) as? Int
        }.getOrNull() ?: 0
        if (current < 36) {
            runCatching {
                val setter = androidExt.javaClass.methods.firstOrNull {
                    it.name == "setCompileSdk" && it.parameterCount == 1 &&
                        it.parameterTypes[0] == java.lang.Integer::class.java
                }
                setter?.invoke(androidExt, 36)
            }
            println("[eqscan] رفع compileSdk للوحدة ${project.name}: $current -> 36")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
