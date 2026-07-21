package com.seusistema.barbearia.common;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.seusistema.barbearia.common.exception.*;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.ResponseEntity;

class GlobalExceptionHandlerTest {

    GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void conflitoDeHorarioVira409ComMensagemAmigavel() {
        var ex = new DataIntegrityViolationException(
            "ERROR: conflicting key value violates exclusion constraint \"sem_sobreposicao\"");
        ResponseEntity<Map<String, Object>> resp = handler.handleConflito(ex);
        assertThat(resp.getStatusCode().value()).isEqualTo(409);
        assertThat(resp.getBody()).containsEntry("erro", "Esse horário acabou de ser reservado. Escolha outro.");
    }

    @Test
    void outraViolacaoDeIntegridadeEhRelancada() {
        var ex = new DataIntegrityViolationException("violates unique constraint \"barbeiros_email_key\"");
        assertThatThrownBy(() -> handler.handleConflito(ex)).isSameAs(ex);
    }

    @Test
    void recursoNaoEncontradoVira404() {
        var resp = handler.handleNaoEncontrado(new RecursoNaoEncontradoException("Barbeiro não encontrado"));
        assertThat(resp.getStatusCode().value()).isEqualTo(404);
        assertThat(resp.getBody()).containsEntry("erro", "Barbeiro não encontrado");
    }

    @Test
    void regraDeNegocioVira400() {
        var resp = handler.handleRegra(new RegraDeNegocioException("Horário indisponível"));
        assertThat(resp.getStatusCode().value()).isEqualTo(400);
        assertThat(resp.getBody()).containsEntry("erro", "Horário indisponível");
    }
}
