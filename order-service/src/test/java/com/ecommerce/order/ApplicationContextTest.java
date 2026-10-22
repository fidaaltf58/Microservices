package com.ecommerce.order;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * Boots the full application context against an in-memory H2 database, so a broken dependency
 * upgrade or misconfiguration fails the build instead of the deployment.
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:orderdb;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.datasource.driver-class-name=org.h2.Driver",
        "spring.jpa.hibernate.ddl-auto=create-drop",
        "eureka.client.enabled=false"
})
class ApplicationContextTest {

    @Test
    void contextLoads() {
    }
}
