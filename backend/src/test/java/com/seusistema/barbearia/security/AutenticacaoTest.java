package com.seusistema.barbearia.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.barbeiro.Barbeiro;
import com.seusistema.barbearia.barbeiro.BarbeiroRepository;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.barbeiro.StatusConta;
import com.seusistema.barbearia.barbeiro.dto.*;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.*;

class AutenticacaoTest extends IntegrationTestBase {

    @Autowired TestRestTemplate rest;
    @Autowired BarbeiroService barbeiroService;
    @Autowired BarbeiroRepository barbeiroRepository;

    @BeforeEach
    void setUp() {
        barbeiroService.criar(new CriarBarbeiroRequest("João", "joao@b.com", "senha123", "joao"));
    }

    @Test
    void loginValidoRetornaTokenUtilizavel() {
        ResponseEntity<LoginResponse> login = rest.postForEntity("/api/v1/app/login",
            new LoginRequest("joao@b.com", "senha123"), LoginResponse.class);
        assertThat(login.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(login.getBody().token()).isNotBlank();

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(login.getBody().token());
        ResponseEntity<String> agenda = rest.exchange("/api/v1/app/agendamentos?data=2026-08-03",
            HttpMethod.GET, new HttpEntity<>(headers), String.class);
        assertThat(agenda.getStatusCode()).isNotEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void senhaErradaRetorna401() {
        ResponseEntity<Map> resp = rest.postForEntity("/api/v1/app/login",
            new LoginRequest("joao@b.com", "errada"), Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(resp.getBody()).containsKey("erro");
    }

    @Test
    void rotaAppSemTokenRetorna401() {
        ResponseEntity<Map> resp = rest.getForEntity("/api/v1/app/agendamentos?data=2026-08-03", Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(resp.getBody()).containsEntry("erro", "Não autorizado");
    }

    @Test
    void rotaPublicaNaoExigeToken() {
        ResponseEntity<String> resp = rest.getForEntity("/api/v1/public/joao", String.class);
        assertThat(resp.getStatusCode()).isNotEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void loginComEmailEmBrancoRetornaDadosInvalidosComUmCampo() {
        ResponseEntity<Map> resp = rest.postForEntity("/api/v1/app/login",
            new LoginRequest("   ", "senha123"), Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Dados inválidos");

        Map<String, String> campos = (Map<String, String>) resp.getBody().get("campos");
        assertThat(campos).hasSize(1);
        assertThat(campos).containsOnlyKeys("email");
        assertThat(campos.get("email")).isIn(
            "não deve estar em branco",
            "deve ser um endereço de e-mail bem formado"
        );
    }

    @Test
    void preflightDeLoginNaoExigeAutenticacao() {
        HttpHeaders headers = new HttpHeaders();
        headers.set("Origin", "http://localhost:5173");
        headers.set("Access-Control-Request-Method", "POST");
        ResponseEntity<Void> resp = rest.exchange("/api/v1/app/login",
            HttpMethod.OPTIONS, new HttpEntity<>(headers), Void.class);
        assertThat(resp.getStatusCode()).isNotEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(resp.getHeaders().getAccessControlAllowOrigin()).isNotNull();
    }

    @Test
    void tokenDeBarbeiroInativoRetorna401() {
        ResponseEntity<LoginResponse> login = rest.postForEntity("/api/v1/app/login",
            new LoginRequest("joao@b.com", "senha123"), LoginResponse.class);
        assertThat(login.getStatusCode()).isEqualTo(HttpStatus.OK);

        Barbeiro joao = barbeiroRepository.findByEmail("joao@b.com").orElseThrow();
        joao.setStatusConta(StatusConta.INATIVO);
        barbeiroRepository.save(joao);

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(login.getBody().token());
        ResponseEntity<Map> resp = rest.exchange("/api/v1/app/agendamentos?data=2026-08-03",
            HttpMethod.GET, new HttpEntity<>(headers), Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(resp.getBody()).containsEntry("erro", "Não autorizado");
    }
}
