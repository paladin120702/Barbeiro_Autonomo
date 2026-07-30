package com.seusistema.barbearia.horario;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import com.seusistema.barbearia.horario.dto.ExcecaoHorarioDTO;
import com.seusistema.barbearia.horario.dto.HorarioFuncionamentoDTO;
import com.seusistema.barbearia.horario.dto.SalvarExcecaoRequest;
import com.seusistema.barbearia.horario.dto.SalvarHorarioRequest;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

class HorarioCrudTest extends IntegrationTestBase {

    @Autowired BarbeiroService barbeiroService;

    HttpHeaders auth;

    @BeforeEach
    void setUp() {
        barbeiroService.criar(new CriarBarbeiroRequest("João", "joao@b.com", "senha123", "joao"));
        auth = authHeaders("joao@b.com", "senha123");
    }

    @Test
    void criaHorarioEListaComUmItem() {
        ResponseEntity<HorarioFuncionamentoDTO> criado = rest.exchange("/api/v1/app/horarios", HttpMethod.POST,
            new HttpEntity<>(new SalvarHorarioRequest(1, LocalTime.of(9, 0), LocalTime.of(18, 0), null), auth),
            HorarioFuncionamentoDTO.class);
        assertThat(criado.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(criado.getBody().id()).isNotNull();
        assertThat(criado.getBody().ativo()).isTrue();

        ResponseEntity<HorarioFuncionamentoDTO[]> lista = rest.exchange("/api/v1/app/horarios", HttpMethod.GET,
            new HttpEntity<>(auth), HorarioFuncionamentoDTO[].class);
        assertThat(lista.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(lista.getBody()).hasSize(1);
    }

    @Test
    void criarComDiaSemanaInvalidoRetorna400ComCampoDiaSemana() {
        ResponseEntity<Map> resp = rest.exchange("/api/v1/app/horarios", HttpMethod.POST,
            new HttpEntity<>(new SalvarHorarioRequest(7, LocalTime.of(9, 0), LocalTime.of(18, 0), null), auth),
            Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        Map<String, String> campos = (Map<String, String>) resp.getBody().get("campos");
        assertThat(campos).containsKey("diaSemana");
    }

    @Test
    void criarComHoraInicioAposHoraFimRetorna400() {
        ResponseEntity<Map> resp = rest.exchange("/api/v1/app/horarios", HttpMethod.POST,
            new HttpEntity<>(new SalvarHorarioRequest(1, LocalTime.of(18, 0), LocalTime.of(9, 0), null), auth),
            Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Hora de início deve ser antes da hora de fim");
    }

    @Test
    void atualizaJanelaEExcluiHorario() {
        ResponseEntity<HorarioFuncionamentoDTO> criado = rest.exchange("/api/v1/app/horarios", HttpMethod.POST,
            new HttpEntity<>(new SalvarHorarioRequest(1, LocalTime.of(9, 0), LocalTime.of(18, 0), null), auth),
            HorarioFuncionamentoDTO.class);
        Long id = criado.getBody().id();

        ResponseEntity<HorarioFuncionamentoDTO> atualizado = rest.exchange("/api/v1/app/horarios/" + id, HttpMethod.PUT,
            new HttpEntity<>(new SalvarHorarioRequest(1, LocalTime.of(10, 0), LocalTime.of(19, 0), true), auth),
            HorarioFuncionamentoDTO.class);
        assertThat(atualizado.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(atualizado.getBody().horaInicio()).isEqualTo(LocalTime.of(10, 0));
        assertThat(atualizado.getBody().horaFim()).isEqualTo(LocalTime.of(19, 0));

        ResponseEntity<Void> excluido = rest.exchange("/api/v1/app/horarios/" + id, HttpMethod.DELETE,
            new HttpEntity<>(auth), Void.class);
        assertThat(excluido.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        ResponseEntity<HorarioFuncionamentoDTO[]> lista = rest.exchange("/api/v1/app/horarios", HttpMethod.GET,
            new HttpEntity<>(auth), HorarioFuncionamentoDTO[].class);
        assertThat(lista.getBody()).isEmpty();
    }

    @Test
    void criaExcecaoDeFolgaComHorasNulas() {
        ResponseEntity<ExcecaoHorarioDTO> criado = rest.exchange("/api/v1/app/horarios/excecoes", HttpMethod.POST,
            new HttpEntity<>(new SalvarExcecaoRequest(LocalDate.of(2026, 8, 10), false, null, null), auth),
            ExcecaoHorarioDTO.class);
        assertThat(criado.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(criado.getBody().disponivel()).isFalse();
        assertThat(criado.getBody().horaInicio()).isNull();
        assertThat(criado.getBody().horaFim()).isNull();

        ResponseEntity<ExcecaoHorarioDTO[]> lista = rest.exchange("/api/v1/app/horarios/excecoes", HttpMethod.GET,
            new HttpEntity<>(auth), ExcecaoHorarioDTO[].class);
        assertThat(lista.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(lista.getBody()).hasSize(1);
    }

    @Test
    void criaExcecaoEspecialComHoras() {
        ResponseEntity<ExcecaoHorarioDTO> criado = rest.exchange("/api/v1/app/horarios/excecoes", HttpMethod.POST,
            new HttpEntity<>(new SalvarExcecaoRequest(LocalDate.of(2026, 8, 11), true, LocalTime.of(10, 0), LocalTime.of(14, 0)), auth),
            ExcecaoHorarioDTO.class);
        assertThat(criado.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(criado.getBody().disponivel()).isTrue();
        assertThat(criado.getBody().horaInicio()).isEqualTo(LocalTime.of(10, 0));
        assertThat(criado.getBody().horaFim()).isEqualTo(LocalTime.of(14, 0));
    }

    @Test
    void criaExcecaoDuplicadaParaMesmaDataRetorna400() {
        LocalDate data = LocalDate.of(2026, 8, 12);
        rest.exchange("/api/v1/app/horarios/excecoes", HttpMethod.POST,
            new HttpEntity<>(new SalvarExcecaoRequest(data, false, null, null), auth),
            ExcecaoHorarioDTO.class);

        ResponseEntity<Map> resp = rest.exchange("/api/v1/app/horarios/excecoes", HttpMethod.POST,
            new HttpEntity<>(new SalvarExcecaoRequest(data, false, null, null), auth),
            Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(resp.getBody()).containsEntry("erro", "Já existe exceção para esta data");
    }

    @Test
    void excluiExcecao() {
        ResponseEntity<ExcecaoHorarioDTO> criado = rest.exchange("/api/v1/app/horarios/excecoes", HttpMethod.POST,
            new HttpEntity<>(new SalvarExcecaoRequest(LocalDate.of(2026, 8, 13), false, null, null), auth),
            ExcecaoHorarioDTO.class);
        Long id = criado.getBody().id();

        ResponseEntity<Void> excluido = rest.exchange("/api/v1/app/horarios/excecoes/" + id, HttpMethod.DELETE,
            new HttpEntity<>(auth), Void.class);
        assertThat(excluido.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        ResponseEntity<ExcecaoHorarioDTO[]> lista = rest.exchange("/api/v1/app/horarios/excecoes", HttpMethod.GET,
            new HttpEntity<>(auth), ExcecaoHorarioDTO[].class);
        assertThat(lista.getBody()).isEmpty();
    }

    @Test
    void operarHorarioDeOutroBarbeiroRetorna404() {
        ResponseEntity<HorarioFuncionamentoDTO> criado = rest.exchange("/api/v1/app/horarios", HttpMethod.POST,
            new HttpEntity<>(new SalvarHorarioRequest(1, LocalTime.of(9, 0), LocalTime.of(18, 0), null), auth),
            HorarioFuncionamentoDTO.class);
        Long horarioDoJoaoId = criado.getBody().id();

        barbeiroService.criar(new CriarBarbeiroRequest("Maria", "maria@b.com", "senha123", "maria"));
        HttpHeaders authMaria = authHeaders("maria@b.com", "senha123");

        ResponseEntity<Map> put = rest.exchange("/api/v1/app/horarios/" + horarioDoJoaoId, HttpMethod.PUT,
            new HttpEntity<>(new SalvarHorarioRequest(1, LocalTime.of(10, 0), LocalTime.of(19, 0), true), authMaria),
            Map.class);
        assertThat(put.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

        ResponseEntity<Map> delete = rest.exchange("/api/v1/app/horarios/" + horarioDoJoaoId, HttpMethod.DELETE,
            new HttpEntity<>(authMaria), Map.class);
        assertThat(delete.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void operarExcecaoDeOutroBarbeiroRetorna404() {
        ResponseEntity<ExcecaoHorarioDTO> criado = rest.exchange("/api/v1/app/horarios/excecoes", HttpMethod.POST,
            new HttpEntity<>(new SalvarExcecaoRequest(LocalDate.of(2026, 8, 14), false, null, null), auth),
            ExcecaoHorarioDTO.class);
        Long excecaoDoJoaoId = criado.getBody().id();

        barbeiroService.criar(new CriarBarbeiroRequest("Maria", "maria@b.com", "senha123", "maria"));
        HttpHeaders authMaria = authHeaders("maria@b.com", "senha123");

        ResponseEntity<Map> delete = rest.exchange("/api/v1/app/horarios/excecoes/" + excecaoDoJoaoId, HttpMethod.DELETE,
            new HttpEntity<>(authMaria), Map.class);
        assertThat(delete.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }
}
