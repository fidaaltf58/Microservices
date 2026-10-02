# E-commerce Microservices: Spring Boot & Spring Cloud

A small e-commerce backend built as **microservices** with **Spring Boot 3.2** and **Spring Cloud 2023.0**. It shows service discovery, centralised configuration, an API gateway with circuit breakers, inter-service calls with OpenFeign, and a separate database per service. Everything is containerised with Docker Compose.

---

## Architecture

```
                         ┌─────────────────────┐
     Client ───────────► │  API Gateway :8080  │  Spring Cloud Gateway
                         │  + Resilience4j CB  │  (fallbacks on /fallback/*)
                         └─────────┬───────────┘
                    lb://PRODUCT-SERVICE   lb://ORDER-SERVICE
                 ┌─────────────────┴──────────────────┐
                 ▼                                    ▼
      ┌──────────────────────┐   OpenFeign   ┌──────────────────────┐
      │ Product Service :8081│ ◄──────────── │  Order Service :8082 │
      └──────────┬───────────┘ (stock check) └──────────┬───────────┘
                 ▼                                      ▼
          MySQL 8 :3306                         PostgreSQL 15 :5432
           (productdb)                              (orderdb)

      ┌──────────────────────┐     ┌──────────────────────┐
      │ Eureka Server :8761  │     │ Config Server :8888  │
      │ (service registry)   │     │ (native profile)     │
      └──────────────────────┘     └──────────────────────┘
```

| Service | Port | Role |
|---|---|---|
| `eureka-server` | 8761 | Service registry (Netflix Eureka) |
| `config-server` | 8888 | Centralised configuration (Spring Cloud Config, `native` profile) |
| `api-gateway` | 8080 | Single entry point; routes `/api/products/**` and `/api/orders/**` with circuit breakers |
| `product-service` | 8081 | Product catalogue and stock (MySQL) |
| `order-service` | 8082 | Orders; checks and decrements stock through Feign (PostgreSQL) |

## Tech stack

- **Java 17**, **Spring Boot 3.2**, **Spring Cloud 2023.0.0**
- Spring Cloud **Gateway**, **Netflix Eureka**, **Config Server**, **OpenFeign**
- **Resilience4j** circuit breakers (gateway + Feign client)
- **Spring Data JPA** + **Bean Validation**
- **MySQL 8** (products), **PostgreSQL 15** (orders)
- **springdoc-openapi** (Swagger UI), **Spring Boot Actuator**
- **Docker** multi-stage builds + **Docker Compose**

## Getting started

### Option 1: Docker Compose (recommended)

Prerequisites: Docker and Docker Compose.

```bash
git clone https://github.com/fidaaltf58/Microservices.git
cd Microservices
docker compose up -d --build
```

Services start in dependency order (databases → Eureka → Config → Gateway → Product → Order) using health checks. The first build takes a few minutes because Maven runs inside each image.

| URL | What |
|---|---|
| <http://localhost:8761> | Eureka dashboard |
| <http://localhost:8080/api/products> | Products through the gateway |
| <http://localhost:8080/api/orders> | Orders through the gateway |
| <http://localhost:8081/swagger-ui.html> | Product Service Swagger UI |
| <http://localhost:8082/swagger-ui.html> | Order Service Swagger UI |
| <http://localhost:8080/actuator/health> | Gateway health |

```bash
docker compose logs -f order-service   # follow logs
docker compose down -v                 # stop and delete the data volumes
```

### Option 2: Run locally with Maven

Prerequisites: JDK 17, Maven 3.9.

```bash
# 1. Start the databases
docker compose up -d mysql postgres

# 2. Point the services at a local Eureka instance
export EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://localhost:8761/eureka/

# 3. Start each service in its own terminal, in this order
cd eureka-server   && mvn spring-boot:run
cd config-server   && mvn spring-boot:run
cd product-service && mvn spring-boot:run
cd order-service   && mvn spring-boot:run
cd api-gateway     && mvn spring-boot:run
```

Wait for Eureka (<http://localhost:8761>) to be up before starting the other services.

## API

All endpoints are available through the gateway on port `8080`.

### Products: `/api/products`

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/products` | List all products |
| `GET` | `/api/products/{id}` | Get a product |
| `POST` | `/api/products` | Create a product |
| `PUT` | `/api/products/{id}` | Update a product |
| `DELETE` | `/api/products/{id}` | Delete a product |
| `GET` | `/api/products/category/{category}` | Filter by category |
| `GET` | `/api/products/search?name=` | Search by name |
| `GET` | `/api/products/available` | Products in stock |
| `PATCH` | `/api/products/{id}/stock?quantity=` | Adjust stock by `quantity` (negative to decrease; rejected if stock would go below 0) |

### Orders: `/api/orders`

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/orders` | List all orders |
| `GET` | `/api/orders/{id}` | Get an order |
| `GET` | `/api/orders/number/{orderNumber}` | Get by order number |
| `POST` | `/api/orders` | Place an order (checks stock in Product Service) |
| `PATCH` | `/api/orders/{id}/status?status=` | Update status |
| `DELETE` | `/api/orders/{id}` | Cancel an order |
| `GET` | `/api/orders/customer/{email}` | Orders for a customer |
| `GET` | `/api/orders/status/{status}` | Filter by status |

Order statuses: `PENDING`, `CONFIRMED`, `PROCESSING`, `SHIPPED`, `DELIVERED`, `CANCELLED`.

### Example

```bash
# Create a product
curl -X POST http://localhost:8080/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","description":"14-inch","price":999.99,"stockQuantity":10,"category":"Electronics","active":true}'

# Place an order
curl -X POST http://localhost:8080/api/orders \
  -H "Content-Type: application/json" \
  -d '{"customerName":"Jane Doe","customerEmail":"jane@example.com","shippingAddress":"1 Main St",
       "items":[{"productId":1,"quantity":2}]}'
```

## Resilience

- **Gateway circuit breakers** (`productCircuitBreaker`, `orderCircuitBreaker`): sliding window of 10 calls, 50% failure threshold, 10 s open state. When a service is down, the gateway forwards to `/fallback/products` or `/fallback/orders`.
- **Feign circuit breaker** in Order Service (`productService`), with fallbacks for `getProduct` and `updateStock`.

## Project structure

```
Microservices/
├── eureka-server/
├── config-server/
├── api-gateway/          # routes, CORS, FallbackController
├── product-service/      # controller → service → repository, DTOs, exception handler
├── order-service/        # + client/ProductClient (Feign)
├── docker-compose.yml
└── pom.xml               # parent aggregator
```

## Author

**Fidaa Letaief** · [@fidaaltf58](https://github.com/fidaaltf58)
