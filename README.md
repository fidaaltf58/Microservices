# Terminal 1: Bases de données
docker-compose up mysql postgres

# Terminal 2: Eureka Server
cd eureka-server
mvn clean install
mvn spring-boot:run

# Attendre que Eureka soit démarré (voir http://localhost:8761)

# Terminal 3: Config Server
cd config-server
mvn clean install
mvn spring-boot:run

# Terminal 4: Product Service
cd product-service
mvn clean install
mvn spring-boot:run

# Terminal 5: Order Service
cd order-service
mvn clean install
mvn spring-boot:run

# Terminal 6: API Gateway
cd api-gateway
mvn clean install
mvn spring-boot:run
