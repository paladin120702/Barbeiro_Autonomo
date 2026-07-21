package com.seusistema.barbearia.common.exception;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Objects;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    static final String ERRO_GENERICO = "Erro inesperado. Tente novamente.";

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Map<String, Object>> handleConflito(DataIntegrityViolationException ex) {
        String msg = ex.getMessage() == null ? "" : ex.getMessage();
        // Ancorado no texto completo: o nome da constraint sozinho também aparece
        // dentro do SQL e do Detail: da mensagem, com valores vindos do cliente.
        if (msg.contains("exclusion constraint \"sem_sobreposicao\"")) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(Map.of("erro", "Esse horário acabou de ser reservado. Escolha outro."));
        }
        // Não relança: exceção relançada de dentro de um @ExceptionHandler escapa do
        // DispatcherServlet sem passar pelo catch-all (o resolver trata o caso
        // invocationEx == exception devolvendo null). Verificado em
        // GlobalExceptionHandlerRoteamentoTest. O cliente não deve ver detalhe da
        // exceção de qualquer forma, então devolvemos o mesmo 500 genérico.
        return handleInesperado(ex);
    }

    @ExceptionHandler(RecursoNaoEncontradoException.class)
    public ResponseEntity<Map<String, Object>> handleNaoEncontrado(RecursoNaoEncontradoException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
            .body(Map.of("erro", Objects.requireNonNullElse(ex.getMessage(), "Recurso não encontrado")));
    }

    @ExceptionHandler(RegraDeNegocioException.class)
    public ResponseEntity<Map<String, Object>> handleRegra(RegraDeNegocioException ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST)
            .body(Map.of("erro", Objects.requireNonNullElse(ex.getMessage(), ERRO_GENERICO)));
    }

    // Catch-all: sem ele, qualquer exceção não mapeada cai no corpo padrão do Boot
    // ({"timestamp","status","error","path"}), que é JSON válido mas não tem a
    // chave "erro" — o cliente sobrescreve o fallback dele e mostra mensagem vazia.
    // A exceção real fica no log; a resposta não vaza detalhe interno.
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleInesperado(Exception ex) {
        log.error("Erro não tratado", ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(Map.of("erro", ERRO_GENERICO));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidacao(MethodArgumentNotValidException ex) {
        Map<String, String> campos = new LinkedHashMap<>();
        ex.getBindingResult().getFieldErrors()
            .forEach(err -> campos.putIfAbsent(err.getField(), err.getDefaultMessage()));
        Map<String, Object> body = new HashMap<>();
        body.put("erro", "Dados inválidos");
        body.put("campos", campos);
        return ResponseEntity.badRequest().body(body);
    }
}
