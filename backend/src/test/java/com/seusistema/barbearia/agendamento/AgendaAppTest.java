package com.seusistema.barbearia.agendamento;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.agendamento.dto.AgendamentoDTO;
import com.seusistema.barbearia.agendamento.dto.CancelarRequest;
import com.seusistema.barbearia.agendamento.dto.DisponibilidadeDTO;
import com.seusistema.barbearia.agendamento.dto.FinalizarRequest;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import com.seusistema.barbearia.cliente.Cliente;
import com.seusistema.barbearia.cliente.ClienteRepository;
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
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * "Agora" fixado em 2026-08-03T10:30 America/Sao_Paulo (segunda-feira), igual à
 * DisponibilidadeTest/AgendamentoPublicoTest, via Clock @Primary de teste
 * sobrepondo o Clock.system do ClockConfig de produção. Os agendamentos são
 * criados em 2026-08-10 (também segunda-feira), dentro do horário de
 * funcionamento configurado (9h-18h) e no futuro em relação ao "agora" fixado.
 */
@Import(AgendaAppTest.ClockDeTeste.class)
class AgendaAppTest extends IntegrationTestBase {

    @Autowired BarbeiroService barbeiroService;
    @Autowired HorarioFuncionamentoRepository horarios;
    @Autowired ServicoRepository servicosRepo;
    @Autowired ClienteRepository clientesRepo;
    @Autowired AgendamentoRepository agendamentos;

    Long barbeiroId;
    Servico servico;
    Cliente cliente;
    HttpHeaders auth;

    @BeforeEach
    void setUp() {
        var ativo = barbeiroService.criar(
            new CriarBarbeiroRequest("João Barbeiro", "joao@b.com", "senha123", "joao"));
        barbeiroId = ativo.getId();
        auth = authHeaders("joao@b.com", "senha123");

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
        servico = servicosRepo.save(s);

        Cliente c = new Cliente();
        c.setBarbeiroId(barbeiroId);
        c.setNome("Cliente Teste");
        c.setTelefone("11999999999");
        cliente = clientesRepo.save(c);
    }

    private Agendamento criarAgendamento(LocalDateTime inicio) {
        Agendamento a = new Agendamento();
        a.setBarbeiroId(barbeiroId);
        a.setCliente(cliente);
        a.setServico(servico);
        a.setDataHoraInicio(inicio);
        return agendamentos.save(a);
    }

