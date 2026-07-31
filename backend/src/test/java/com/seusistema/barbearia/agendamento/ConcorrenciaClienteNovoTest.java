package com.seusistema.barbearia.agendamento;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.barbeiro.Barbeiro;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import com.seusistema.barbearia.horario.HorarioFuncionamento;
import com.seusistema.barbearia.horario.HorarioFuncionamentoRepository;
import com.seusistema.barbearia.servico.Servico;
import com.seusistema.barbearia.servico.ServicoRepository;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.List;
import java.util.concurrent.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.*;

/**
 * Reproduz o gap de find-then-save sem lock em ClienteService.upsert: duas
 * requisições concorrentes com o MESMO telefone NUNCA visto, mas em slots de
 * horário DIFERENTES, para que a corrida bata só na constraint UNIQUE de
 * "clientes" (barbeiro_id, telefone) e não na exclusion constraint
 * "sem_sobreposicao" (já coberta por ConcorrenciaAgendamentoTest).
 *
 * "Agora" fixado em 2026-08-03T10:30 America/Sao_Paulo (segunda-feira), igual à
 * AgendamentoPublicoTest/DisponibilidadeTest/ConcorrenciaAgendamentoTest.
 */
@Import(ConcorrenciaClienteNovoTest.ClockDeTeste.class)
class ConcorrenciaClienteNovoTest extends IntegrationTestBase {

    @Autowired TestRestTemplate rest;
    @Autowired BarbeiroService barbeiroService;
    @Autowired HorarioFuncionamentoRepository horarios;
    @Autowired ServicoRepository servicosRepo;

    Long servicoId;

    @BeforeEach
    void setUp() {
        Barbeiro ativo = barbeiroService.criar(
            new CriarBarbeiroRequest("João Barbeiro", "joao@b.com", "senha123", "joao"));
        Long barbeiroId = ativo.getId();

        HorarioFuncionamento segunda = new HorarioFuncionamento();
        segunda.setBarbeiroId(barbeiroId);
        segunda.setDiaSemana(1); // segunda-feira
        segunda.setHoraInicio(LocalTime.of(9, 0));
        segunda.setHoraFim(LocalTime.of(18, 0));
        segunda.setAtivo(true);
        horarios.save(segunda);

        Servico s = new Servico();
        s.setBarbeiroId(barbeiroId);
        s.setNome("Corte");
        s.setPreco(new BigDecimal("50.00"));
        servicoId = servicosRepo.save(s).getId();
    }

    @Test
    void duasRequisicoesSimultaneasComMesmoTelefoneNovoEmSlotsDiferentesNuncaViram500() throws Exception {
        var barrier = new CyclicBarrier(2);
        java.util.function.IntFunction<Callable<ResponseEntity<String>>> chamada = i -> () -> {
            var body = new java.util.HashMap<String, Object>();
            body.put("servicoId", servicoId);
            body.put("dataHora", i == 1 ? "2026-08-10T14:00:00" : "2026-08-10T15:00:00");
            body.put("nomeCliente", "Cliente " + i);
            body.put("telefoneCliente", "11999998888"); // mesmo telefone, nunca visto, nas duas threads
            barrier.await();
            return rest.postForEntity("/api/v1/public/joao/agendamentos", body, String.class);
        };

        var executor = Executors.newFixedThreadPool(2);
        List<Future<ResponseEntity<String>>> futures =
            executor.invokeAll(List.of(chamada.apply(1), chamada.apply(2)));
        executor.shutdown();

        var respostas = futures.stream().map(f -> {
            try { return f.get(); } catch (Exception e) { throw new RuntimeException(e); }
        }).toList();

        var statusList = respostas.stream().map(r -> r.getStatusCode().value()).sorted().toList();

        // Slots diferentes: não há disputa pela exclusion constraint de horário, só
        // pela UNIQUE (barbeiro_id, telefone) de clientes. O CyclicBarrier só
        // sincroniza o disparo do HTTP, não garante que as duas transações cheguem
        // juntas até o save() do cliente (mesma ressalva de
        // ConcorrenciaAgendamentoTest): se a transação A commitar o cliente novo
        // antes do findByBarbeiroIdAndTelefone da B rodar, a B enxerga o cliente já
        // existente e também recebe 201 — não há corrida de fato nessa execução, e
        // isso é corretíssimo (mesmo cliente, dois agendamentos). Verificado
        // empiricamente: [201, 409] em execução isolada, [201, 201] sob
        // -Dsurefire.runOrder=reversealphabetical. O único desfecho que a correção
        // deste teste proíbe é 500 — esse sim seria o bug de find-then-save sem lock
        // vazando pro cliente.
        assertThat(statusList).hasSize(2).doesNotContain(500);
        assertThat(statusList).allMatch(s -> s == 201 || s == 409);

        respostas.stream()
            .filter(r -> r.getStatusCode().value() == 409)
            .findFirst()
            .ifPresent(r -> assertThat(r.getBody()).contains("erro"));
    }

    @TestConfiguration
    static class ClockDeTeste {
        @Bean
        @Primary
        Clock clockDeTeste() {
            return Clock.fixed(
                LocalDateTime.of(2026, 8, 3, 10, 30)
                    .atZone(ZoneId.of("America/Sao_Paulo"))
                    .toInstant(),
                ZoneId.of("America/Sao_Paulo"));
        }
    }
}
