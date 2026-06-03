# --- Étape A : BUILD (on compile le projet) ---
FROM eclipse-temurin:21-jdk-alpine

RUN apk add --no-cache maven

WORKDIR /build

# On copie d'abord les pom.xml pour profiter du cache Docker (comme package.json pour le front)
COPY pom.xml .
COPY mobili-core/pom.xml mobili-core/
COPY mobili-boot/pom.xml mobili-boot/

# Ensuite le code source des deux modules
COPY mobili-core/src mobili-core/src
COPY mobili-boot/src mobili-boot/src

# On compile et on fabrique le JAR du module "boot" (+ dépendance "core" automatiquement)
# -pl mobili-boot = seulement ce module
# -am = " aussi les modules dont il dépend" → mobili-core
RUN mvn -B -f pom.xml -pl mobili-boot -am package -DskipTests

# --- Étape B : RUNTIME (on ne garde que ce qui sert à exécuter) ---
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# On récupère SEULEMENT le JAR construit à l'étape A
COPY --from=0 /build/mobili-boot/target/application.jar /app/application.jar

EXPOSE 8080

CMD ["java", "-jar", "/app/application.jar"]