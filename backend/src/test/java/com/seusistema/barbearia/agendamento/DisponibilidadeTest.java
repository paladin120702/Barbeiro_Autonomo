package com.seusistema.barbearia.agendamento;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.agendamento.dto.DisponibilidadeDTO;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import com.seusistema.barbearia.cliente.Cliente;
import com.seusistema.barbearia.cliente.ClienteRepository;
import com.seusistema.barbearia.horario.ExcecaoHorario;
import com.seusistema.barbearia.horario.ExcecaoHorarioRepository;
import com.seusistema.barbearia.horario.HorarioFuncionamento;
import com.seusistema.barbearia.horario.HorarioFuncionamentoRepository;
import com.seusistema.barbearia.servico.Servico;
import com.seusistema.barbearia.servico.ServicoRepository;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * "Agora" fixado em 2026-08-03T10:30 America/Sao_Paulo (segunda-feira) via
 * Clock @Primary de teste, sobrepondo o Clock.system do ClockConfig de produção.
 */
@Import(DisponibilidadeTest.ClockDeTeste.class)
class DisponibilidadeTest extends IntegrationTestBase {

    @Autowired BarbeiroService barbeiroService;
    @Autowired HorarioFuncionamentoRepository horarios;
    @Autowired ExcecaoHorarioRepository excecoes;
    @Autowired AgendamentoRepository agendamentos;
    @Autowired ClienteRepository clientesRepo;
    @Autowired ServicoRepository servicosRepo;

    Long barbeiroId;
    Cliente cliente;
    Servico servico;

    @BeforeEach
    void setUp() {
        var ativo = barbeiroService.criar(new CriarBarbeiroRequest("João Barbeiro", "joao@b.com", "senha123", "joao"));
        barbeiroId = ativo.getId();

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

    private void criarAgendamento(LocalDateTime inicio, StatusAgendamento status) {
        Agendamento a = new Agendamento();
        a.setBarbeiroId(barbeiroId);
        a.setCliente(cliente);
        a.setServico(servico);
        a.setDataHoraInicio(inicio);
        a.setStatus(status);
        agendamentos.save(a);
    }

    private ResponseEntity<DisponibilidadeDTO> buscar(String slug, String data) {
        return rest.getForEntity("/api/v1/public/" + slug + "/disponibilidade?data=" + data, DisponibilidadeDTO.class);
    }

    @Test
    void diaFuturoSemAgendamentosRetornaSlotsDeHoraCheia() {
        ResponseEntity<DisponibilidadeDTO> resp = buscar("joao", "2026-08-10"); // segunda-feira futura
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody().horarios()).containsExactly(
            "09:00", "10:00", "11:00", "12:00", "13:00", "14:00", "15:00", "16:00", "17:00");
    }

    @Test
    void agendamentoAgendadoOcupaSlotECanceladoNaoOcupa() {
        criarAgendamento(LocalDateTime.of(2026, 8, 10, 14, 0), StatusAgendamento.AGENDADO);
        criarAgendamento(LocalDateTime.of(2026, 8, 10, 15, 0), StatusAgendamento.CANCELADO);

        ResponseEntity<DisponibilidadeDTO> resp = buscar("joao", "2026-08-10");
        assertThat(resp.getBody().horarios()).doesNotContain("14:00");
        assertThat(resp.getBody().horarios()).contains("15:00");
    }

    @Test
    void excecaoDeFolgaSobrepoeHorarioNormalERetornaVazia() {
        ExcecaoHorario excecao = new ExcecaoHorario();
        excecao.setBarbeiroId(barbeiroId);
        excecao.setData(LocalDate.of(2026, 8, 17)); // segunda-feira, teria horário normal
        excecao.setDisponivel(false);
        excecoes.save(excecao);

        ResponseEntity<DisponibilidadeDTO> resp = buscar("joao", "2026-08-17");
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody().horarios()).isEmpty();
    }

    @Test
    void excecaoComJanelaPropriaSubstituiHorarioNormal() {
        ExcecaoHorario excecao = new ExcecaoHorario();
        excecao.setBarbeiroId(barbeiroId);
        excecao.setData(LocalDate.of(2026, 8, 18)); // terça-feira, sem horário cadastrado
        excecao.setDisponivel(true);
        excecao.setHoraInicio(LocalTime.of(10, 0));
        excecao.setHoraFim(LocalTime.of(14, 0));
        excecoes.save(excecao);

        ResponseEntity<DisponibilidadeDTO> resp = buscar("joao", "2026-08-18");
        assertThat(resp.getBody().horarios()).containsExactly("10:00", "11:00", "12:00", "13:00");
    }

    @Test
    void hojeRemoveSlotsComInicioAnteriorOuIgualAoHorarioAtual() {
        ResponseEntity<DisponibilidadeDTO> resp = buscar("joao", "2026-08-03"); // hoje, agora fixado em 10:30
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody().horarios()).containsExactly(
            "11:00", "12:00", "13:00", "14:00", "15:00", "16:00", "17:00");
    }

    @Test
    void diaSemHorarioCadastradoRetornaVazia() {
        ResponseEntity<DisponibilidadeDTO> resp = buscar("joao", "2026-08-09"); // domingo, sem horário
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody().horarios()).isEmpty();
    }

    @Test
    void dataNoPassadoRetorna400() {
        ResponseEntity<Map> resp = rest.getForEntity(
            "/api/v1/public/joao/disponibilidade?data=2026-08-02", Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Data fora do período de agendamento");
    }

    @Test
    void dataAlemDeTrintaDiasRetorna400() {
        ResponseEntity<Map> resp = rest.getForEntity(
            "/api/v1/public/joao/disponibilidade?data=2026-09-03", Map.class); // hoje + 31 dias
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Data fora do período de agendamento");
    }

    @Test
    void parametroDataAusenteRetorna400() {
        ResponseEntity<Map> resp = rest.getForEntity(
            "/api/v1/public/joao/disponibilidade", Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Parâmetro inválido");
    }

    @Test
    void parametroDataMalformadoRetorna400() {
        ResponseEntity<Map> resp = rest.getForEntity(
            "/api/v1/public/joao/disponibilidade?data=abc", Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Parâmetro inválido");
    }

    @Test
    void slugInexistenteRetorna404() {
        ResponseEntity<Map> resp = rest.getForEntity(
            "/api/v1/public/nao-existe/disponibilidade?data=2026-08-10", Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void janelaQuebradaArredondaInicioERespeitaSlotInteiro() {
        HorarioFuncionamento quarta = new HorarioFuncionamento();
        quarta.setBarbeiroId(barbeiroId);
        quarta.setDiaSemana(3); // quarta-feira
        quarta.setHoraInicio(LocalTime.of(9, 30));
        quarta.setHoraFim(LocalTime.of(12, 30));
        quarta.setAtivo(true);
        horarios.save(quarta);

        ResponseEntity<DisponibilidadeDTO> resp = buscar("joao", "2026-08-05"); // quarta-feira futura
        assertThat(resp.getBody().horarios()).containsExactly("10:00", "11:00");
    }

    @TestConfiguration
    static class ClockDeTeste {
        // Nome de método diferente de "clock": com o mesmo nome, o Spring Boot 3.4
        // (allow-bean-definition-overriding=false por padrão) lança
        // BeanDefinitionOverrideException antes mesmo de chegar a resolver @Primary
        // — a colisão é pelo nome do bean, não pelo tipo. Nomes distintos deixam os
        // dois beans Clock coexistirem e o @Primary desempata por tipo na injeção.
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
