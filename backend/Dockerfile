# Image exécutable Spring Boot, prête pour AWS ECR / ECS (ou tout registre OCI).
# Build (multi-module : mobili-core + mobili-boot) depuis le dossier backend/ :
#   docker build -t mobili-api:latest ./backend
# Tag / push ECR (exemple) :
#   aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com
#   docker tag mobili-api:latest <account>.dkr.ecr.<region>.amazonaws.com/mobili-api:latest
#   docker push <account>.dkr.ecr.<region>.amazonaws.com/mobili-api:latest
#
# En local : -p 8080:8080 + variables (voir application-staging.yml) :
#   docker run -p 8080:8080 -e DB_URL=... -e DB_USERNAME=... -e DB_PASSWORD=... mobili-api:latest
#
# Autre profil (ex. prod) : -e SPRING_PROFILES_ACTIVE=production
FROM maven:3.9-eclipse-temurin-21-alpine AS build
WORKDIR /build
COPY pom.xml .
COPY mobili-core/pom.xml mobili-core/
COPY mobili-boot/pom.xml mobili-boot/
COPY mobili-core/src mobili-core/src
COPY mobili-boot/src mobili-boot/src
RUN mvn -q -DskipTests -pl mobili-boot -am package \
    && mv /build/mobili-boot/target/application.jar /build/application.jar

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S mobili && adduser -S -G mobili mobili
WORKDIR /app
COPY --from=build --chown=mobili:mobili /build/application.jar app.jar

USER mobili
EXPOSE 8080

# Profil par défaut : recette (override au run si besoin).
ENV SPRING_PROFILES_ACTIVE=staging
ENV JAVA_OPTS=""

# Spring Boot lit SPRING_PROFILES_ACTIVE ; pas besoin de -Dspring.profiles.active.
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
