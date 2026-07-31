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
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

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
        // Violação de UNIQUE constraint genérica: cobre o padrão find-then-save sem
        // lock que existe em mais de um service (ex.: ClienteService.upsert em
        // "clientes_barbeiro_id_telefone_key", HorarioService.criarExcecao na UNIQUE
        // de excecoes_horario) — duas requisições concorrentes com o mesmo valor
        // nunca visto passam pelo find (nenhuma acha nada) e uma delas estoura a
        // constraint só no save(). Texto confirmado empiricamente contra Postgres 16
        // real (Testcontainers) em ConcorrenciaClienteNovoTest: "duplicate key value
        // violates unique constraint". Ancorado nesse prefixo (não no nome da
        // constraint, que varia por tabela) para não alcançar violação de FK/NOT
        // NULL/CHECK, que indicam bug real e devem continuar caindo no 500 genérico.
        if (msg.contains("duplicate key value violates unique constraint")) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(Map.of("erro", "Esse registro já existe ou acabou de ser processado. Tente novamente."));
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

    @ExceptionHandler(BadCredentialsException.class)
    public ResponseEntity<Map<String, Object>> handleCredenciais(BadCredentialsException ex) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("erro", "E-mail ou senha inválidos"));
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

    // Parâmetro de query ausente (MissingServletRequestParameterException) ou com
    // tipo incompatível (MethodArgumentTypeMismatchException, ex.: "data" malformada)
    // são ServletException/RuntimeException não mapeadas — sem este handler caem no
    // catch-all genérico e viram 500 em vez do 400 esperado pelo cliente.
    @ExceptionHandler({MethodArgumentTypeMismatchException.class, MissingServletRequestParameterException.class})
    public ResponseEntity<Map<String, Object>> handleParametroInvalido(Exception ex) {
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("erro", "Parâmetro inválido"));
    }
}
