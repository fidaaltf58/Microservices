package com.ecommerce.order.client;

import com.ecommerce.order.dto.ProductDTO;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.web.bind.annotation.*;

@FeignClient(
        name = "product-service",
        url = "${product.service.url:http://localhost:8081}"  // ← ADD THIS
)
public interface ProductClient {

    @GetMapping("/api/products/{id}")
    @CircuitBreaker(name = "productService", fallbackMethod = "getProductFallback")
    ProductDTO getProductById(@PathVariable("id") Long id);

    @PatchMapping("/api/products/{id}/stock")
    @CircuitBreaker(name = "productService", fallbackMethod = "updateStockFallback")
    void updateStock(@PathVariable("id") Long id, @RequestParam("quantity") Integer quantity);

    default ProductDTO getProductFallback(Long id, Exception e) {
        ProductDTO fallbackProduct = new ProductDTO();
        fallbackProduct.setId(id);
        fallbackProduct.setName("Product Unavailable");
        fallbackProduct.setPrice(java.math.BigDecimal.ZERO);
        fallbackProduct.setStockQuantity(0);
        return fallbackProduct;
    }

    default void updateStockFallback(Long id, Integer quantity, Exception e) {
        // Log the error or handle fallback
        throw new RuntimeException("Product service unavailable for stock update");
    }
}