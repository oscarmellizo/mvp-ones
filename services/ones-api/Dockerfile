FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /workspace
COPY pom.xml .
COPY mvnw .
COPY .mvn ./.mvn
COPY src ./src
RUN chmod +x mvnw && ./mvnw -q -DskipTests=false test package

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /workspace/target/ones-api-0.1.0-SNAPSHOT.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app/app.jar"]