    @Test
    void listaDoDiaRetornaDoisItensOrdenadosComServicoEClienteTelefone() {
        criarAgendamento(LocalDateTime.of(2026, 8, 10, 15, 0));
        criarAgendamento(LocalDateTime.of(2026, 8, 10, 10, 0));

        ResponseEntity<AgendamentoDTO[]> resp = rest.exchange(
            "/api/v1/app/agendamentos?data=2026-08-10", HttpMethod.GET,
            new HttpEntity<>(auth), AgendamentoDTO[].class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        List<AgendamentoDTO> lista = List.of(resp.getBody());
        assertThat(lista).hasSize(2);
        assertThat(lista.get(0).dataHoraInicio()).isEqualTo(LocalDateTime.of(2026, 8, 10, 10, 0));
        assertThat(lista.get(1).dataHoraInicio()).isEqualTo(LocalDateTime.of(2026, 8, 10, 15, 0));
        assertThat(lista.get(0).servicoNome()).isEqualTo("Corte");
        assertThat(lista.get(0).clienteTelefone()).isEqualTo("11999999999");
    }

    @Test
    void listaDeOutroDiaRetornaVazia() {
        criarAgendamento(LocalDateTime.of(2026, 8, 10, 10, 0));

        ResponseEntity<AgendamentoDTO[]> resp = rest.exchange(
            "/api/v1/app/agendamentos?data=2026-08-11", HttpMethod.GET,
            new HttpEntity<>(auth), AgendamentoDTO[].class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody()).isEmpty();
    }

    @Test
    void finalizarComFormaPagamentoRetorna200EAtualizaBanco() {
        Agendamento a = criarAgendamento(LocalDateTime.of(2026, 8, 10, 10, 0));

        ResponseEntity<AgendamentoDTO> resp = rest.exchange(
            "/api/v1/app/agendamentos/" + a.getId() + "/finalizar", HttpMethod.POST,
            new HttpEntity<>(new FinalizarRequest(FormaPagamento.PIX), auth), AgendamentoDTO.class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);

        Agendamento salvo = agendamentos.findById(a.getId()).orElseThrow();
        assertThat(salvo.getStatus()).isEqualTo(StatusAgendamento.CONCLUIDO);
        assertThat(salvo.getFormaPagamento()).isEqualTo(FormaPagamento.PIX);
    }

    @Test
    void finalizarAgendamentoJaConcluidoRetorna400() {
        Agendamento a = criarAgendamento(LocalDateTime.of(2026, 8, 10, 10, 0));
        a.setStatus(StatusAgendamento.CONCLUIDO);
        agendamentos.save(a);

        ResponseEntity<Map> resp = rest.exchange(
            "/api/v1/app/agendamentos/" + a.getId() + "/finalizar", HttpMethod.POST,
            new HttpEntity<>(new FinalizarRequest(FormaPagamento.PIX), auth), Map.class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Agendamento não pode ser finalizado");
    }

    @Test
    void cancelarComNaoCompareceuRetorna200EReflitaEDevolveSlotNaDisponibilidadePublica() {
        Agendamento a = criarAgendamento(LocalDateTime.of(2026, 8, 10, 10, 0));

        ResponseEntity<Map> disponibilidadeAntes = rest.getForEntity(
            "/api/v1/public/joao/disponibilidade?data=2026-08-10", Map.class);
        assertThat(((List<String>) disponibilidadeAntes.getBody().get("horarios"))).doesNotContain("10:00");

        ResponseEntity<AgendamentoDTO> resp = rest.exchange(
            "/api/v1/app/agendamentos/" + a.getId() + "/cancelar", HttpMethod.POST,
            new HttpEntity<>(new CancelarRequest(StatusAgendamento.NAO_COMPARECEU), auth), AgendamentoDTO.class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);

        Agendamento salvo = agendamentos.findById(a.getId()).orElseThrow();
        assertThat(salvo.getStatus()).isEqualTo(StatusAgendamento.NAO_COMPARECEU);

        ResponseEntity<DisponibilidadeDTO> disponibilidadeDepois = rest.getForEntity(
            "/api/v1/public/joao/disponibilidade?data=2026-08-10", DisponibilidadeDTO.class);
        assertThat(disponibilidadeDepois.getBody().horarios()).contains("10:00");
    }

    @Test
    void cancelarComStatusInvalidoRetorna400() {
        Agendamento a = criarAgendamento(LocalDateTime.of(2026, 8, 10, 10, 0));

        ResponseEntity<Map> resp = rest.exchange(
            "/api/v1/app/agendamentos/" + a.getId() + "/cancelar", HttpMethod.POST,
            new HttpEntity<>(new CancelarRequest(StatusAgendamento.CONCLUIDO), auth), Map.class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Status de cancelamento inválido");
    }

    @Test
    void agendamentoDeOutroBarbeiroRetorna404() {
        Agendamento a = criarAgendamento(LocalDateTime.of(2026, 8, 10, 10, 0));

        barbeiroService.criar(new CriarBarbeiroRequest("Maria", "maria@b.com", "senha123", "maria"));
        HttpHeaders authMaria = authHeaders("maria@b.com", "senha123");

        ResponseEntity<Map> finalizar = rest.exchange(
            "/api/v1/app/agendamentos/" + a.getId() + "/finalizar", HttpMethod.POST,
            new HttpEntity<>(new FinalizarRequest(FormaPagamento.PIX), authMaria), Map.class);
        assertThat(finalizar.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        ResponseEntity<Map> cancelar = rest.exchange(
            "/api/v1/app/agendamentos/" + a.getId() + "/cancelar", HttpMethod.POST,
            new HttpEntity<>(new CancelarRequest(StatusAgendamento.CANCELADO), authMaria), Map.class);
        assertThat(cancelar.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
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
