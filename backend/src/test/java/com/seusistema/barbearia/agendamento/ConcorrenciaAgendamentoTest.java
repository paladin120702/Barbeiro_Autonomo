package com.seusistema.barbearia.agendamento;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.ClockFixoTestConfig;
import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.common.ratelimit.RateLimitInterceptor;
import java.util.List;
import java.util.concurrent.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.context.annotation.Import;
import org.springframework.http.*;

/**
 * "Agora" fixado em 2026-08-03T10:30 America/Sao_Paulo (segunda-feira), igual à
 * AgendamentoPublicoTest/DisponibilidadeTest.
 */
@Import(ClockFixoTestConfig.class)
class ConcorrenciaAgendamentoTest extends IntegrationTestBase {

    @Autowired TestRestTemplate rest;
    @Autowired RateLimitInterceptor rateLimitInterceptor;

    Long servicoId;

    @BeforeEach
    void setUp() {
        rateLimitInterceptor.limpar();
        var fixtura = criarBarbeiroComHorarioSegundaEServicoCorte();
        servicoId = fixtura.servico().getId();
    }

    @Test
    void duasRequisicoesSimultaneasParaOMesmoSlotUmaGanhaOutraRecebe409() throws Exception {
        var barrier = new CyclicBarrier(2);
        java.util.function.IntFunction<Callable<ResponseEntity<String>>> chamada = i -> () -> {
            var body = new java.util.HashMap<String, Object>();
            body.put("servicoId", servicoId);
            body.put("dataHora", "2026-08-10T14:00:00");
            body.put("nomeCliente", "Cliente " + i);
            body.put("telefoneCliente", "1198765432" + i); // 11 dígitos, distinto por thread
            barrier.await();
            return rest.postForEntity("/api/v1/public/joao/agendamentos", body, String.class);
        };

        var executor = Executors.newFixedThreadPool(2);
        List<Future<ResponseEntity<String>>> futures =
            executor.invokeAll(List.of(chamada.apply(1), chamada.apply(2)));
        executor.shutdown();

        var statusList = futures.stream().map(f -> {
            try { return f.get().getStatusCode().value(); }
            catch (Exception e) { throw new RuntimeException(e); }
        }).sorted().toList();

        // O CyclicBarrier só sincroniza o disparo do HTTP, não garante que as duas
        // transações cheguem juntas até o INSERT: se a requisição A commitar antes da
        // checagem de disponibilidade da B rodar, B recebe 400 "Horário indisponível"
        // (via horariosLivres) em vez de correr até a constraint e receber 409. Ambos
        // os desfechos previnem o double-booking corretamente — exigir sempre 409
        // torna o teste flaky sob carga real (verificado empiricamente: falha em
        // execução da suíte completa, nunca isoladamente rodado sozinho).
        assertThat(statusList).hasSize(2).contains(201);
        var respostaPerdedora = futures.stream().map(f -> {
            try { return f.get(); } catch (Exception e) { throw new RuntimeException(e); }
        }).filter(r -> r.getStatusCode().value() != 201).findFirst().orElseThrow();
        int statusPerdedor = respostaPerdedora.getStatusCode().value();
        assertThat(statusPerdedor).isIn(400, 409);
        if (statusPerdedor == 409) {
            assertThat(respostaPerdedora.getBody()).contains("Esse horário acabou de ser reservado");
        } else {
            assertThat(respostaPerdedora.getBody()).contains("Horário indisponível");
        }
    }
}
