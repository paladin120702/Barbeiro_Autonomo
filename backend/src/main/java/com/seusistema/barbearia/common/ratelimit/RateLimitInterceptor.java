package com.seusistema.barbearia.common.ratelimit;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.time.Duration;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class RateLimitInterceptor implements HandlerInterceptor {
    private final Map<String, Bucket> cache = new ConcurrentHashMap<>();

    private Bucket criarBucket() {
        Bandwidth limite = Bandwidth.classic(3, Refill.intervally(3, Duration.ofMinutes(10)));
        return Bucket.builder().addLimit(limite).build();
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws java.io.IOException {
        String ip = request.getRemoteAddr();
        Bucket bucket = cache.computeIfAbsent(ip, k -> criarBucket());
        if (bucket.tryConsume(1)) return true;
        response.setStatus(429);
        response.setContentType("application/json;charset=UTF-8");
        response.getWriter().write("{\"erro\": \"Muitas requisições. Tente novamente em alguns minutos.\"}");
        return false;
    }

    public void limpar() {
        cache.clear();
    }
}
