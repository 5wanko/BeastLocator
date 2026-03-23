import java.io.File
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.Properties
import java.util.TimeZone
import org.gradle.api.artifacts.ExternalModuleDependency

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val revisionStateFile = rootProject.file(".debug-revision-state.properties")

fun collectRevisionInputFiles(path: File): List<File> {
    if (!path.exists()) return emptyList()
    if (path.isFile) return listOf(path)
    return path.walkTopDown()
        .onEnter { dir -> dir.name != "build" && dir.name != ".gradle" }
        .filter { it.isFile }
        .toList()
}

fun updateDigestWithFile(digest: MessageDigest, file: File, projectRoot: File) {
    val relativePath = projectRoot.toPath().relativize(file.toPath()).toString().replace("\\", "/")
    digest.update(relativePath.toByteArray(Charsets.UTF_8))
    digest.update(0)
    file.inputStream().use { input ->
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        while (true) {
            val read = input.read(buffer)
            if (read <= 0) break
            digest.update(buffer, 0, read)
        }
    }
    digest.update(0)
}

fun computeRevisionHash(files: List<File>, projectRoot: File): String {
    val digest = MessageDigest.getInstance("SHA-256")
    files.sortedBy { it.absolutePath }.forEach { file ->
        updateDigestWithFile(digest, file, projectRoot)
    }
    return digest.digest().joinToString("") { "%02x".format(it) }
}

fun createRevisionDateFormatter(): SimpleDateFormat {
    return SimpleDateFormat("yyMMdd", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("Asia/Tokyo")
    }
}

data class OssCatalogEntry(
    val title: String,
    val coordinate: String,
    val license: String,
    val url: String,
    val body: String
)

fun jsonEscape(value: String): String {
    return buildString(value.length + 16) {
        value.forEach { ch ->
            when (ch) {
                '\\' -> append("\\\\")
                '"' -> append("\\\"")
                '\n' -> append("\\n")
                '\r' -> append("\\r")
                '\t' -> append("\\t")
                else -> append(ch)
            }
        }
    }
}

fun resolveLicenseMetadata(group: String, name: String): Triple<String, String, String> {
    return when {
        group.startsWith("androidx.") -> Triple(
            "Apache License 2.0",
            "https://developer.android.com/jetpack/androidx/releases",
            "AndroidX libraries are distributed under Apache License 2.0."
        )
        group == "com.google.android.material" -> Triple(
            "Apache License 2.0",
            "https://github.com/material-components/material-components-android",
            "Material Components for Android is distributed under Apache License 2.0."
        )
        group.startsWith("org.jetbrains.kotlin") -> Triple(
            "Apache License 2.0",
            "https://kotlinlang.org/docs/license.html",
            "Kotlin is distributed under Apache License 2.0."
        )
        group.startsWith("com.google.android.gms") -> Triple(
            "Google Play services Terms",
            "https://policies.google.com/terms",
            "Google Play services is provided under Google Play services terms."
        )
        else -> Triple(
            "License not specified",
            "https://mvnrepository.com/artifact/$group/$name",
            "Please check the upstream project page for license details."
        )
    }
}

fun prettifyArtifactName(name: String): String {
    return name.split('-', '_')
        .filter { it.isNotBlank() }
        .joinToString(" ") { token ->
            when (token.lowercase(Locale.US)) {
                "ktx" -> "KTX"
                "api" -> "API"
                "sdk" -> "SDK"
                else -> token.replaceFirstChar {
                    if (it.isLowerCase()) it.titlecase(Locale.US) else it.toString()
                }
            }
        }
}

fun resolveDisplayTitle(group: String, name: String): String {
    return when {
        group == "androidx.activity" && name == "activity-ktx" -> "AndroidX Activity KTX"
        group == "androidx.appcompat" && name == "appcompat" -> "AndroidX AppCompat"
        group == "androidx.core" && name == "core-ktx" -> "AndroidX Core KTX"
        group == "androidx.constraintlayout" && name == "constraintlayout" -> "AndroidX ConstraintLayout"
        group == "com.google.android.material" && name == "material" -> "Material Components for Android"
        group.startsWith("org.jetbrains.kotlin") && name.startsWith("kotlin-stdlib") -> "Kotlin Standard Library"
        group == "com.google.android.gms" && name == "play-services-location" -> "Google Play services Location"
        group.startsWith("androidx.") -> "AndroidX ${prettifyArtifactName(name)}"
        else -> prettifyArtifactName(name)
    }
}

val revisionInputRoots = listOf(
    rootProject.file("build.gradle.kts"),
    rootProject.file("settings.gradle.kts"),
    rootProject.file("gradle/libs.versions.toml"),
    project.file("build.gradle.kts"),
    project.file("proguard-rules.pro"),
    project.file("src/main"),
    project.file("src/debug"),
    project.file("src/release")
)

val revisionInputFiles = revisionInputRoots
    .flatMap(::collectRevisionInputFiles)
    .distinctBy { it.absolutePath }

