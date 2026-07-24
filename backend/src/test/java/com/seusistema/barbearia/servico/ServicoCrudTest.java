package com.seusistema.barbearia.servico;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.agendamento.Agendamento;
import com.seusistema.barbearia.agendamento.AgendamentoRepository;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import com.seusistema.barbearia.cliente.Cliente;
import com.seusistema.barbearia.cliente.ClienteRepository;
import com.seusistema.barbearia.servico.dto.SalvarServicoRequest;
import com.seusistema.barbearia.servico.dto.ServicoDTO;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

class ServicoCrudTest extends IntegrationTestBase {

    @Autowired BarbeiroService barbeiroService;
    @Autowired ClienteRepository clienteRepository;
    @Autowired AgendamentoRepository agendamentoRepository;
    @Autowired ServicoRepository servicoRepository;

    HttpHeaders auth;

    @BeforeEach
    void setUp() {
        barbeiroService.criar(new CriarBarbeiroRequest("João", "joao@b.com", "senha123", "joao"));
        auth = authHeaders("joao@b.com", "senha123");
    }

    @Test
    void criaServicoEListaComUmItem() {
        ResponseEntity<ServicoDTO> criado = rest.exchange("/api/v1/app/servicos", HttpMethod.POST,
            new HttpEntity<>(new SalvarServicoRequest("Corte", new BigDecimal("50.00"), 30), auth),
            ServicoDTO.class);
        assertThat(criado.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(criado.getBody().id()).isNotNull();

        ResponseEntity<ServicoDTO[]> lista = rest.exchange("/api/v1/app/servicos", HttpMethod.GET,
            new HttpEntity<>(auth), ServicoDTO[].class);
        assertThat(lista.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(lista.getBody()).hasSize(1);
    }

    @Test
    void criarSemNomeRetorna400ComCampoNome() {
        ResponseEntity<Map> resp = rest.exchange("/api/v1/app/servicos", HttpMethod.POST,
            new HttpEntity<>(new SalvarServicoRequest(null, new BigDecimal("50.00"), 30), auth),
            Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        Map<String, String> campos = (Map<String, String>) resp.getBody().get("campos");
        assertThat(campos).containsKey("nome");
    }

    @Test
    void atualizaPrecoERefleteNaListagem() {
        ResponseEntity<ServicoDTO> criado = rest.exchange("/api/v1/app/servicos", HttpMethod.POST,
            new HttpEntity<>(new SalvarServicoRequest("Corte", new BigDecimal("50.00"), 30), auth),
            ServicoDTO.class);
        Long id = criado.getBody().id();

        ResponseEntity<ServicoDTO> atualizado = rest.exchange("/api/v1/app/servicos/" + id, HttpMethod.PUT,
            new HttpEntity<>(new SalvarServicoRequest("Corte", new BigDecimal("70.00"), 30), auth),
            ServicoDTO.class);
        assertThat(atualizado.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<ServicoDTO[]> lista = rest.exchange("/api/v1/app/servicos", HttpMethod.GET,
            new HttpEntity<>(auth), ServicoDTO[].class);
        assertThat(lista.getBody()[0].preco()).isEqualByComparingTo("70.00");
    }

    @Test
    void atualizarIdInexistenteRetorna404() {
        ResponseEntity<Map> resp = rest.exchange("/api/v1/app/servicos/99999", HttpMethod.PUT,
            new HttpEntity<>(new SalvarServicoRequest("Corte", new BigDecimal("70.00"), 30), auth),
            Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void excluiServicoEListaFicaVazia() {
        ResponseEntity<ServicoDTO> criado = rest.exchange("/api/v1/app/servicos", HttpMethod.POST,
            new HttpEntity<>(new SalvarServicoRequest("Corte", new BigDecimal("50.00"), 30), auth),
            ServicoDTO.class);
        Long id = criado.getBody().id();

        ResponseEntity<Void> excluido = rest.exchange("/api/v1/app/servicos/" + id, HttpMethod.DELETE,
            new HttpEntity<>(auth), Void.class);
        assertThat(excluido.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        ResponseEntity<ServicoDTO[]> lista = rest.exchange("/api/v1/app/servicos", HttpMethod.GET,
            new HttpEntity<>(auth), ServicoDTO[].class);
        assertThat(lista.getBody()).isEmpty();
    }

    @Test
    void excluirServicoComAgendamentoRetorna400() {
        ResponseEntity<ServicoDTO> criado = rest.exchange("/api/v1/app/servicos", HttpMethod.POST,
            new HttpEntity<>(new SalvarServicoRequest("Corte", new BigDecimal("50.00"), 30), auth),
            ServicoDTO.class);
        Long servicoId = criado.getBody().id();
        Servico servico = servicoRepository.findById(servicoId).orElseThrow();

        Cliente cliente = new Cliente();
        cliente.setBarbeiroId(servico.getBarbeiroId());
        cliente.setNome("Cliente Teste");
        cliente.setTelefone("11999999999");
        clienteRepository.save(cliente);

        Agendamento agendamento = new Agendamento();
        agendamento.setBarbeiroId(servico.getBarbeiroId());
        agendamento.setCliente(cliente);
        agendamento.setServico(servico);
        agendamento.setDataHoraInicio(LocalDateTime.of(2026, 8, 3, 10, 0));
        agendamentoRepository.save(agendamento);

        ResponseEntity<Map> resp = rest.exchange("/api/v1/app/servicos/" + servicoId, HttpMethod.DELETE,
            new HttpEntity<>(auth), Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Serviço possui agendamentos e não pode ser excluído");
    }

    @Test
    void putEDeleteDeOutroBarbeiroRetorna404() {
        ResponseEntity<ServicoDTO> criado = rest.exchange("/api/v1/app/servicos", HttpMethod.POST,
            new HttpEntity<>(new SalvarServicoRequest("Corte", new BigDecimal("50.00"), 30), auth),
            ServicoDTO.class);
        Long servicoDoJoaoId = criado.getBody().id();

        barbeiroService.criar(new CriarBarbeiroRequest("Maria", "maria@b.com", "senha123", "maria"));
        HttpHeaders authMaria = authHeaders("maria@b.com", "senha123");

        ResponseEntity<Map> put = rest.exchange("/api/v1/app/servicos/" + servicoDoJoaoId, HttpMethod.PUT,
            new HttpEntity<>(new SalvarServicoRequest("Corte", new BigDecimal("70.00"), 30), authMaria),
            Map.class);
        assertThat(put.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        ResponseEntity<Map> delete = rest.exchange("/api/v1/app/servicos/" + servicoDoJoaoId, HttpMethod.DELETE,
            new HttpEntity<>(authMaria), Map.class);
        assertThat(delete.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }
}
