package com.seusistema.barbearia.common;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import com.seusistema.barbearia.common.ratelimit.RateLimitInterceptor;
import com.seusistema.barbearia.servico.Servico;
import com.seusistema.barbearia.servico.ServicoRepository;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * Clock real (nenhum @Import de ClockDeTeste): usa "amanhã" calculado no mesmo
 * fuso do ClockConfig de produção (America/Sao_Paulo) para nunca cair em "data
 * no passado" nem depender de horário de funcionamento cadastrado — a rota de
 * disponibilidade responde 200 com lista vazia quando não há horário para o
 * dia, o que já basta para os fins deste teste (contagem de requisições, não
 * conteúdo de disponibilidade).
 */
class RateLimitTest extends IntegrationTestBase {

    @Autowired BarbeiroService barbeiroService;
    @Autowired ServicoRepository servicosRepo;
    @Autowired RateLimitInterceptor rateLimitInterceptor;

    Long servicoId;
    String amanha;

    @BeforeEach
    void setUp() {
        rateLimitInterceptor.limpar();

        var ativo = barbeiroService.criar(
            new CriarBarbeiroRequest("João Barbeiro", "joao@b.com", "senha123", "joao"));

        Servico s = new Servico();
        s.setBarbeiroId(ativo.getId());
        s.setNome("Corte");
        s.setPreco(new BigDecimal("50.00"));
        servicoId = servicosRepo.save(s).getId();

        amanha = LocalDate.now(ZoneId.of("America/Sao_Paulo")).plusDays(1).toString();
    }

    private ResponseEntity<Map> disponibilidade() {
        return rest.getForEntity("/api/v1/public/joao/disponibilidade?data=" + amanha, Map.class);
    }

    private ResponseEntity<Map> agendar() {
        Map<String, Object> body = new HashMap<>();
        body.put("servicoId", servicoId);
        body.put("dataHora", amanha + "T14:00:00");
        body.put("nomeCliente", "Maria");
        body.put("telefoneCliente", "11987654321");
        return rest.postForEntity("/api/v1/public/joao/agendamentos", body, Map.class);
    }

    @Test
    void quartaRequisicaoNaMesmaRotaRecebe429ComMensagemPadrao() {
        for (int i = 0; i < 3; i++) {
            assertThat(disponibilidade().getStatusCode()).isNotEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        }

        ResponseEntity<Map> quarta = disponibilidade();
        assertThat(quarta.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        assertThat(quarta.getBody()).containsEntry("erro", "Muitas requisições. Tente novamente em alguns minutos.");
    }

    @Test
    void limiteEhCompartilhadoEntreDisponibilidadeEAgendamentosPorSerOMesmoIp() {
        assertThat(disponibilidade().getStatusCode()).isNotEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        assertThat(disponibilidade().getStatusCode()).isNotEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        assertThat(agendar().getStatusCode()).isNotEqualTo(HttpStatus.TOO_MANY_REQUESTS);

        ResponseEntity<Map> quarta = disponibilidade();
        assertThat(quarta.getStatusCode()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
    }

    @Test
    void rotasPublicasForaDoEscopoDoLimiteNuncaRecebem429() {
        for (int i = 0; i < 5; i++) {
            assertThat(rest.getForEntity("/api/v1/public/joao", String.class).getStatusCode())
                .isNotEqualTo(HttpStatus.TOO_MANY_REQUESTS);
            assertThat(rest.getForEntity("/api/v1/public/joao/servicos", String.class).getStatusCode())
                .isNotEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        }
    }
}
