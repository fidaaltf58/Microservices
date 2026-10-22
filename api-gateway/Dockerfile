# Build stage: compile with the full JDK + Maven, cache dependencies in their own layer
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q clean package -DskipTests

# Runtime stage: JRE only, unprivileged user
FROM eclipse-temurin:17-jre-alpine
RUN addgroup -S -g 10001 app && adduser -S -D -u 10001 -G app app
WORKDIR /app
COPY --from=build --chown=10001:10001 /app/target/*.jar app.jar
USER 10001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=5 \
  CMD ["sh", "-c", "wget -qO- http://127.0.0.1:8080/actuator/health || exit 1"]
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
