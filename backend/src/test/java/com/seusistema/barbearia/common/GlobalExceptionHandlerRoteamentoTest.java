package com.seusistema.barbearia.common;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.seusistema.barbearia.common.exception.GlobalExceptionHandler;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Prova, pelo resolver real do Spring, que TODA exceção que sai de um controller
 * vira resposta com a chave "erro". Teste de unidade no handler não cobre isto:
 * ele chama o método direto e não exercita o roteamento entre @ExceptionHandler.
 */
class GlobalExceptionHandlerRoteamentoTest {

    @RestController
    static class ControllerDeTeste {

        @GetMapping("/estoura-integridade-nao-mapeada")
        String integridadeNaoMapeada() {
            throw new DataIntegrityViolationException(
                "violates unique constraint \"barbeiros_email_key\"");
        }

        @GetMapping("/estoura-conflito-de-horario")
        String conflitoDeHorario() {
            throw new DataIntegrityViolationException(
                "ERROR: conflicting key value violates exclusion constraint \"sem_sobreposicao\"");
        }

        @GetMapping("/estoura-inesperada")
        String inesperada() {
            throw new IllegalStateException("falha interna qualquer");
        }
    }

    MockMvc mvc = MockMvcBuilders
        .standaloneSetup(new ControllerDeTeste())
        .setControllerAdvice(new GlobalExceptionHandler())
        .build();

    @Test
    void violacaoDeIntegridadeNaoMapeadaVira500ComChaveErro() throws Exception {
        mvc.perform(get("/estoura-integridade-nao-mapeada"))
            .andExpect(status().isInternalServerError())
            .andExpect(jsonPath("$.erro").value("Erro inesperado. Tente novamente."));
    }

    @Test
    void conflitoDeHorarioContinuaVirando409() throws Exception {
        mvc.perform(get("/estoura-conflito-de-horario"))
            .andExpect(status().isConflict())
            .andExpect(jsonPath("$.erro").value("Esse horário acabou de ser reservado. Escolha outro."));
    }

    @Test
    void excecaoInesperadaVira500ComChaveErro() throws Exception {
        mvc.perform(get("/estoura-inesperada"))
            .andExpect(status().isInternalServerError())
            .andExpect(jsonPath("$.erro").value("Erro inesperado. Tente novamente."));
    }
}
