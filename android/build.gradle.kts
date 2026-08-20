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

    // AGP 8+ requires every Android module to declare a `namespace` in
    // its build file. Some older plugins (e.g. flutter_jailbreak_detection
    // 1.10.0) still rely on the legacy `package` attribute in
    // AndroidManifest.xml and fail to configure with the namespace
    // error. This hook backfills the missing namespace from the manifest's
    // `package` attribute for any sub-project that hasn't migrated. It's
    // a no-op on plugins that already declare a namespace correctly.
    //
    // Registered HERE — before the `evaluationDependsOn(":app")` block
    // below — so the afterEvaluate handler is in place by the time
    // Gradle starts evaluating the sub-projects.
    afterEvaluate {
        if (extensions.findByName("android") != null) {
            val androidExt =
                extensions.findByName("android") as
                    com.android.build.gradle.BaseExtension
            if (androidExt.namespace == null) {
                val manifest = file("src/main/AndroidManifest.xml")
                if (manifest.exists()) {
                    val pkgRegex = Regex("""package="([^"]+)"""")
                    val match = pkgRegex.find(manifest.readText())
                    if (match != null) {
                        androidExt.namespace = match.groupValues[1]
                    }
                }
            }
            // Some older plugins (e.g. flutter_jailbreak_detection
            // 1.10.0) leave Java at 1.8 while Kotlin picks up the
            // host JDK (often 21). AGP's JVM-target validator then
            // refuses to build. Pin both to 11 — the same target the
            // app module uses — so every module compiles consistently.
            androidExt.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
        }
        tasks
            .withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                kotlinOptions {
                    jvmTarget = JavaVersion.VERSION_11.toString()
                }
            }

        // Cosmetic: silence the noisy javac deprecation warning from
        // third-party plugin Java sources (e.g. flutter_webrtc via
        // livekit_client's `[removal] onSurfaceDestroyed()`). We keep the
        // stable, known-good native versions rather than upgrading the
        // WebRTC/LiveKit stack just to fix a warning; `-Xlint:none` hides
        // it. Purely build-output only — no behavior change.
        tasks.withType<JavaCompile>().configureEach {
            options.isDeprecation = false
            options.compilerArgs.addAll(listOf("-Xlint:none", "-nowarn"))
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
