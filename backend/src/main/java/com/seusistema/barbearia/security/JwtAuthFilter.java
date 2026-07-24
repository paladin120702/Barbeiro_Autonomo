package com.seusistema.barbearia.security;

import com.seusistema.barbearia.barbeiro.BarbeiroRepository;
import com.seusistema.barbearia.barbeiro.StatusConta;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final BarbeiroRepository barbeiroRepository;

    public JwtAuthFilter(JwtService jwtService, BarbeiroRepository barbeiroRepository) {
        this.jwtService = jwtService;
        this.barbeiroRepository = barbeiroRepository;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            try {
                Long barbeiroId = jwtService.validarEExtrairId(header.substring(7));
                boolean ativo = barbeiroRepository.findById(barbeiroId)
                    .map(b -> b.getStatusConta() == StatusConta.ATIVO)
                    .orElse(false);
                if (ativo) {
                    var auth = new UsernamePasswordAuthenticationToken(barbeiroId, null, List.of());
                    SecurityContextHolder.getContext().setAuthentication(auth);
                } else {
                    SecurityContextHolder.clearContext();
                }
            } catch (Exception e) {
                SecurityContextHolder.clearContext();
            }
        }
        filterChain.doFilter(request, response);
    }
}
