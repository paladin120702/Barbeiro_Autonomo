package com.seusistema.barbearia.agendamento;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.ClockFixoTestConfig;
import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.agendamento.dto.AgendamentoCriadoDTO;
import com.seusistema.barbearia.barbeiro.Barbeiro;
import com.seusistema.barbearia.barbeiro.BarbeiroRepository;
import com.seusistema.barbearia.barbeiro.StatusConta;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import com.seusistema.barbearia.cliente.Cliente;
import com.seusistema.barbearia.cliente.ClienteRepository;
import com.seusistema.barbearia.common.ratelimit.RateLimitInterceptor;
import com.seusistema.barbearia.servico.Servico;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

/**
 * "Agora" fixado em 2026-08-03T10:30 America/Sao_Paulo (segunda-feira), igual à
 * DisponibilidadeTest, via Clock @Primary de teste sobrepondo o Clock.system do
 * ClockConfig de produção.
 */
@Import(ClockFixoTestConfig.class)
class AgendamentoPublicoTest extends IntegrationTestBase {

    @Autowired BarbeiroRepository barbeiroRepository;
    @Autowired ClienteRepository clientesRepo;
    @Autowired AgendamentoRepository agendamentos;
    @Autowired RateLimitInterceptor rateLimitInterceptor;

    Long barbeiroId;
    Long servicoId;

    @BeforeEach
    void setUp() {
        rateLimitInterceptor.limpar();
        var fixtura = criarBarbeiroComHorarioSegundaEServicoCorte();
        barbeiroId = fixtura.barbeiroId();
        servicoId = fixtura.servico().getId();
    }

    private Map<String, Object> corpo(Long servicoId, String dataHora, String nome, String telefone) {
        Map<String, Object> body = new HashMap<>();
        body.put("servicoId", servicoId);
        body.put("dataHora", dataHora);
        body.put("nomeCliente", nome);
        body.put("telefoneCliente", telefone);
        return body;
    }

    private ResponseEntity<Map> postar(String slug, Map<String, Object> body) {
        return rest.postForEntity("/api/v1/public/" + slug + "/agendamentos", body, Map.class);
    }

    @Test
    void postValidoCriaAgendamentoECliente() {
        ResponseEntity<AgendamentoCriadoDTO> resp = rest.postForEntity(
            "/api/v1/public/joao/agendamentos",
            corpo(servicoId, "2026-08-10T14:00:00", "Maria", "(11) 98765-4321"),
            AgendamentoCriadoDTO.class);

        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(resp.getBody().dataHoraInicio()).isEqualTo(LocalDateTime.of(2026, 8, 10, 14, 0));
        assertThat(resp.getBody().nomeCliente()).isEqualTo("Maria");

        List<Agendamento> todos = agendamentos.findAll();
        assertThat(todos).hasSize(1);
        Agendamento salvo = todos.get(0);
        assertThat(salvo.getStatus()).isEqualTo(StatusAgendamento.AGENDADO);
        assertThat(salvo.getDataHoraFim()).isEqualTo(LocalDateTime.of(2026, 8, 10, 15, 0));

        Cliente cliente = clientesRepo.findByBarbeiroIdAndTelefone(barbeiroId, "11987654321").orElseThrow();
        assertThat(cliente.getNome()).isEqualTo("Maria");
    }

    @Test
    void mesmoTelefoneComMascaraDiferenteNaoDuplicaCliente() {
        postar("joao", corpo(servicoId, "2026-08-10T14:00:00", "Maria", "(11) 98765-4321"));
        ResponseEntity<Map> segunda = postar("joao", corpo(servicoId, "2026-08-10T15:00:00", "Maria Silva", "11987654321"));

        assertThat(segunda.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(clientesRepo.findAll()).hasSize(1);
        Cliente cliente = clientesRepo.findByBarbeiroIdAndTelefone(barbeiroId, "11987654321").orElseThrow();
        assertThat(cliente.getNome()).isEqualTo("Maria Silva");
    }

    @Test
    void telefoneComNoveDigitosRetorna400() {
        ResponseEntity<Map> resp = postar("joao", corpo(servicoId, "2026-08-10T14:00:00", "Maria", "987654321"));
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Telefone inválido");
    }

    @Test
    void dataHoraForaDeHoraCheiaRetorna400() {
        ResponseEntity<Map> resp = postar("joao", corpo(servicoId, "2026-08-10T14:30:00", "Maria", "11987654321"));
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Horário deve ser em hora cheia");
    }

    @Test
    void slotJaOcupadoRetorna400() {
        Cliente c = new Cliente();
        c.setBarbeiroId(barbeiroId);
        c.setNome("Outro Cliente");
        c.setTelefone("11911111111");
        c = clientesRepo.save(c);

        Servico servico = servicos.findById(servicoId).orElseThrow();

        Agendamento existente = new Agendamento();
        existente.setBarbeiroId(barbeiroId);
        existente.setCliente(c);
        existente.setServico(servico);
        existente.setDataHoraInicio(LocalDateTime.of(2026, 8, 10, 14, 0));
        agendamentos.save(existente);

        ResponseEntity<Map> resp = postar("joao", corpo(servicoId, "2026-08-10T14:00:00", "Maria", "11987654321"));
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Horário indisponível");
    }

    @Test
    void servicoDeOutroBarbeiroRetorna404() {
        Barbeiro outro = barbeiroService.criar(
            new CriarBarbeiroRequest("Pedro Barbeiro", "pedro@b.com", "senha123", "pedro"));
        Servico servicoDoPedro = new Servico();
        servicoDoPedro.setBarbeiroId(outro.getId());
        servicoDoPedro.setNome("Barba");
        servicoDoPedro.setPreco(new BigDecimal("30.00"));
        Long idServicoDoPedro = servicos.save(servicoDoPedro).getId();

        ResponseEntity<Map> resp = postar("joao", corpo(idServicoDoPedro, "2026-08-10T14:00:00", "Maria", "11987654321"));
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(resp.getBody()).containsEntry("erro", "Serviço não encontrado");
    }

    @Test
    void dataHoraNoPassadoRetorna400() {
        ResponseEntity<Map> resp = postar("joao", corpo(servicoId, "2026-07-27T14:00:00", "Maria", "11987654321"));
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Data fora do período de agendamento");
    }

    @Test
    void slugInativoRetorna404() {
        Barbeiro inativo = barbeiroService.criar(
            new CriarBarbeiroRequest("Pedro Barbeiro", "pedro@b.com", "senha123", "pedro"));
        inativo.setStatusConta(StatusConta.INATIVO);
        barbeiroRepository.save(inativo);

        ResponseEntity<Map> resp = postar("pedro", corpo(servicoId, "2026-08-10T14:00:00", "Maria", "11987654321"));
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void dataHoraMalformadaRetorna400() {
        ResponseEntity<Map> resp = postar("joao", corpo(servicoId, "não-é-uma-data", "Maria", "11987654321"));
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Data/hora inválida");
    }
}
