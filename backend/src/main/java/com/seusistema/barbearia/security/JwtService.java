package com.seusistema.barbearia.security;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Date;
import javax.crypto.SecretKey;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class JwtService {

    private final SecretKey key;
    private final Duration expiracao;

    public JwtService(@Value("${barbearia.jwt.secret}") String secret,
                      @Value("${barbearia.jwt.expiracao-dias}") long expiracaoDias) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expiracao = Duration.ofDays(expiracaoDias);
    }

    public String gerar(Long barbeiroId) {
        Date agora = new Date();
        return Jwts.builder()
            .subject(String.valueOf(barbeiroId))
            .issuedAt(agora)
            .expiration(new Date(agora.getTime() + expiracao.toMillis()))
            .signWith(key)
            .compact();
    }

    public Long validarEExtrairId(String token) {
        return Long.valueOf(Jwts.parser().verifyWith(key).build()
            .parseSignedClaims(token).getPayload().getSubject());
    }
}
