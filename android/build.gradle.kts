import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import com.android.build.gradle.BaseExtension

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

subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        val androidExt = project.extensions.findByType(BaseExtension::class.java)
        val javaTarget = androidExt?.compileOptions?.targetCompatibility
        val kotlinTarget =
            when (javaTarget) {
                JavaVersion.VERSION_17 -> JvmTarget.JVM_17
                JavaVersion.VERSION_11 -> JvmTarget.JVM_11
                else -> JvmTarget.JVM_1_8
            }
        compilerOptions.jvmTarget.set(kotlinTarget)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
