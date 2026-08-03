package com.seusistema.barbearia;

import com.seusistema.barbearia.barbeiro.Barbeiro;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import com.seusistema.barbearia.barbeiro.dto.LoginRequest;
import com.seusistema.barbearia.barbeiro.dto.LoginResponse;
import com.seusistema.barbearia.horario.HorarioFuncionamento;
import com.seusistema.barbearia.horario.HorarioFuncionamentoRepository;
import com.seusistema.barbearia.servico.Servico;
import com.seusistema.barbearia.servico.ServicoRepository;
import java.math.BigDecimal;
import java.time.LocalTime;
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

    @Autowired protected BarbeiroService barbeiroService;

    @Autowired protected HorarioFuncionamentoRepository horarios;

    @Autowired protected ServicoRepository servicos;

    protected HttpHeaders authHeaders(String email, String senha) {
        ResponseEntity<LoginResponse> login = rest.postForEntity("/api/v1/app/login",
            new LoginRequest(email, senha), LoginResponse.class);
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(login.getBody().token());
        return headers;
    }

    protected record FixturaPadrao(Long barbeiroId, Servico servico) {}

    /**
     * Cria o barbeiro "João Barbeiro" (joao@b.com/senha123, slug "joao") com
     * horário de funcionamento de segunda 09:00-18:00 e um serviço "Corte" de
     * R$50,00. Fixture repetida em ConcorrenciaClienteNovoTest,
     * ConcorrenciaAgendamentoTest, AgendaAppTest, DisponibilidadeTest e
     * AgendamentoPublicoTest — extraída aqui para eliminar a duplicação.
     */
    protected FixturaPadrao criarBarbeiroComHorarioSegundaEServicoCorte() {
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
        Servico salvo = servicos.save(s);

        return new FixturaPadrao(barbeiroId, salvo);
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
