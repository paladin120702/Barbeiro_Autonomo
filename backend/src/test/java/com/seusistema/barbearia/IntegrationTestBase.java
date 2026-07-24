package com.seusistema.barbearia;

import com.seusistema.barbearia.barbeiro.dto.LoginRequest;
import com.seusistema.barbearia.barbeiro.dto.LoginResponse;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
public abstract class IntegrationTestBase {

    static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>("postgres:16-alpine");

    static {
        POSTGRES.start();
    }

    @Autowired protected JdbcTemplate jdbc;

    @Autowired protected TestRestTemplate rest;

    protected HttpHeaders authHeaders(String email, String senha) {
        ResponseEntity<LoginResponse> login = rest.postForEntity("/api/v1/app/login",
            new LoginRequest(email, senha), LoginResponse.class);
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(login.getBody().token());
        return headers;
    }

    // O container é estático e compartilhado por toda a suíte, então a limpeza é
    // propriedade da base, não de cada teste. CASCADE dispensa ordem, para que
    // acrescentar tabela depois não quebre em silêncio.
    @BeforeEach
    void limparBanco() {
        jdbc.update("""
            TRUNCATE agendamentos, excecoes_horario, horario_funcionamento,
                     clientes, servicos, barbeiros RESTART IDENTITY CASCADE
            """);
    }

    @DynamicPropertySource
    static void datasource(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }
}