val revisionProperties = Properties().apply {
    if (revisionStateFile.exists()) {
        revisionStateFile.inputStream().use { load(it) }
    }
}

val currentRevisionHash = computeRevisionHash(revisionInputFiles, rootProject.projectDir)
val storedRevisionHash = revisionProperties.getProperty("last_hash")
var revisionCounter = revisionProperties.getProperty("counter")?.toIntOrNull() ?: 0
var revisionDate = revisionProperties.getProperty("stamp_date")
val todayRevisionDate = createRevisionDateFormatter().format(Date())

if (storedRevisionHash != currentRevisionHash) {
    revisionCounter = if (revisionDate == todayRevisionDate) {
        revisionCounter + 1
    } else {
        1
    }
    revisionDate = todayRevisionDate
    revisionProperties["last_hash"] = currentRevisionHash
    revisionProperties["counter"] = revisionCounter.toString()
    revisionProperties["stamp_date"] = revisionDate
    revisionStateFile.outputStream().use {
        revisionProperties.store(it, "Auto-generated. Incremented when source hash changes.")
    }
}

if (revisionDate.isNullOrBlank()) {
    revisionDate = todayRevisionDate
}

val revisionId = "${revisionDate}_${revisionCounter.toString().padStart(6, '0')}"
val generatedOssAssetsDir = layout.buildDirectory.dir("generated/oss-assets")
val generatedOssFile = generatedOssAssetsDir.map { it.file("oss_licenses/oss_licenses_auto.json") }

val generateOssLicensesAutoJson = tasks.register("generateOssLicensesAutoJson") {
    outputs.file(generatedOssFile)
    doLast {
        val implementationDeps = project.configurations
            .getByName("implementation")
            .dependencies
            .withType(ExternalModuleDependency::class.java)
            .mapNotNull { dep ->
                val group = dep.group ?: return@mapNotNull null
                val version = dep.version ?: return@mapNotNull null
                val (license, url, body) = resolveLicenseMetadata(group, dep.name)
                OssCatalogEntry(
                    title = resolveDisplayTitle(group, dep.name),
                    coordinate = "$group:${dep.name}:$version",
                    license = license,
                    url = url,
                    body = body
                )
            }
            .distinctBy { it.coordinate }

        val extraEntries = listOf(
            OssCatalogEntry(
                title = "Photon (Reverse Geocoding API)",
                coordinate = "service:photon",
                license = "Apache License 2.0",
                url = "https://github.com/komoot/photon",
                body = "Photon reverse geocoding service is open source under Apache License 2.0."
            ),
            OssCatalogEntry(
                title = "OpenStreetMap / Nominatim Data",
                coordinate = "data:openstreetmap-nominatim",
                license = "ODbL 1.0",
                url = "https://www.openstreetmap.org/copyright",
                body = "OpenStreetMap data is licensed under ODbL 1.0."
            )
        )

        val entries = (implementationDeps + extraEntries)
            .distinctBy { it.coordinate }
            .sortedBy { it.coordinate.lowercase(Locale.US) }

        val outFile = generatedOssFile.get().asFile
        outFile.parentFile.mkdirs()
        val generatedAt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US).format(Date())
        val json = buildString {
            append("{\n")
            append("  \"generatedAt\": \"").append(jsonEscape(generatedAt)).append("\",\n")
            append("  \"entries\": [\n")
            entries.forEachIndexed { index, entry ->
                append("    {\n")
                append("      \"title\": \"").append(jsonEscape(entry.title)).append("\",\n")
                append("      \"coordinate\": \"").append(jsonEscape(entry.coordinate)).append("\",\n")
                append("      \"license\": \"").append(jsonEscape(entry.license)).append("\",\n")
                append("      \"url\": \"").append(jsonEscape(entry.url)).append("\",\n")
                append("      \"body\": \"").append(jsonEscape(entry.body)).append("\"\n")
                append("    }")
                if (index != entries.lastIndex) append(",")
                append("\n")
            }
            append("  ]\n")
            append("}\n")
        }
        outFile.writeText(json)
    }
}

android {
    namespace = "jp.linkserver.beastlocator"
    compileSdk = 34

    buildFeatures {
        buildConfig = true
    }

    val appVersionName = "1.2.4-IntDev"

    defaultConfig {
        applicationId = "jp.linkserver.beastlocator"
        minSdk = 26 // 通常は26
        targetSdk = 34
        versionCode = 202603234   // 2026, 03, 23, 4(年、月、日、その日のうちの何個目)
        versionName = appVersionName
        buildConfigField("String", "REVISION_ID", "\"$revisionId\"")
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    sourceSets.getByName("main") {
        assets.srcDir(generatedOssAssetsDir)
    }
}

tasks.named("preBuild").configure {
    dependsOn(generateOssLicensesAutoJson)
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.activity:activity-ktx:1.9.2")
    implementation("com.google.android.gms:play-services-location:21.3.0")
}
