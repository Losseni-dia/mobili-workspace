import org.gradle.authentication.http.BasicAuthentication

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // mapbox_maps_flutter télécharge le SDK natif Android depuis le repository Maven privé
        // de Mapbox — nécessite un "secret downloads token" (scope DOWNLOADS:READ, distinct du
        // token public utilisé à l'exécution dans le code Dart). Jamais commité : lu depuis la
        // variable d'environnement MAPBOX_DOWNLOADS_TOKEN (même convention que les autres
        // secrets de build, ex. MOBILEAPP_KEYSTORE_PASSWORD ci-dessous dans app/build.gradle.kts).
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication { create<BasicAuthentication>("basic") }
            credentials {
                username = "mapbox"
                password = System.getenv("MAPBOX_DOWNLOADS_TOKEN") ?: ""
            }
        }
    }
}

// mapbox_maps_flutter (2.30.0) suppose que AGP 9+ fournit automatiquement l'extension Kotlin
// "kotlin { compilerOptions {...} }" sans appliquer explicitement le plugin Kotlin Android
// (commentaire dans son propre build.gradle : "Kotlin is built into AGP 9+") — ce qui n'est pas
// le cas ici (le Built-in Kotlin de Flutter est encore un mécanisme de compatibilité, pas
// automatiquement actif pour les plugins tiers) : build en échec avec "Could not find method
// kotlin()". On applique nous-mêmes le plugin sur ce seul sous-projet.
subprojects {
    if (name == "mapbox_maps_flutter") {
        apply(plugin = "org.jetbrains.kotlin.android")
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