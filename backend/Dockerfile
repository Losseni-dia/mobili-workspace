# Image JAR exécutable (build Maven dans l'image, pas d'exécution locale requise).
# Usage : docker compose depuis la racine du dépôt, ou : docker build -t mobili-api ./backend
FROM maven:3.9-eclipse-temurin-21-alpine AS build
WORKDIR /build
COPY pom.xml .
COPY src src
RUN mvn -q -DskipTests package \
    && mv /build/target/*.jar /build/application.jar

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /build/application.jar app.jar
EXPOSE 8080
ENV JAVA_OPTS=""
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
