buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.1")
    }
}

// flutter_background_geolocation choisit son artefact natif (tslocationmanager vs
// tslocationmanager-v21) selon la version de play-services-location déclarée ici : la valeur par
// défaut du plugin (20.0.0) pointe vers un artefact "tslocationmanager:3.+" retiré de Maven
// Central (seules les versions 4.x restent publiées) — build cassé sans cet override. >= 21
// bascule sur l'artefact "-v21", toujours publié en 3.+.
extra["playServicesLocationVersion"] = "21.3.0"

// Même logique : flutter_background_geolocation compile par défaut en 34, mais sa propre
// dépendance transitive background_fetch exige compileSdk >= 36 — même override que app/
// build.gradle.kts (voir commentaire au-dessus de "compileSdk = 36" dans ce fichier).
extra["compileSdkVersion"] = 36

allprojects {
    repositories {
        google()
        mavenCentral()
        // flutter_background_geolocation embarque ses artefacts natifs (tslocationmanager /
        // tslocationmanager-v21) dans son propre dossier "libs" plutôt que sur Maven Central,
        // qui n'héberge plus que la ligne 4.x (le plugin réclame "3.+", introuvable ailleurs).
        // Le repository relatif "./libs" déclaré dans le build.gradle du plugin ne se résout pas
        // correctement une fois inclus dans le build composite Flutter — on le redéclare ici en
        // chemin absolu, comme documenté par Transistorsoft pour ce cas précis.
        findProject(":flutter_background_geolocation")?.let { plugin ->
            maven { url = uri("${plugin.projectDir}/libs") }
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