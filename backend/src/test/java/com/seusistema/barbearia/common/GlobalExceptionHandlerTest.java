package com.seusistema.barbearia.common;

import static org.assertj.core.api.Assertions.assertThat;

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

    /**
     * O plano previa relançar aqui. Relançar de dentro de um @ExceptionHandler faz
     * a exceção escapar do DispatcherServlet sem passar pelo catch-all, devolvendo
     * um corpo sem a chave "erro" — comprovado em GlobalExceptionHandlerRoteamentoTest.
     * Vira 500 genérico, com a exceção real só no log.
     */
    @Test
    void outraViolacaoDeIntegridadeVira500Generico() {
        var ex = new DataIntegrityViolationException("violates unique constraint \"barbeiros_email_key\"");
        var resp = handler.handleConflito(ex);
        assertThat(resp.getStatusCode().value()).isEqualTo(500);
        assertThat(resp.getBody()).containsEntry("erro", "Erro inesperado. Tente novamente.");
        assertThat(resp.getBody().get("erro").toString()).doesNotContain("barbeiros_email_key");
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

    @Test
    void excecaoNaoMapeadaVira500ComMensagemGenericaESemVazarDetalhe() {
        var resp = handler.handleInesperado(
            new IllegalStateException("conexão jdbc:postgresql://interno:5432 recusada"));
        assertThat(resp.getStatusCode().value()).isEqualTo(500);
        assertThat(resp.getBody()).containsEntry("erro", "Erro inesperado. Tente novamente.");
        assertThat(resp.getBody().get("erro").toString()).doesNotContain("jdbc");
    }

    /**
     * Sem o requireNonNullElse, Map.of lança NPE aqui e o 404 vira um 500 sem
     * chave "erro" — justamente o que o catch-all existe para evitar.
     */
    @Test
    void mensagemNulaNaoDerrubaOHandler() {
        var naoEncontrado = handler.handleNaoEncontrado(new RecursoNaoEncontradoException(null));
        assertThat(naoEncontrado.getStatusCode().value()).isEqualTo(404);
        assertThat(naoEncontrado.getBody()).containsEntry("erro", "Recurso não encontrado");

        var regra = handler.handleRegra(new RegraDeNegocioException(null));
        assertThat(regra.getStatusCode().value()).isEqualTo(400);
        assertThat(regra.getBody()).containsEntry("erro", "Erro inesperado. Tente novamente.");
    }

    /**
     * O match é ancorado em `exclusion constraint "sem_sobreposicao"`. O nome da
     * constraint sozinho aparece no SQL e no Detail: da mensagem do Postgres, com
     * valores vindos do cliente — um cliente chamado "sem_sobreposicao" que tropeça
     * numa violação de unique não pode receber 409 "horário reservado".
     */
    @Test
    void nomeDaConstraintEmDadoDoClienteNaoViraConflito() {
        var ex = new DataIntegrityViolationException(
            "violates unique constraint \"clientes_barbeiro_id_telefone_key\" "
                + "Detail: Key (nome)=(sem_sobreposicao) already exists.");
        var resp = handler.handleConflito(ex);
        assertThat(resp.getStatusCode().value()).isEqualTo(500);
    }
}
