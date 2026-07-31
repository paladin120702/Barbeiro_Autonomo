package com.seusistema.barbearia.caixa;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.agendamento.Agendamento;
import com.seusistema.barbearia.agendamento.AgendamentoRepository;
import com.seusistema.barbearia.agendamento.FormaPagamento;
import com.seusistema.barbearia.agendamento.StatusAgendamento;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import com.seusistema.barbearia.caixa.dto.CaixaDTO;
import com.seusistema.barbearia.cliente.Cliente;
import com.seusistema.barbearia.cliente.ClienteRepository;
import com.seusistema.barbearia.servico.Servico;
import com.seusistema.barbearia.servico.ServicoRepository;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * Dois serviços de preços distintos (50.00 e 30.00) e agendamentos espalhados em
 * dois dias de 2026-07 (dia1 = 2026-07-18, dia2 = 2026-07-20): dia1 tem os dois
 * CONCLUIDO/PIX (50+50) e o AGENDADO (não entra na soma); dia2 tem o
 * CONCLUIDO/DINHEIRO (30) e o CANCELADO (não entra na soma). Assim o caixa do
 * dia1 fica isolado (só os dois PIX) e o caixa do mês soma os três CONCLUIDO
 * dos dois dias, batendo com os valores do brief (total 130.00, qtde 3).
 */
class CaixaTest extends IntegrationTestBase {

    @Autowired BarbeiroService barbeiroService;
    @Autowired ServicoRepository servicosRepo;
    @Autowired ClienteRepository clientesRepo;
    @Autowired AgendamentoRepository agendamentos;

    Long barbeiroId;
    Servico servico50;
    Servico servico30;
    Cliente cliente;
    HttpHeaders auth;

    @BeforeEach
    void setUp() {
        var ativo = barbeiroService.criar(
            new CriarBarbeiroRequest("João Barbeiro", "joao@b.com", "senha123", "joao"));
        barbeiroId = ativo.getId();
        auth = authHeaders("joao@b.com", "senha123");

        Servico s50 = new Servico();
        s50.setBarbeiroId(barbeiroId);
        s50.setNome("Corte");
        s50.setPreco(new BigDecimal("50.00"));
        servico50 = servicosRepo.save(s50);

        Servico s30 = new Servico();
        s30.setBarbeiroId(barbeiroId);
        s30.setNome("Barba");
        s30.setPreco(new BigDecimal("30.00"));
        servico30 = servicosRepo.save(s30);

        Cliente c = new Cliente();
        c.setBarbeiroId(barbeiroId);
        c.setNome("Cliente Teste");
        c.setTelefone("11999999999");
        cliente = clientesRepo.save(c);

        // Dia 1: 2026-07-18 — dois CONCLUIDO/PIX (servico50) e um AGENDADO (servico50, não conta).
        criarAgendamento(LocalDateTime.of(2026, 7, 18, 10, 0), servico50,
            StatusAgendamento.CONCLUIDO, FormaPagamento.PIX);
        criarAgendamento(LocalDateTime.of(2026, 7, 18, 11, 0), servico50,
            StatusAgendamento.CONCLUIDO, FormaPagamento.PIX);
        criarAgendamento(LocalDateTime.of(2026, 7, 18, 14, 0), servico50,
            StatusAgendamento.AGENDADO, null);

        // Dia 2: 2026-07-20 — um CONCLUIDO/DINHEIRO (servico30) e um CANCELADO (servico30, não conta).
        criarAgendamento(LocalDateTime.of(2026, 7, 20, 10, 0), servico30,
            StatusAgendamento.CONCLUIDO, FormaPagamento.DINHEIRO);
        criarAgendamento(LocalDateTime.of(2026, 7, 20, 11, 0), servico30,
            StatusAgendamento.CANCELADO, null);
    }

    private Agendamento criarAgendamento(LocalDateTime inicio, Servico servico,
            StatusAgendamento status, FormaPagamento formaPagamento) {
        Agendamento a = new Agendamento();
        a.setBarbeiroId(barbeiroId);
        a.setCliente(cliente);
        a.setServico(servico);
        a.setDataHoraInicio(inicio);
        a.setStatus(status);
        a.setFormaPagamento(formaPagamento);
        return agendamentos.save(a);
    }

    @Test
    void caixaDoDiaContaSoOsConcluidosDoDia() {
        ResponseEntity<CaixaDTO> resp = rest.exchange(
            "/api/v1/app/caixa?periodo=dia&data=2026-07-18", HttpMethod.GET,
            new HttpEntity<>(auth), CaixaDTO.class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        CaixaDTO caixa = resp.getBody();
        assertThat(caixa.total()).isEqualByComparingTo("100.00");
        assertThat(caixa.quantidade()).isEqualTo(2);
        assertThat(caixa.porFormaPagamento().get(FormaPagamento.PIX)).isEqualByComparingTo("100.00");
        assertThat(caixa.porFormaPagamento().get(FormaPagamento.DINHEIRO)).isEqualByComparingTo("0");
        assertThat(caixa.porFormaPagamento().get(FormaPagamento.DEBITO)).isEqualByComparingTo("0");
        assertThat(caixa.porFormaPagamento().get(FormaPagamento.CREDITO)).isEqualByComparingTo("0");
    }

    @Test
    void caixaDoMesSomaOsDoisDias() {
        ResponseEntity<CaixaDTO> resp = rest.exchange(
            "/api/v1/app/caixa?periodo=mes&data=2026-07", HttpMethod.GET,
            new HttpEntity<>(auth), CaixaDTO.class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        CaixaDTO caixa = resp.getBody();
        assertThat(caixa.total()).isEqualByComparingTo("130.00");
        assertThat(caixa.quantidade()).isEqualTo(3);
        assertThat(caixa.porFormaPagamento().get(FormaPagamento.PIX)).isEqualByComparingTo("100.00");
        assertThat(caixa.porFormaPagamento().get(FormaPagamento.DINHEIRO)).isEqualByComparingTo("30.00");
        assertThat(caixa.porFormaPagamento().get(FormaPagamento.DEBITO)).isEqualByComparingTo("0");
        assertThat(caixa.porFormaPagamento().get(FormaPagamento.CREDITO)).isEqualByComparingTo("0");
    }

    @Test
    void periodoInvalidoRetorna400() {
        ResponseEntity<Map> resp = rest.exchange(
            "/api/v1/app/caixa?periodo=semana&data=2026-07-18", HttpMethod.GET,
            new HttpEntity<>(auth), Map.class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Período inválido");
    }

    @Test
    void dataMalformadaRetorna400() {
        ResponseEntity<Map> resp = rest.exchange(
            "/api/v1/app/caixa?periodo=mes&data=2026-13", HttpMethod.GET,
            new HttpEntity<>(auth), Map.class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Período inválido");
    }
}
