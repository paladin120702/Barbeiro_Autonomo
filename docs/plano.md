# Plano de Implementação — MVP SaaS Barbearia

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SaaS de agendamento para barbeiro individual: backend Spring Boot + vitrine pública React + app Flutter de gestão.

**Architecture:** Backend MVC em camadas (Controller → Service → Repository), pacotes por feature, trava de sobreposição via exclusion constraint PostgreSQL criada por Flyway. Web é página única sem login consumindo `/api/v1/public/**`. Mobile é MVVM com provider/ChangeNotifier consumindo `/api/v1/app/**` com JWT.

**Tech Stack:** Java 21, Spring Boot 3.4.x, PostgreSQL 16, Flyway, jjwt 0.12.x, Bucket4j, Testcontainers; React 18 + TypeScript + Vite + TanStack Query + Zod; Flutter 3.x + provider + dio + flutter_secure_storage + mockito.

**Fontes de verdade:** `MVP-SaaS-Barbearia.md` e `docs/superpowers/specs/2026-07-18-mvp-barbearia-design.md`. Dúvida → spec prevalece.

## Global Constraints

- Slots sempre de 1 hora cheia (9:00, 10:00…), `data_hora_fim = inicio + 1h`.
- Exclusion constraint `sem_sobreposicao` via Flyway SQL puro (`EXCLUDE USING gist`, `tsrange`, `btree_gist`), ignora `CANCELADO`/`NAO_COMPARECEU`. Nunca via Hibernate; `ddl-auto: validate`.
- Violação → `DataIntegrityViolationException` → 409 `{"erro": "Esse horário acabou de ser reservado. Escolha outro."}`.
- Rate limit Bucket4j 3 req/10min por IP **somente** em `GET /public/{slug}/disponibilidade` e `POST /public/{slug}/agendamentos`. 429 na 4ª.
- Rotas: `/api/v1/public/{slug}/**` sem auth; `/api/v1/app/**` JWT (7 dias, secret em `JWT_SECRET`, sem refresh).
- Erro padrão `{"erro": "msg"}`; validação 400 adiciona `"campos": {campo: msg}`.
- Timezone `America/Sao_Paulo` fixo, `LocalDateTime` puro.
- Telefone: normalizar para dígitos, validar 10–11; upsert cliente por `(barbeiro_id, telefone normalizado)`.
- Janela de agendamento: início > agora e ≤ 30 dias; disponibilidade de hoje omite horas passadas.
- `status_conta=INATIVO` → todas as `/public/{slug}/**` retornam 404; app funciona.
- Exatamente 6 tabelas: `barbeiros`, `servicos`, `clientes`, `horario_funcionamento`, `excecoes_horario`, `agendamentos`.
- DTOs sempre na borda; entidade JPA nunca serializada.
- Package `com.seusistema.barbearia`. Sem Lombok (código plain Java, como o MVP doc).
- Fora de escopo: WhatsApp, fidelidade, cobrança, multi-barbeiro, push, DDD/Clean/CQRS. YAGNI é lei.
- Fases estritas: Fase 1 (backend) → Fase 2 (web) → Fase 3 (Flutter). Fase só começa com a anterior revisada e verde.
- Testes backend: integração com Testcontainers (PostgreSQL real). Flutter: unidade de ViewModels com repository mockado.
- Commit por tarefa concluída (mensagens em português, Conventional Commits).

---

# FASE 1 — Backend

### Task 1: Scaffold do backend + docker-compose + base de testes Testcontainers

**Files:**
- Create: `backend/` (via start.spring.io), `backend/pom.xml` (ajustes), `backend/src/main/resources/application.yml`, `backend/src/main/resources/application-dev.yml`, `docker-compose.yml`, `.gitignore`, `backend/src/test/java/com/seusistema/barbearia/IntegrationTestBase.java`

**Interfaces:**
- Produces: `IntegrationTestBase` (classe abstrata; testes de integração estendem ela), profile `dev`, banco local via `docker compose up -d`.

- [ ] **Step 1: Gerar projeto**

```bash
cd /home/artur/Projetos/Barbearia
curl -s https://start.spring.io/starter.tgz \
  -d type=maven-project -d language=java -d bootVersion=3.4.5 -d javaVersion=21 \
  -d groupId=com.seusistema -d artifactId=barbearia -d name=barbearia \
  -d packageName=com.seusistema.barbearia \
  -d dependencies=web,data-jpa,security,validation,flyway,postgresql,testcontainers \
  | tar -xz && mv barbearia backend
```

- [ ] **Step 2: Adicionar dependências extras ao `backend/pom.xml`** (dentro de `<dependencies>`):

```xml
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-api</artifactId>
    <version>0.12.6</version>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-impl</artifactId>
    <version>0.12.6</version>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>io.jsonwebtoken</groupId>
    <artifactId>jjwt-jackson</artifactId>
    <version>0.12.6</version>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>com.bucket4j</groupId>
    <artifactId>bucket4j-core</artifactId>
    <version>8.10.1</version>
</dependency>
<dependency>
    <groupId>org.springframework.security</groupId>
    <artifactId>spring-security-test</artifactId>
    <scope>test</scope>
</dependency>
```

- [ ] **Step 3: `docker-compose.yml` na raiz**

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: barbearia-db
    environment:
      POSTGRES_DB: barbearia
      POSTGRES_USER: barbearia
      POSTGRES_PASSWORD: barbearia
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
volumes:
  pgdata:
```

- [ ] **Step 4: `backend/src/main/resources/application.yml`**

```yaml
spring:
  application:
    name: barbearia
  jpa:
    hibernate:
      ddl-auto: validate
    open-in-view: false
  flyway:
    locations: classpath:db/migration
  datasource:
    url: ${DB_URL:jdbc:postgresql://localhost:5432/barbearia}
    username: ${DB_USER:barbearia}
    password: ${DB_PASSWORD:barbearia}

barbearia:
  jwt:
    secret: ${JWT_SECRET:chave-dev-insegura-trocar-em-producao-0123456789abcdef}
    expiracao-dias: 7
```

E `application-dev.yml`:

```yaml
spring:
  flyway:
    locations: classpath:db/migration,classpath:db/dev
```

- [ ] **Step 5: Forçar timezone na main class** (`BarbeariaApplication.java`):

```java
package com.seusistema.barbearia;

import java.util.TimeZone;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class BarbeariaApplication {

    public static void main(String[] args) {
        TimeZone.setDefault(TimeZone.getTimeZone("America/Sao_Paulo"));
        SpringApplication.run(BarbeariaApplication.class, args);
    }
}
```

- [ ] **Step 6: Base de testes** — `backend/src/test/java/com/seusistema/barbearia/IntegrationTestBase.java` (container singleton, reusado por toda a suíte):

```java
package com.seusistema.barbearia;

import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.containers.PostgreSQLContainer;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
public abstract class IntegrationTestBase {

    static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>("postgres:16-alpine");

    static {
        POSTGRES.start();
    }

    @TestConfiguration
    static class ContainerConfig {
        @Bean
        @ServiceConnection
        PostgreSQLContainer<?> postgresContainer() {
            return POSTGRES;
        }
    }
}
```

> Nota: `@ServiceConnection` dentro de `@TestConfiguration` importada automaticamente não funciona sem `@Import`. Alternativa mais simples e robusta: usar `@DynamicPropertySource`:

```java
package com.seusistema.barbearia;

import org.springframework.boot.test.context.SpringBootTest;
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

    @DynamicPropertySource
    static void datasource(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }
}
```

Usar a versão com `@DynamicPropertySource`. Apagar o teste gerado `BarbeariaApplicationTests` e criar `ContextLoadsTest extends IntegrationTestBase` com um método `@Test void contextLoads() {}`.

- [ ] **Step 7: Rodar** — `cd backend && ./mvnw -q test`. Esperado: `ContextLoadsTest` FALHA ainda não — passa, pois não há migration nem entidade (Flyway sem migration = ok vazio). Se Flyway reclamar de location vazia, criar `db/migration/.keep` temporário ou setar `spring.flyway.fail-on-missing-locations: false` (remover na Task 2).

- [ ] **Step 8: `.gitignore` raiz** (backend/target, node_modules, build flutter, .idea, .vscode, *.iml, .env) e commit:

```bash
git add -A && git commit -m "feat(backend): scaffold Spring Boot + docker-compose + base Testcontainers"
```

---

### Task 2: Migration V1 (schema completo + exclusion constraint) com teste real da constraint

**Files:**
- Create: `backend/src/main/resources/db/migration/V1__schema.sql`
- Test: `backend/src/test/java/com/seusistema/barbearia/MigrationConstraintTest.java`

**Interfaces:**
- Produces: as 6 tabelas + constraint `sem_sobreposicao`. Todas as tasks seguintes dependem deste schema.

- [ ] **Step 1: Teste falhando** — `MigrationConstraintTest` insere via `JdbcTemplate` dois agendamentos sobrepostos do mesmo barbeiro e espera exceção; e verifica que sobrepor com `CANCELADO`/`NAO_COMPARECEU` é permitido:

```java
package com.seusistema.barbearia;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class MigrationConstraintTest extends IntegrationTestBase {

    @Autowired JdbcTemplate jdbc;

    Long barbeiroId;
    Long clienteId;
    Long servicoId;

    @BeforeEach
    void setUp() {
        jdbc.update("DELETE FROM agendamentos");
        jdbc.update("DELETE FROM clientes");
        jdbc.update("DELETE FROM servicos");
        jdbc.update("DELETE FROM barbeiros");
        barbeiroId = jdbc.queryForObject(
            "INSERT INTO barbeiros (nome, email, senha, slug) VALUES ('B', 'b@b.com', 'x', 'b') RETURNING id", Long.class);
        clienteId = jdbc.queryForObject(
            "INSERT INTO clientes (barbeiro_id, nome, telefone) VALUES (?, 'C', '11999999999') RETURNING id", Long.class, barbeiroId);
        servicoId = jdbc.queryForObject(
            "INSERT INTO servicos (barbeiro_id, nome, preco) VALUES (?, 'Corte', 50) RETURNING id", Long.class, barbeiroId);
    }

    private void inserir(String inicio, String status) {
        jdbc.update("""
            INSERT INTO agendamentos (barbeiro_id, cliente_id, servico_id, data_hora_inicio, data_hora_fim, status)
            VALUES (?, ?, ?, ?::timestamp, ?::timestamp + interval '1 hour', ?)
            """, barbeiroId, clienteId, servicoId, inicio, inicio, status);
    }

    @Test
    void constraintBloqueiaSobreposicaoDeAgendamentosAtivos() {
        inserir("2026-08-03 09:00", "AGENDADO");
        assertThatThrownBy(() -> inserir("2026-08-03 09:00", "AGENDADO"))
            .hasMessageContaining("sem_sobreposicao");
    }

    @Test
    void constraintIgnoraCanceladoENaoCompareceu() {
        inserir("2026-08-03 09:00", "CANCELADO");
        inserir("2026-08-03 09:00", "NAO_COMPARECEU");
        assertThatCode(() -> inserir("2026-08-03 09:00", "AGENDADO"))
            .doesNotThrowAnyException();
    }
}
```

- [ ] **Step 2: Rodar** — `./mvnw -q test -Dtest=MigrationConstraintTest`. Esperado: FAIL (`relation "agendamentos" does not exist`).

- [ ] **Step 3: Escrever `V1__schema.sql`** — SQL da seção 4 do MVP doc, verbatim:

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE barbeiros (
    id BIGSERIAL PRIMARY KEY,
    nome VARCHAR(120) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    senha VARCHAR(255) NOT NULL,
    slug VARCHAR(60) UNIQUE NOT NULL,
    telefone VARCHAR(20),
    status_conta VARCHAR(20) NOT NULL DEFAULT 'ATIVO'
);

CREATE TABLE servicos (
    id BIGSERIAL PRIMARY KEY,
    barbeiro_id BIGINT NOT NULL REFERENCES barbeiros(id),
    nome VARCHAR(120) NOT NULL,
    preco NUMERIC(10,2) NOT NULL,
    duracao_minutos INT NOT NULL DEFAULT 60
);

CREATE TABLE clientes (
    id BIGSERIAL PRIMARY KEY,
    barbeiro_id BIGINT NOT NULL REFERENCES barbeiros(id),
    nome VARCHAR(120) NOT NULL,
    telefone VARCHAR(20) NOT NULL,
    UNIQUE (barbeiro_id, telefone)
);

CREATE TABLE horario_funcionamento (
    id BIGSERIAL PRIMARY KEY,
    barbeiro_id BIGINT NOT NULL REFERENCES barbeiros(id),
    dia_semana SMALLINT NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fim TIME NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE excecoes_horario (
    id BIGSERIAL PRIMARY KEY,
    barbeiro_id BIGINT NOT NULL REFERENCES barbeiros(id),
    data DATE NOT NULL,
    disponivel BOOLEAN NOT NULL DEFAULT FALSE,
    hora_inicio TIME,
    hora_fim TIME,
    UNIQUE (barbeiro_id, data)
);

CREATE TABLE agendamentos (
    id BIGSERIAL PRIMARY KEY,
    barbeiro_id BIGINT NOT NULL REFERENCES barbeiros(id),
    cliente_id BIGINT NOT NULL REFERENCES clientes(id),
    servico_id BIGINT NOT NULL REFERENCES servicos(id),
    data_hora_inicio TIMESTAMP NOT NULL,
    data_hora_fim TIMESTAMP NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'AGENDADO',
    forma_pagamento VARCHAR(20),

    CONSTRAINT sem_sobreposicao EXCLUDE USING gist (
        barbeiro_id WITH =,
        tsrange(data_hora_inicio, data_hora_fim) WITH &&
    ) WHERE (status NOT IN ('CANCELADO', 'NAO_COMPARECEU'))
);
```

Remover o workaround de location vazia da Task 1, se usado.

- [ ] **Step 4: Rodar** — `./mvnw -q test -Dtest=MigrationConstraintTest`. Esperado: PASS.

- [ ] **Step 5: Commit** — `git add -A && git commit -m "feat(backend): migration V1 com schema e exclusion constraint sem_sobreposicao"`

---

### Task 3: Entidades JPA, enums e repositories

**Files:**
- Create: `backend/src/main/java/com/seusistema/barbearia/barbeiro/Barbeiro.java`, `barbeiro/BarbeiroRepository.java`, `barbeiro/StatusConta.java`, `servico/Servico.java`, `servico/ServicoRepository.java`, `cliente/Cliente.java`, `cliente/ClienteRepository.java`, `horario/HorarioFuncionamento.java`, `horario/ExcecaoHorario.java`, `horario/HorarioFuncionamentoRepository.java`, `horario/ExcecaoHorarioRepository.java`, `agendamento/Agendamento.java`, `agendamento/StatusAgendamento.java`, `agendamento/FormaPagamento.java`, `agendamento/AgendamentoRepository.java`
- Test: `backend/src/test/java/com/seusistema/barbearia/EntidadesMapeamentoTest.java`

**Interfaces:**
- Produces: entidades com getters/setters plain Java; enums `StatusConta {ATIVO, INATIVO}`, `StatusAgendamento {AGENDADO, CONCLUIDO, CANCELADO, NAO_COMPARECEU}`, `FormaPagamento {PIX, DINHEIRO, DEBITO, CREDITO}`. Repositories Spring Data:
  - `BarbeiroRepository`: `Optional<Barbeiro> findBySlug(String slug)`, `Optional<Barbeiro> findByEmail(String email)`, `boolean existsBySlug(String slug)`, `boolean existsByEmail(String email)`
  - `ServicoRepository`: `List<Servico> findByBarbeiroId(Long barbeiroId)`, `Optional<Servico> findByIdAndBarbeiroId(Long id, Long barbeiroId)`
  - `ClienteRepository`: `Optional<Cliente> findByBarbeiroIdAndTelefone(Long barbeiroId, String telefone)`
  - `HorarioFuncionamentoRepository`: `List<HorarioFuncionamento> findByBarbeiroId(Long id)`, `List<HorarioFuncionamento> findByBarbeiroIdAndDiaSemanaAndAtivoTrue(Long id, int diaSemana)`, `Optional<HorarioFuncionamento> findByIdAndBarbeiroId(Long id, Long barbeiroId)`
  - `ExcecaoHorarioRepository`: `List<ExcecaoHorario> findByBarbeiroId(Long id)`, `Optional<ExcecaoHorario> findByBarbeiroIdAndData(Long id, LocalDate data)`, `Optional<ExcecaoHorario> findByIdAndBarbeiroId(Long id, Long barbeiroId)`
  - `AgendamentoRepository`: `List<Agendamento> findByBarbeiroIdAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThanOrderByDataHoraInicio(Long id, LocalDateTime ini, LocalDateTime fimExclusivo)`, `Optional<Agendamento> findByIdAndBarbeiroId(Long id, Long barbeiroId)`, `List<Agendamento> findByBarbeiroIdAndStatusAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThan(Long id, StatusAgendamento status, LocalDateTime ini, LocalDateTime fimExclusivo)`
  - **Regra:** toda query de range de tempo é half-open `[ini, fim)`, espelhando o `tsrange [)` da constraint `sem_sobreposicao`. Nunca usar `Between` (inclusivo nas duas pontas) nem `LocalTime.MAX` como limite.

- [ ] **Step 1: Teste falhando** — `EntidadesMapeamentoTest extends IntegrationTestBase`: salva um `Barbeiro`, um `Servico`, um `Cliente` e um `Agendamento` via repositories e relê; verifica `dataHoraFim == inicio.plusHours(1)` (o `@PrePersist`):

```java
package com.seusistema.barbearia;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.agendamento.*;
import com.seusistema.barbearia.barbeiro.*;
import com.seusistema.barbearia.cliente.*;
import com.seusistema.barbearia.servico.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class EntidadesMapeamentoTest extends IntegrationTestBase {

    @Autowired BarbeiroRepository barbeiros;
    @Autowired ServicoRepository servicos;
    @Autowired ClienteRepository clientes;
    @Autowired AgendamentoRepository agendamentos;

    @Test
    void persisteGrafoCompletoECalculaFimNoPrePersist() {
        Barbeiro b = new Barbeiro();
        b.setNome("João");
        b.setEmail("joao@teste.com");
        b.setSenha("hash");
        b.setSlug("joao-barber");
        b = barbeiros.save(b);
        assertThat(b.getStatusConta()).isEqualTo(StatusConta.ATIVO);

        Servico s = new Servico();
        s.setBarbeiroId(b.getId());
        s.setNome("Corte");
        s.setPreco(new BigDecimal("50.00"));
        s = servicos.save(s);
        assertThat(s.getDuracaoMinutos()).isEqualTo(60);

        Cliente c = new Cliente();
        c.setBarbeiroId(b.getId());
        c.setNome("Cliente");
        c.setTelefone("11999999999");
        c = clientes.save(c);

        Agendamento a = new Agendamento();
        a.setBarbeiroId(b.getId());
        a.setCliente(c);
        a.setServico(s);
        a.setDataHoraInicio(LocalDateTime.of(2026, 8, 3, 9, 0));
        a = agendamentos.save(a);

        assertThat(a.getDataHoraFim()).isEqualTo(LocalDateTime.of(2026, 8, 3, 10, 0));
        assertThat(a.getStatus()).isEqualTo(StatusAgendamento.AGENDADO);
    }
}
```

- [ ] **Step 2: Rodar** — esperado: FAIL (classes não existem / não compila).

- [ ] **Step 3: Implementar entidades.** `Agendamento` exatamente como a seção 5.3 do MVP doc (com `@PrePersist calcularFim()`). Demais entidades seguem o mesmo estilo — campos = colunas, `@Enumerated(EnumType.STRING)` para enums, getters/setters. Exemplo `Barbeiro`:

```java
package com.seusistema.barbearia.barbeiro;

import jakarta.persistence.*;

@Entity
@Table(name = "barbeiros")
public class Barbeiro {

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String nome;
    private String email;
    private String senha;
    private String slug;
    private String telefone;

    @Enumerated(EnumType.STRING)
    @Column(name = "status_conta")
    private StatusConta statusConta = StatusConta.ATIVO;

    // getters e setters de todos os campos
}
```

`Servico`: `id`, `barbeiroId` (`@Column(name = "barbeiro_id")`), `nome`, `preco` (`BigDecimal`), `duracaoMinutos` (`@Column(name = "duracao_minutos")`, default `60`). `Cliente`: `id`, `barbeiroId`, `nome`, `telefone`. `HorarioFuncionamento`: `id`, `barbeiroId`, `diaSemana` (int), `horaInicio`/`horaFim` (`LocalTime`), `ativo` (boolean, default true). `ExcecaoHorario`: `id`, `barbeiroId`, `data` (`LocalDate`), `disponivel` (boolean, default false), `horaInicio`/`horaFim` (`LocalTime`, nullable). Repositories: interfaces `extends JpaRepository<T, Long>` com os métodos listados em **Produces**.

- [ ] **Step 4: Rodar** — `./mvnw -q test -Dtest=EntidadesMapeamentoTest`. Esperado: PASS (valida também o `ddl-auto: validate` contra o schema Flyway).

- [ ] **Step 5: Commit** — `git commit -am "feat(backend): entidades JPA, enums e repositories"`

---

### Task 4: Tratamento global de erros (formato padrão da API)

**Files:**
- Create: `backend/src/main/java/com/seusistema/barbearia/common/exception/GlobalExceptionHandler.java`, `common/exception/RecursoNaoEncontradoException.java`, `common/exception/RegraDeNegocioException.java`
- Test: `backend/src/test/java/com/seusistema/barbearia/common/GlobalExceptionHandlerTest.java` (unidade, sem Spring)

**Interfaces:**
- Produces: `RecursoNaoEncontradoException(String msg)` → 404; `RegraDeNegocioException(String msg)` → 400; `DataIntegrityViolationException` com `sem_sobreposicao` → 409; `MethodArgumentNotValidException` → 400 com `campos`. Corpo sempre `{"erro": ...}` (+ `"campos"` na validação).

- [ ] **Step 1: Teste falhando** (unidade pura — instancia o handler):

```java
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
    void outraViolacaoDeIntegridadeVira500Generico() {
        var ex = new DataIntegrityViolationException("violates unique constraint \"barbeiros_email_key\"");
        var resp = handler.handleConflito(ex);
        assertThat(resp.getStatusCode().value()).isEqualTo(500);
        assertThat(resp.getBody()).containsEntry("erro", "Erro inesperado. Tente novamente.");
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
```

- [ ] **Step 2: Rodar** — `./mvnw -q test -Dtest=GlobalExceptionHandlerTest`. Esperado: FAIL (não compila).

- [ ] **Step 3: Implementar:**

```java
package com.seusistema.barbearia.common.exception;

public class RecursoNaoEncontradoException extends RuntimeException {
    public RecursoNaoEncontradoException(String message) { super(message); }
}
```

```java
package com.seusistema.barbearia.common.exception;

public class RegraDeNegocioException extends RuntimeException {
    public RegraDeNegocioException(String message) { super(message); }
}
```

```java
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
        // no SQL e no Detail: da mensagem, com valores vindos do cliente.
        if (msg.contains("exclusion constraint \"sem_sobreposicao\"")) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(Map.of("erro", "Esse horário acabou de ser reservado. Escolha outro."));
        }
        // Violação de UNIQUE constraint genérica: cobre o padrão find-then-save sem
        // lock que aparece em mais de um service (ex.: ClienteService.upsert em
        // "clientes_barbeiro_id_telefone_key", HorarioService.criarExcecao na UNIQUE
        // de excecoes_horario) — duas requisições concorrentes com o mesmo valor
        // nunca visto passam pelo find (nenhuma acha nada) e uma delas estoura a
        // constraint só no save(). Texto confirmado empiricamente contra Postgres 16
        // real (Testcontainers, Task 10 hardening): "duplicate key value violates
        // unique constraint". Ancorado nesse prefixo (não no nome da constraint, que
        // varia por tabela) para não alcançar violação de FK/NOT NULL/CHECK, que
        // indicam bug real e devem continuar caindo no 500 genérico.
        if (msg.contains("duplicate key value violates unique constraint")) {
            return ResponseEntity.status(HttpStatus.CONFLICT)
                .body(Map.of("erro", "Esse registro já existe ou acabou de ser processado. Tente novamente."));
        }
        // NÃO relançar: exceção relançada de dentro de um @ExceptionHandler escapa do
        // DispatcherServlet sem passar pelo catch-all (o resolver devolve null quando
        // invocationEx == exception), e o cliente recebe corpo sem a chave "erro".
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

    // Catch-all: sem ele, exceção não mapeada cai no corpo padrão do Boot
    // ({"timestamp","status","error","path"}), que é JSON válido mas não tem "erro".
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
```

- [ ] **Step 4: Rodar** — esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(backend): GlobalExceptionHandler com formato de erro padrão"`

---

### Task 5: Segurança JWT + login + BarbeiroService.criar + CLI admin + seed dev

**Files:**
- Create: `backend/src/main/java/com/seusistema/barbearia/security/JwtService.java`, `security/JwtAuthFilter.java`, `config/SecurityConfig.java`, `config/CorsConfig.java`, `barbeiro/BarbeiroService.java`, `barbeiro/BarbeiroController.java`, `barbeiro/dto/LoginRequest.java`, `barbeiro/dto/LoginResponse.java`, `barbeiro/dto/CriarBarbeiroRequest.java`, `config/CriarBarbeiroRunner.java`, `backend/src/main/resources/db/dev/R__seed_dev.sql`
- Modify: `common/exception/GlobalExceptionHandler.java` (handler de `BadCredentialsException`)
- Test: `backend/src/test/java/com/seusistema/barbearia/barbeiro/BarbeiroServiceTest.java`, `backend/src/test/java/com/seusistema/barbearia/security/AutenticacaoTest.java`

**Interfaces:**
- Consumes: `RegraDeNegocioException`, `RecursoNaoEncontradoException`, `GlobalExceptionHandler` (Task 4); `BarbeiroRepository` (Task 3).
- Produces:
  - `JwtService`: `String gerar(Long barbeiroId)`; `Long validarEExtrairId(String token)` (lança se inválido/expirado). Expiração 7 dias; secret de `barbearia.jwt.secret` (HMAC-SHA256).
  - `JwtAuthFilter`: valida Bearer token; sucesso → `Authentication` com principal `Long barbeiroId`. Controllers `/app` recebem o id via `@AuthenticationPrincipal Long barbeiroId`.
  - `SecurityConfig`: `permitAll` em `/api/v1/public/**` e `POST /api/v1/app/login`; resto autenticado; 401 body `{"erro": "Não autorizado"}`; CSRF off; stateless; bean `PasswordEncoder` (BCrypt).
  - `BarbeiroService`: `Barbeiro criar(CriarBarbeiroRequest req)` — e-mail/slug duplicado → `RegraDeNegocioException`; slug gerado do nome quando ausente (minúsculas, sem acento, hífens); senha BCrypt; status ATIVO. `LoginResponse login(LoginRequest req)` — credencial inválida → `BadCredentialsException` (handler devolve 401 `{"erro": "E-mail ou senha inválidos"}`). `Barbeiro buscarAtivoPorSlug(String slug)` — inexistente **ou INATIVO** → `RecursoNaoEncontradoException("Barbeiro não encontrado")`.
  - `CriarBarbeiroRunner`: `ApplicationRunner` ativo só com arg `--criar-barbeiro`; lê `--nome=`, `--email=`, `--senha=`, `--slug=` (opcional); delega a `BarbeiroService.criar`; imprime id/slug; encerra via `System.exit(SpringApplication.exit(ctx))`. Camada fina, zero lógica de negócio (preparação para futuro endpoint self-service, que NÃO será criado agora).
  - Records: `LoginRequest(String email, String senha)`, `LoginResponse(String token, String nome, String slug)`, `CriarBarbeiroRequest(String nome, String email, String senha, String slug)`.
- Endpoint: `POST /api/v1/app/login` → 200 `LoginResponse` | 401.

- [ ] **Step 1: Teste de service falhando** — `BarbeiroServiceTest extends IntegrationTestBase`:

```java
package com.seusistema.barbearia.barbeiro;

import static org.assertj.core.api.Assertions.*;

import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import com.seusistema.barbearia.common.exception.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;

class BarbeiroServiceTest extends IntegrationTestBase {

    @Autowired BarbeiroService service;
    @Autowired BarbeiroRepository repository;
    @Autowired PasswordEncoder encoder;
    @Autowired JdbcTemplate jdbc;

    @BeforeEach
    void limpar() {
        jdbc.update("DELETE FROM agendamentos");
        jdbc.update("DELETE FROM clientes");
        jdbc.update("DELETE FROM servicos");
        jdbc.update("DELETE FROM excecoes_horario");
        jdbc.update("DELETE FROM horario_funcionamento");
        jdbc.update("DELETE FROM barbeiros");
    }

    @Test
    void criaComSlugGeradoESenhaComHash() {
        Barbeiro b = service.criar(new CriarBarbeiroRequest("João Barber", "j@b.com", "senha123", null));
        assertThat(b.getSlug()).isEqualTo("joao-barber");
        assertThat(b.getSenha()).isNotEqualTo("senha123");
        assertThat(encoder.matches("senha123", b.getSenha())).isTrue();
        assertThat(b.getStatusConta()).isEqualTo(StatusConta.ATIVO);
    }

    @Test
    void rejeitaEmailDuplicado() {
        service.criar(new CriarBarbeiroRequest("A", "dup@b.com", "x12345", "a"));
        assertThatThrownBy(() -> service.criar(new CriarBarbeiroRequest("B", "dup@b.com", "x12345", "b")))
            .isInstanceOf(RegraDeNegocioException.class);
    }

    @Test
    void buscarAtivoPorSlugNaoRetornaInativo() {
        Barbeiro b = service.criar(new CriarBarbeiroRequest("C", "c@b.com", "x12345", "c"));
        b.setStatusConta(StatusConta.INATIVO);
        repository.save(b);
        assertThatThrownBy(() -> service.buscarAtivoPorSlug("c"))
            .isInstanceOf(RecursoNaoEncontradoException.class);
    }
}
```

Nota: o `@BeforeEach` de limpeza total de tabelas se repete em todos os testes de integração — extrair para método `protected void limparBanco()` na `IntegrationTestBase` (com `@Autowired JdbcTemplate` lá) e chamar dos `@BeforeEach`. Fazer isso já nesta task e refatorar `MigrationConstraintTest`/`EntidadesMapeamentoTest` para usar.

- [ ] **Step 2: Teste de autenticação falhando** — `AutenticacaoTest` com `TestRestTemplate` (sufixo `Test`, não `IT`: o Surefire da fase `test` só coleta `*Test`/`*Tests`/`*TestCase`; `*IT` seria do Failsafe, que não está no pom, e a suíte inteira roda por `./mvnw test`):

```java
package com.seusistema.barbearia.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.barbeiro.dto.*;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.*;

class AutenticacaoTest extends IntegrationTestBase {

    @Autowired TestRestTemplate rest;
    @Autowired BarbeiroService barbeiroService;

    @BeforeEach
    void setUp() {
        limparBanco();
        barbeiroService.criar(new CriarBarbeiroRequest("João", "joao@b.com", "senha123", "joao"));
    }

    @Test
    void loginValidoRetornaTokenUtilizavel() {
        ResponseEntity<LoginResponse> login = rest.postForEntity("/api/v1/app/login",
            new LoginRequest("joao@b.com", "senha123"), LoginResponse.class);
        assertThat(login.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(login.getBody().token()).isNotBlank();

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(login.getBody().token());
        ResponseEntity<String> agenda = rest.exchange("/api/v1/app/agendamentos?data=2026-08-03",
            HttpMethod.GET, new HttpEntity<>(headers), String.class);
        assertThat(agenda.getStatusCode()).isNotEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void senhaErradaRetorna401() {
        ResponseEntity<Map> resp = rest.postForEntity("/api/v1/app/login",
            new LoginRequest("joao@b.com", "errada"), Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(resp.getBody()).containsKey("erro");
    }

    @Test
    void rotaAppSemTokenRetorna401() {
        ResponseEntity<Map> resp = rest.getForEntity("/api/v1/app/agendamentos?data=2026-08-03", Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(resp.getBody()).containsEntry("erro", "Não autorizado");
    }

    @Test
    void rotaPublicaNaoExigeToken() {
        ResponseEntity<String> resp = rest.getForEntity("/api/v1/public/joao", String.class);
        assertThat(resp.getStatusCode()).isNotEqualTo(HttpStatus.UNAUTHORIZED);
    }
}
```

Nota: `GET /app/agendamentos` e `GET /public/{slug}` ainda não existem — 404/403 autenticado é aceitável aqui (asserts usam `isNotEqualTo(UNAUTHORIZED)`).

- [ ] **Step 3: Rodar os dois** — `./mvnw -q test -Dtest='BarbeiroServiceTest,AutenticacaoTest'`. Esperado: FAIL (não compila).

- [ ] **Step 4: Implementar.** `JwtService`:

```java
package com.seusistema.barbearia.security;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Date;
import javax.crypto.SecretKey;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class JwtService {

    private final SecretKey key;
    private final Duration expiracao;

    public JwtService(@Value("${barbearia.jwt.secret}") String secret,
                      @Value("${barbearia.jwt.expiracao-dias}") long expiracaoDias) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expiracao = Duration.ofDays(expiracaoDias);
    }

    public String gerar(Long barbeiroId) {
        Date agora = new Date();
        return Jwts.builder()
            .subject(String.valueOf(barbeiroId))
            .issuedAt(agora)
            .expiration(new Date(agora.getTime() + expiracao.toMillis()))
            .signWith(key)
            .compact();
    }

    public Long validarEExtrairId(String token) {
        return Long.valueOf(Jwts.parser().verifyWith(key).build()
            .parseSignedClaims(token).getPayload().getSubject());
    }
}
```

`JwtAuthFilter`:

```java
package com.seusistema.barbearia.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.List;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtService jwtService;

    public JwtAuthFilter(JwtService jwtService) {
        this.jwtService = jwtService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            try {
                Long barbeiroId = jwtService.validarEExtrairId(header.substring(7));
                var auth = new UsernamePasswordAuthenticationToken(barbeiroId, null, List.of());
                SecurityContextHolder.getContext().setAuthentication(auth);
            } catch (Exception e) {
                SecurityContextHolder.clearContext();
            }
        }
        filterChain.doFilter(request, response);
    }
}
```

`SecurityConfig`:

```java
package com.seusistema.barbearia.config;

import com.seusistema.barbearia.security.JwtAuthFilter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
public class SecurityConfig {

    @Bean
    SecurityFilterChain filterChain(HttpSecurity http, JwtAuthFilter jwtAuthFilter) throws Exception {
        return http
            .csrf(csrf -> csrf.disable())
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/public/**").permitAll()
                .requestMatchers(HttpMethod.POST, "/api/v1/app/login").permitAll()
                .anyRequest().authenticated())
            .exceptionHandling(e -> e.authenticationEntryPoint((req, res, ex) -> {
                res.setStatus(401);
                res.setContentType("application/json;charset=UTF-8");
                res.getWriter().write("{\"erro\": \"Não autorizado\"}");
            }))
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }

    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
```

`BarbeiroService`:

```java
package com.seusistema.barbearia.barbeiro;

import com.seusistema.barbearia.barbeiro.dto.*;
import com.seusistema.barbearia.common.exception.*;
import com.seusistema.barbearia.security.JwtService;
import java.text.Normalizer;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BarbeiroService {

    private final BarbeiroRepository repository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public BarbeiroService(BarbeiroRepository repository, PasswordEncoder passwordEncoder,
                           JwtService jwtService) {
        this.repository = repository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    @Transactional
    public Barbeiro criar(CriarBarbeiroRequest req) {
        if (repository.existsByEmail(req.email())) {
            throw new RegraDeNegocioException("E-mail já cadastrado");
        }
        String slug = (req.slug() == null || req.slug().isBlank()) ? gerarSlug(req.nome()) : req.slug();
        if (repository.existsBySlug(slug)) {
            throw new RegraDeNegocioException("Slug já em uso");
        }
        Barbeiro b = new Barbeiro();
        b.setNome(req.nome());
        b.setEmail(req.email());
        b.setSenha(passwordEncoder.encode(req.senha()));
        b.setSlug(slug);
        return repository.save(b);
    }

    public LoginResponse login(LoginRequest req) {
        Barbeiro b = repository.findByEmail(req.email())
            .orElseThrow(() -> new BadCredentialsException("credenciais"));
        if (!passwordEncoder.matches(req.senha(), b.getSenha())) {
            throw new BadCredentialsException("credenciais");
        }
        return new LoginResponse(jwtService.gerar(b.getId()), b.getNome(), b.getSlug());
    }

    public Barbeiro buscarAtivoPorSlug(String slug) {
        return repository.findBySlug(slug)
            .filter(b -> b.getStatusConta() == StatusConta.ATIVO)
            .orElseThrow(() -> new RecursoNaoEncontradoException("Barbeiro não encontrado"));
    }

    private String gerarSlug(String nome) {
        String semAcento = Normalizer.normalize(nome, Normalizer.Form.NFD).replaceAll("\\p{M}", "");
        return semAcento.toLowerCase().trim().replaceAll("[^a-z0-9]+", "-").replaceAll("(^-|-$)", "");
    }
}
```

`BarbeiroController` — só o login:

```java
package com.seusistema.barbearia.barbeiro;

import com.seusistema.barbearia.barbeiro.dto.*;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/app")
public class BarbeiroController {

    private final BarbeiroService barbeiroService;

    public BarbeiroController(BarbeiroService barbeiroService) {
        this.barbeiroService = barbeiroService;
    }

    @PostMapping("/login")
    public LoginResponse login(@Valid @RequestBody LoginRequest request) {
        return barbeiroService.login(request);
    }
}
```

`CriarBarbeiroRunner`:

```java
package com.seusistema.barbearia.config;

import com.seusistema.barbearia.barbeiro.Barbeiro;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.stereotype.Component;

@Component
public class CriarBarbeiroRunner implements ApplicationRunner {

    private final BarbeiroService barbeiroService;
    private final ConfigurableApplicationContext context;

    public CriarBarbeiroRunner(BarbeiroService barbeiroService, ConfigurableApplicationContext context) {
        this.barbeiroService = barbeiroService;
        this.context = context;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!args.containsOption("criar-barbeiro")) {
            return;
        }
        Barbeiro b = barbeiroService.criar(new CriarBarbeiroRequest(
            primeiro(args, "nome"), primeiro(args, "email"),
            primeiro(args, "senha"), primeiro(args, "slug")));
        System.out.printf("Barbeiro criado: id=%d slug=%s%n", b.getId(), b.getSlug());
        System.exit(SpringApplication.exit(context, () -> 0));
    }

    private String primeiro(ApplicationArguments args, String nome) {
        var valores = args.getOptionValues(nome);
        return (valores == null || valores.isEmpty()) ? null : valores.get(0);
    }
}
```

Records (`LoginRequest` com `@NotBlank @Email` em email e `@NotBlank` em senha; demais sem validação — CLI valida no service). Handler novo no `GlobalExceptionHandler`:

```java
@ExceptionHandler(BadCredentialsException.class)
public ResponseEntity<Map<String, Object>> handleCredenciais(BadCredentialsException ex) {
    return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("erro", "E-mail ou senha inválidos"));
}
```

`CorsConfig` — `WebMvcConfigurer` com `addCorsMappings`: `/api/v1/**`, origens `*`, métodos GET/POST/PUT/DELETE (vitrine e app rodam em origens próprias; sem credenciais de cookie, CORS aberto é aceitável no MVP).

`R__seed_dev.sql` (location `db/dev`, só no profile `dev`): gerar o hash uma vez — `jshell` ou teste descartável imprimindo `new BCryptPasswordEncoder().encode("senha123")` — e colar no lugar do placeholder abaixo (único valor do plano gerado em tempo de implementação):

```sql
INSERT INTO barbeiros (nome, email, senha, slug)
VALUES ('Barbeiro Dev', 'dev@barbearia.local', '<HASH_BCRYPT_DE_senha123>', 'barbeiro-dev')
ON CONFLICT (email) DO NOTHING;
```

- [ ] **Step 5: Rodar** — `./mvnw -q test -Dtest='BarbeiroServiceTest,AutenticacaoTest'`. Esperado: PASS. Rodar suíte completa (`./mvnw -q test`) para garantir que nada quebrou.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat(backend): JWT, login, BarbeiroService.criar, CLI admin e seed dev"`

---

### Task 6: Vitrine pública — GET /public/{slug} e serviços públicos

**Files:**
- Create: `backend/src/main/java/com/seusistema/barbearia/barbeiro/BarbeiroPublicoController.java`, `barbeiro/dto/BarbeiroPublicoDTO.java`, `servico/ServicoPublicoController.java`, `servico/dto/ServicoDTO.java`, `servico/ServicoService.java`
- Test: `backend/src/test/java/com/seusistema/barbearia/barbeiro/VitrinePublicaIT.java`

**Interfaces:**
- Consumes: `BarbeiroService.buscarAtivoPorSlug(String)` (Task 5); `ServicoRepository` (Task 3).
- Produces: `BarbeiroPublicoDTO(String nome, String slug, String telefone)` (record; **sem** email/senha/status); `ServicoDTO(Long id, String nome, BigDecimal preco, Integer duracaoMinutos)` (record; reusado nas rotas /app na Task 7); `ServicoService.listarPorBarbeiro(Long barbeiroId)` → `List<ServicoDTO>` ordenado por nome.
- Endpoints: `GET /api/v1/public/{slug}` → 200 `BarbeiroPublicoDTO` | 404; `GET /api/v1/public/{slug}/servicos` → 200 `List<ServicoDTO>` | 404.

- [ ] **Step 1: Teste falhando** — `VitrinePublicaIT extends IntegrationTestBase` (`limparBanco()` no `@BeforeEach`): cria barbeiro ativo com 2 serviços (via `BarbeiroService.criar` + `ServicoRepository`) e um barbeiro INATIVO. Asserts:
  - `GET /api/v1/public/{slug-ativo}` → 200; corpo (String) contém o nome e **não** contém `"senha"` nem `"email"`.
  - `GET /api/v1/public/nao-existe` → 404 com `{"erro": "Barbeiro não encontrado"}`.
  - `GET /api/v1/public/{slug-inativo}` → 404.
  - `GET /api/v1/public/{slug-ativo}/servicos` → 200 com 2 itens ordenados por nome (deserializar em `ServicoDTO[]`).

- [ ] **Step 2: Rodar** — `./mvnw -q test -Dtest=VitrinePublicaIT`. Esperado: FAIL.

- [ ] **Step 3: Implementar.** `BarbeiroPublicoController`:

```java
package com.seusistema.barbearia.barbeiro;

import com.seusistema.barbearia.barbeiro.dto.BarbeiroPublicoDTO;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/public/{slug}")
public class BarbeiroPublicoController {

    private final BarbeiroService barbeiroService;

    public BarbeiroPublicoController(BarbeiroService barbeiroService) {
        this.barbeiroService = barbeiroService;
    }

    @GetMapping
    public BarbeiroPublicoDTO buscar(@PathVariable String slug) {
        Barbeiro b = barbeiroService.buscarAtivoPorSlug(slug);
        return new BarbeiroPublicoDTO(b.getNome(), b.getSlug(), b.getTelefone());
    }
}
```

`ServicoService`:

```java
package com.seusistema.barbearia.servico;

import com.seusistema.barbearia.servico.dto.ServicoDTO;
import java.util.Comparator;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class ServicoService {

    private final ServicoRepository repository;

    public ServicoService(ServicoRepository repository) {
        this.repository = repository;
    }

    public List<ServicoDTO> listarPorBarbeiro(Long barbeiroId) {
        return repository.findByBarbeiroId(barbeiroId).stream()
            .sorted(Comparator.comparing(Servico::getNome))
            .map(s -> new ServicoDTO(s.getId(), s.getNome(), s.getPreco(), s.getDuracaoMinutos()))
            .toList();
    }
}
```

`ServicoPublicoController` (`GET /api/v1/public/{slug}/servicos`): resolve barbeiro via `barbeiroService.buscarAtivoPorSlug(slug)` (garante 404 de INATIVO) e retorna `servicoService.listarPorBarbeiro(b.getId())`.

- [ ] **Step 4: Rodar** — esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(backend): vitrine pública (barbeiro e serviços por slug)"`

---

### Task 7: CRUD de serviços (/app)

**Files:**
- Create: `backend/src/main/java/com/seusistema/barbearia/servico/ServicoController.java`, `servico/dto/SalvarServicoRequest.java`
- Modify: `servico/ServicoService.java`
- Test: `backend/src/test/java/com/seusistema/barbearia/servico/ServicoCrudIT.java`

**Interfaces:**
- Consumes: `ServicoDTO`, `ServicoService` (Task 6); autenticação via `@AuthenticationPrincipal Long barbeiroId` (Task 5).
- Produces: `SalvarServicoRequest(String nome, BigDecimal preco, Integer duracaoMinutos)` (record; `@NotBlank` nome, `@NotNull @Positive` preco; `duracaoMinutos` opcional, default 60). Novos métodos no `ServicoService`, todos escopados pelo barbeiro autenticado:
  - `ServicoDTO criar(Long barbeiroId, SalvarServicoRequest req)`
  - `ServicoDTO atualizar(Long barbeiroId, Long id, SalvarServicoRequest req)` — não achou → `RecursoNaoEncontradoException("Serviço não encontrado")`
  - `void excluir(Long barbeiroId, Long id)` — idem 404; se o serviço tiver agendamentos vinculados, lançar `RegraDeNegocioException("Serviço possui agendamentos e não pode ser excluído")` antes do delete (checar via novo método `AgendamentoRepository.existsByServicoId(Long servicoId)`).
- Endpoints: `GET /api/v1/app/servicos` → 200 lista; `POST /api/v1/app/servicos` → 201 `ServicoDTO`; `PUT /api/v1/app/servicos/{id}` → 200 `ServicoDTO`; `DELETE /api/v1/app/servicos/{id}` → 204.

- [ ] **Step 1: Teste falhando** — `ServicoCrudIT extends IntegrationTestBase`: `@BeforeEach` limpa banco, cria barbeiro via service e faz login real (`POST /app/login`) guardando `HttpHeaders` com Bearer. Extrair helper `protected HttpHeaders authHeaders(String email, String senha)` para a `IntegrationTestBase` (reusado nas Tasks 8, 9, 11 e 12). Casos:
  - POST cria → 201 com id no body; GET lista com 1 item.
  - POST sem nome → 400 com `campos.nome`.
  - PUT atualiza preço → 200; GET reflete.
  - PUT id inexistente → 404.
  - DELETE → 204; GET lista vazia.
  - DELETE de serviço com agendamento → 400 `{"erro": "Serviço possui agendamentos e não pode ser excluído"}` (montar agendamento via repositories).
  - Escopo por barbeiro: PUT/DELETE com token do barbeiro A sobre serviço do barbeiro B → 404.

- [ ] **Step 2: Rodar** — `./mvnw -q test -Dtest=ServicoCrudIT`. Esperado: FAIL.

- [ ] **Step 3: Implementar.** `ServicoController`:

```java
package com.seusistema.barbearia.servico;

import com.seusistema.barbearia.servico.dto.*;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/app/servicos")
public class ServicoController {

    private final ServicoService servicoService;

    public ServicoController(ServicoService servicoService) {
        this.servicoService = servicoService;
    }

    @GetMapping
    public List<ServicoDTO> listar(@AuthenticationPrincipal Long barbeiroId) {
        return servicoService.listarPorBarbeiro(barbeiroId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ServicoDTO criar(@AuthenticationPrincipal Long barbeiroId,
                            @Valid @RequestBody SalvarServicoRequest req) {
        return servicoService.criar(barbeiroId, req);
    }

    @PutMapping("/{id}")
    public ServicoDTO atualizar(@AuthenticationPrincipal Long barbeiroId, @PathVariable Long id,
                                @Valid @RequestBody SalvarServicoRequest req) {
        return servicoService.atualizar(barbeiroId, id, req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void excluir(@AuthenticationPrincipal Long barbeiroId, @PathVariable Long id) {
        servicoService.excluir(barbeiroId, id);
    }
}
```

Métodos novos do `ServicoService` seguem o padrão: buscar com `findByIdAndBarbeiroId`, mapear request → entidade (`duracaoMinutos` null vira 60), salvar, devolver DTO.

- [ ] **Step 4: Rodar** — esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(backend): CRUD de serviços no app"`

---

### Task 8: Horário de funcionamento + exceções (/app)

**Files:**
- Create: `backend/src/main/java/com/seusistema/barbearia/horario/HorarioService.java`, `horario/HorarioController.java`, `horario/dto/HorarioFuncionamentoDTO.java`, `horario/dto/SalvarHorarioRequest.java`, `horario/dto/ExcecaoHorarioDTO.java`, `horario/dto/SalvarExcecaoRequest.java`
- Test: `backend/src/test/java/com/seusistema/barbearia/horario/HorarioCrudTest.java`

**Interfaces:**
- Consumes: `HorarioFuncionamentoRepository`, `ExcecaoHorarioRepository` (Task 3); `authHeaders` da `IntegrationTestBase` (Task 7).
- Produces (records):
  - `HorarioFuncionamentoDTO(Long id, Integer diaSemana, LocalTime horaInicio, LocalTime horaFim, Boolean ativo)`
  - `SalvarHorarioRequest(Integer diaSemana, LocalTime horaInicio, LocalTime horaFim, Boolean ativo)` — `@NotNull @Min(0) @Max(6)` diaSemana; `@NotNull` horas; valida no service `horaInicio < horaFim` (`RegraDeNegocioException("Hora de início deve ser antes da hora de fim")`); `ativo` null vira true.
  - `ExcecaoHorarioDTO(Long id, LocalDate data, Boolean disponivel, LocalTime horaInicio, LocalTime horaFim)`
  - `SalvarExcecaoRequest(LocalDate data, Boolean disponivel, LocalTime horaInicio, LocalTime horaFim)` — `@NotNull` data; `disponivel` null vira false; se `disponivel=true`, horas obrigatórias e `horaInicio < horaFim`; se `disponivel=false`, horas ignoradas (gravar null). Data duplicada para o barbeiro → `RegraDeNegocioException("Já existe exceção para esta data")`.
  - `HorarioService`: `listarHorarios(Long barbeiroId)`, `criarHorario(Long barbeiroId, SalvarHorarioRequest)`, `atualizarHorario(Long barbeiroId, Long id, SalvarHorarioRequest)`, `excluirHorario(Long barbeiroId, Long id)`, `listarExcecoes(Long barbeiroId)`, `criarExcecao(Long barbeiroId, SalvarExcecaoRequest)`, `excluirExcecao(Long barbeiroId, Long id)`. Não encontrado → `RecursoNaoEncontradoException`.
- Endpoints: `GET|POST /api/v1/app/horarios`, `PUT|DELETE /api/v1/app/horarios/{id}`, `GET|POST /api/v1/app/horarios/excecoes`, `DELETE /api/v1/app/horarios/excecoes/{id}`. **Atenção à ordem dos mappings**: `/horarios/excecoes` não pode colidir com `/horarios/{id}` — usar métodos com paths explícitos no mesmo controller: `@GetMapping("/excecoes")`/`@PostMapping("/excecoes")`/`@DeleteMapping("/excecoes/{id}")` ao lado de `@PutMapping("/{id}")`/`@DeleteMapping("/{id}")`. Spring resolve o path literal (`excecoes`) antes do path variável (`{id}`) independente da ordem de declaração no código.

- [ ] **Step 1: Teste falhando** — `HorarioCrudTest extends IntegrationTestBase` (limpa banco, cria barbeiro, login). Casos:
  - POST horário {diaSemana:1, 09:00–18:00} → 201; GET lista com 1.
  - POST com diaSemana=7 → 400 com `campos.diaSemana`.
  - POST com horaInicio ≥ horaFim → 400 `{"erro": "Hora de início deve ser antes da hora de fim"}`.
  - PUT muda janela → 200; DELETE → 204.
  - POST exceção folga {data, disponivel:false} → 201; GET excecoes com 1, horas null.
  - POST exceção especial {data, disponivel:true, 10:00–14:00} → 201 com horas.
  - POST exceção duplicada (mesma data) → 400 `{"erro": "Já existe exceção para esta data"}`.
  - DELETE exceção → 204.
  - Escopo: operar horário de outro barbeiro → 404.

- [ ] **Step 2: Rodar** — `./mvnw -q test -Dtest=HorarioCrudTest`. Esperado: FAIL.

- [ ] **Step 3: Implementar** `HorarioService` (validações acima, mapeamento entidade↔DTO) e `HorarioController`:

```java
package com.seusistema.barbearia.horario;

import com.seusistema.barbearia.horario.dto.*;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/app/horarios")
public class HorarioController {

    private final HorarioService horarioService;

    public HorarioController(HorarioService horarioService) {
        this.horarioService = horarioService;
    }

    @GetMapping
    public List<HorarioFuncionamentoDTO> listar(@AuthenticationPrincipal Long barbeiroId) {
        return horarioService.listarHorarios(barbeiroId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public HorarioFuncionamentoDTO criar(@AuthenticationPrincipal Long barbeiroId,
                                         @Valid @RequestBody SalvarHorarioRequest req) {
        return horarioService.criarHorario(barbeiroId, req);
    }

    @PutMapping("/{id}")
    public HorarioFuncionamentoDTO atualizar(@AuthenticationPrincipal Long barbeiroId,
                                             @PathVariable Long id,
                                             @Valid @RequestBody SalvarHorarioRequest req) {
        return horarioService.atualizarHorario(barbeiroId, id, req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void excluir(@AuthenticationPrincipal Long barbeiroId, @PathVariable Long id) {
        horarioService.excluirHorario(barbeiroId, id);
    }

    @GetMapping("/excecoes")
    public List<ExcecaoHorarioDTO> listarExcecoes(@AuthenticationPrincipal Long barbeiroId) {
        return horarioService.listarExcecoes(barbeiroId);
    }

    @PostMapping("/excecoes")
    @ResponseStatus(HttpStatus.CREATED)
    public ExcecaoHorarioDTO criarExcecao(@AuthenticationPrincipal Long barbeiroId,
                                          @Valid @RequestBody SalvarExcecaoRequest req) {
        return horarioService.criarExcecao(barbeiroId, req);
    }

    @DeleteMapping("/excecoes/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void excluirExcecao(@AuthenticationPrincipal Long barbeiroId, @PathVariable Long id) {
        horarioService.excluirExcecao(barbeiroId, id);
    }
}
```

- [ ] **Step 4: Rodar** — esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(backend): CRUD de horário de funcionamento e exceções"`

---

### Task 9: DisponibilidadeService + endpoint público de disponibilidade

**Files:**
- Create: `backend/src/main/java/com/seusistema/barbearia/agendamento/DisponibilidadeService.java`, `agendamento/AgendamentoPublicoController.java` (só o GET nesta task), `agendamento/dto/DisponibilidadeDTO.java`, `config/ClockConfig.java`
- Test: `backend/src/test/java/com/seusistema/barbearia/agendamento/DisponibilidadeTest.java`

**Interfaces:**
- Consumes: `BarbeiroService.buscarAtivoPorSlug` (Task 5); repositories de horário/exceção/agendamento (Task 3).
- Produces:
  - `ClockConfig`: bean `java.time.Clock` (`Clock.system(ZoneId.of("America/Sao_Paulo"))`). Testes sobrescrevem com `Clock.fixed(...)` via `@TestConfiguration`/`@MockitoBean` quando precisarem controlar "agora".
  - `DisponibilidadeService(HorarioFuncionamentoRepository, ExcecaoHorarioRepository, AgendamentoRepository, Clock)`: `List<LocalTime> horariosLivres(Long barbeiroId, LocalDate data)`. Algoritmo:
    1. Exceção da data existe e `disponivel=false` → lista vazia.
    2. Exceção com `disponivel=true` → janela = horas da exceção; senão → janelas de `horario_funcionamento` do `dia_semana` (`data.getDayOfWeek().getValue() % 7` mapeia DayOfWeek→0=domingo) com `ativo=true`; nenhuma → vazia.
    3. Slots de hora cheia: primeiro slot = `horaInicio` arredondada para cima à hora cheia (`09:30` → `10:00`); último slot começa em `horaFim.minusHours(1)` (slot precisa caber inteiro).
    4. Remove slots com agendamento `AGENDADO`/`CONCLUIDO` no intervalo (busca agendamentos do dia e compara `dataHoraInicio`).
    5. Se `data == hoje` (pelo Clock), remove slots com início `<= agora`.
  - `DisponibilidadeDTO(LocalDate data, List<String> horarios)` — horários formato `"HH:mm"`.
- Endpoint: `GET /api/v1/public/{slug}/disponibilidade?data=2026-08-03` → 200 `DisponibilidadeDTO` | 404 slug/INATIVO | 400 se `data` ausente/malformada ou fora da janela (passado ou > 30 dias → `RegraDeNegocioException("Data fora do período de agendamento")`).

- [ ] **Step 1: Teste falhando** — `DisponibilidadeTest extends IntegrationTestBase` com `Clock` fixado (registrar `@TestConfiguration` interna com `@Bean @Primary Clock clockDeTeste()` retornando `Clock.fixed` em `2026-08-03T10:30` America/Sao_Paulo — segunda-feira; **nome do método não pode ser `clock()`** — colidiria com o bean `clock()` do `ClockConfig` de produção e o Spring Boot 3.4 rejeita com `BeanDefinitionOverrideException` antes mesmo do `@Primary` desempatar). Montar barbeiro com horário seg 09:00–18:00. Casos (via HTTP no endpoint público):
  - Dia futuro sem agendamentos → slots 09:00…17:00 (9 slots).
  - Com agendamento AGENDADO às 14:00 → 14:00 some; CANCELADO às 15:00 → 15:00 continua.
  - Exceção folga na data → lista vazia.
  - Exceção especial 10:00–14:00 → slots 10:00…13:00.
  - Hoje (2026-08-03) → slots ≤ 10:30 somem (09:00 e 10:00 fora; 11:00 em diante).
  - Dia sem horário cadastrado (domingo) → vazia.
  - `data` no passado ou hoje+31 → 400.
  - Slug inexistente → 404.
  - Janela quebrada 09:30–12:30 → slots 10:00 e 11:00 (09:30 arredonda para 10:00; 12:00 não entra pois terminaria 13:00, depois de 12:30).

- [ ] **Step 2: Rodar** — `./mvnw -q test -Dtest=DisponibilidadeTest`. Esperado: FAIL.

- [ ] **Step 3: Implementar:**

```java
package com.seusistema.barbearia.agendamento;

import com.seusistema.barbearia.horario.*;
import java.time.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Service;

@Service
public class DisponibilidadeService {

    private final HorarioFuncionamentoRepository horarios;
    private final ExcecaoHorarioRepository excecoes;
    private final AgendamentoRepository agendamentos;
    private final Clock clock;

    public DisponibilidadeService(HorarioFuncionamentoRepository horarios,
                                  ExcecaoHorarioRepository excecoes,
                                  AgendamentoRepository agendamentos,
                                  Clock clock) {
        this.horarios = horarios;
        this.excecoes = excecoes;
        this.agendamentos = agendamentos;
        this.clock = clock;
    }

    public List<LocalTime> horariosLivres(Long barbeiroId, LocalDate data) {
        List<LocalTime[]> janelas = janelasDoDia(barbeiroId, data);
        if (janelas.isEmpty()) {
            return List.of();
        }

        Set<LocalTime> ocupados = agendamentos
            .findByBarbeiroIdAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThanOrderByDataHoraInicio(
                barbeiroId, data.atStartOfDay(), data.plusDays(1).atStartOfDay())
            .stream()
            .filter(a -> a.getStatus() == StatusAgendamento.AGENDADO
                      || a.getStatus() == StatusAgendamento.CONCLUIDO)
            .map(a -> a.getDataHoraInicio().toLocalTime())
            .collect(java.util.stream.Collectors.toSet());

        LocalDateTime agora = LocalDateTime.now(clock);
        List<LocalTime> livres = new ArrayList<>();
        for (LocalTime[] janela : janelas) {
            LocalTime slot = arredondarParaCima(janela[0]);
            while (!slot.plusHours(1).isAfter(janela[1]) && !slot.plusHours(1).equals(LocalTime.MIDNIGHT)) {
                boolean passado = data.equals(agora.toLocalDate()) && !data.atTime(slot).isAfter(agora);
                if (!ocupados.contains(slot) && !passado) {
                    livres.add(slot);
                }
                slot = slot.plusHours(1);
            }
        }
        return livres.stream().sorted().toList();
    }

    private List<LocalTime[]> janelasDoDia(Long barbeiroId, LocalDate data) {
        var excecao = excecoes.findByBarbeiroIdAndData(barbeiroId, data);
        if (excecao.isPresent()) {
            ExcecaoHorario e = excecao.get();
            if (!e.isDisponivel()) {
                return List.of();
            }
            // List.of(E) vs List.of(E...) são ambíguos para um array cru — o type
            // witness força E=LocalTime[] (lista de UM elemento, a janela).
            return List.<LocalTime[]>of(new LocalTime[]{e.getHoraInicio(), e.getHoraFim()});
        }
        int diaSemana = data.getDayOfWeek().getValue() % 7;
        return horarios.findByBarbeiroIdAndDiaSemanaAndAtivoTrue(barbeiroId, diaSemana).stream()
            .map(h -> new LocalTime[]{h.getHoraInicio(), h.getHoraFim()})
            .toList();
    }

    private LocalTime arredondarParaCima(LocalTime hora) {
        return hora.getMinute() == 0 && hora.getSecond() == 0
            ? hora
            : hora.plusHours(1).withMinute(0).withSecond(0).withNano(0);
    }
}
```

`AgendamentoPublicoController` (por ora só o GET):

```java
package com.seusistema.barbearia.agendamento;

import com.seusistema.barbearia.agendamento.dto.DisponibilidadeDTO;
import com.seusistema.barbearia.barbeiro.*;
import com.seusistema.barbearia.common.exception.RegraDeNegocioException;
import java.time.Clock;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/public/{slug}")
public class AgendamentoPublicoController {

    private final BarbeiroService barbeiroService;
    private final DisponibilidadeService disponibilidadeService;
    private final Clock clock;

    public AgendamentoPublicoController(BarbeiroService barbeiroService,
                                        DisponibilidadeService disponibilidadeService,
                                        Clock clock) {
        this.barbeiroService = barbeiroService;
        this.disponibilidadeService = disponibilidadeService;
        this.clock = clock;
    }

    @GetMapping("/disponibilidade")
    public DisponibilidadeDTO disponibilidade(@PathVariable String slug,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate data) {
        Barbeiro b = barbeiroService.buscarAtivoPorSlug(slug);
        LocalDate hoje = LocalDate.now(clock);
        if (data.isBefore(hoje) || data.isAfter(hoje.plusDays(30))) {
            throw new RegraDeNegocioException("Data fora do período de agendamento");
        }
        var horarios = disponibilidadeService.horariosLivres(b.getId(), data).stream()
            .map(h -> h.format(DateTimeFormatter.ofPattern("HH:mm")))
            .toList();
        return new DisponibilidadeDTO(data, horarios);
    }
}
```

Adicionar ao `GlobalExceptionHandler` um handler de `MethodArgumentTypeMismatchException` e `MissingServletRequestParameterException` → 400 `{"erro": "Parâmetro inválido"}`.

- [ ] **Step 4: Rodar** — esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(backend): cálculo de disponibilidade e endpoint público"`

---

### Task 10: Agendamento público (POST) — upsert de cliente, validações e conflito concorrente

**Files:**
- Create: `backend/src/main/java/com/seusistema/barbearia/agendamento/AgendamentoService.java`, `agendamento/dto/CriarAgendamentoRequest.java`, `agendamento/dto/AgendamentoCriadoDTO.java`, `cliente/ClienteService.java`, `common/validacao/TelefoneBR.java` (utilitário estático)
- Modify: `agendamento/AgendamentoPublicoController.java` (adicionar POST)
- Test: `backend/src/test/java/com/seusistema/barbearia/agendamento/AgendamentoPublicoTest.java`, `backend/src/test/java/com/seusistema/barbearia/agendamento/ConcorrenciaAgendamentoTest.java`

**Interfaces:**
- Consumes: `DisponibilidadeService.horariosLivres` (Task 9); `ClienteRepository` (Task 3); `buscarAtivoPorSlug` (Task 5).
- Produces:
  - `TelefoneBR.normalizar(String)` → só dígitos; `TelefoneBR.valido(String normalizado)` → 10 ou 11 dígitos.
  - `ClienteService.upsert(Long barbeiroId, String nome, String telefoneNormalizado)` → `Cliente` (busca por barbeiro+telefone; existe → atualiza nome; não → cria).
  - `AgendamentoService.criarPublico(String slug, CriarAgendamentoRequest req)` → `AgendamentoCriadoDTO`. Validações em ordem: barbeiro ativo (404) → telefone válido (`RegraDeNegocioException("Telefone inválido")`) → serviço pertence ao barbeiro (404 `"Serviço não encontrado"`) → `dataHora` é hora cheia (`RegraDeNegocioException("Horário deve ser em hora cheia")`) → janela temporal: `dataHora > agora` e `≤ hoje+30d` (`"Data fora do período de agendamento"`) → slot está em `horariosLivres` (`"Horário indisponível"`) → upsert cliente → save (constraint pega corrida; `DataIntegrityViolationException` sobe para o handler → 409).
  - Records: `CriarAgendamentoRequest(Long servicoId, String dataHora, String nomeCliente, String telefoneCliente)` — `@NotNull` servicoId, `@NotBlank` demais; `dataHora` ISO `2026-08-03T14:00:00` parseado no service (malformado → `RegraDeNegocioException("Data/hora inválida")`); `AgendamentoCriadoDTO(Long id, String servicoNome, LocalDateTime dataHoraInicio, String nomeCliente)`.
- Endpoint: `POST /api/v1/public/{slug}/agendamentos` → 201 `AgendamentoCriadoDTO` | 400 | 404 | 409.
- **Transação**: `criarPublico` anotado `@Transactional`. **Verificado por execução** (não é "estoura no flush/commit de fim de método", como se pensava antes de rodar): `Agendamento` usa `@GeneratedValue(strategy = GenerationType.IDENTITY)`, o que obriga o Hibernate a executar o INSERT SINCRONAMENTE dentro do `save()` (precisa do ID gerado de volta) — não pode adiar pro commit. A violação da constraint já estoura dentro do `save()`, ainda dentro do método `@Transactional`, e o Spring traduz para `DataIntegrityViolationException` ali mesmo; nenhum `saveAndFlush` é necessário. Essa conclusão só vale enquanto `Agendamento` usar `IDENTITY` — se a estratégia mudar (ex.: `SEQUENCE` com batch), o INSERT pode deixar de ser síncrono e a premissa cai.

- [ ] **Step 1: Teste funcional falhando** — `AgendamentoPublicoTest extends IntegrationTestBase` (Clock fixado como na Task 9; barbeiro seg 09:00–18:00, 1 serviço). Casos:
  - POST válido (14:00 de segunda futura) → 201; banco tem agendamento AGENDADO com fim = 15:00; cliente criado com telefone normalizado (`"(11) 98765-4321"` → `"11987654321"`).
  - Mesmo telefone com máscara diferente em segundo agendamento (outro horário) → não duplica cliente (count = 1), nome atualizado.
  - Telefone `"987654321"` (9 dígitos) → 400 `{"erro": "Telefone inválido"}`.
  - `dataHora` 14:30 → 400 hora cheia.
  - Slot ocupado (pré-inserido) → 400 `{"erro": "Horário indisponível"}`.
  - Serviço de outro barbeiro → 404.
  - `dataHora` no passado → 400.
  - Slug INATIVO → 404.

- [ ] **Step 2: Teste de concorrência falhando** — `ConcorrenciaAgendamentoTest`: 2 threads com `CyclicBarrier` disparando o mesmo POST HTTP (mesmo slot, telefones diferentes) simultaneamente; exatamente uma resposta 201 e uma 409 com a mensagem amigável:

```java
package com.seusistema.barbearia.agendamento;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.IntegrationTestBase;
import java.util.List;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.*;

class ConcorrenciaAgendamentoTest extends IntegrationTestBase {

    @Autowired TestRestTemplate rest;

    // @BeforeEach monta barbeiro "joao" com horário e serviço (mesmo setup da AgendamentoPublicoTest,
    // extrair helper comum na própria classe de teste ou na IntegrationTestBase)

    @Test
    void duasRequisicoesSimultaneasParaOMesmoSlotUmaGanhaOutraRecebe409() throws Exception {
        var barrier = new CyclicBarrier(2);
        java.util.function.IntFunction<Callable<ResponseEntity<String>>> chamada = i -> () -> {
            var body = new java.util.HashMap<String, Object>();
            body.put("servicoId", servicoId);
            body.put("dataHora", "2026-08-10T14:00:00");
            body.put("nomeCliente", "Cliente " + i);
            body.put("telefoneCliente", "1198765432" + i); // 11 dígitos, distinto por thread
            barrier.await();
            return rest.postForEntity("/api/v1/public/joao/agendamentos", body, String.class);
        };

        var executor = Executors.newFixedThreadPool(2);
        List<Future<ResponseEntity<String>>> futures =
            executor.invokeAll(List.of(chamada.apply(1), chamada.apply(2)));
        executor.shutdown();

        var statusList = futures.stream().map(f -> {
            try { return f.get().getStatusCode().value(); }
            catch (Exception e) { throw new RuntimeException(e); }
        }).sorted().toList();

        // O CyclicBarrier só sincroniza o disparo do HTTP, não garante que as duas
        // transações cheguem juntas até o INSERT: se a requisição A commitar antes da
        // checagem de disponibilidade da B rodar, B recebe 400 "Horário indisponível"
        // (via horariosLivres) em vez de correr até a constraint e receber 409. Ambos
        // os desfechos previnem o double-booking corretamente — exigir sempre 409
        // torna o teste flaky sob carga real (verificado empiricamente: falha em
        // execução da suíte completa, nunca isoladamente rodado sozinho).
        assertThat(statusList).hasSize(2).contains(201);
        var respostaPerdedora = futures.stream().map(f -> {
            try { return f.get(); } catch (Exception e) { throw new RuntimeException(e); }
        }).filter(r -> r.getStatusCode().value() != 201).findFirst().orElseThrow();
        int statusPerdedor = respostaPerdedora.getStatusCode().value();
        assertThat(statusPerdedor).isIn(400, 409);
        if (statusPerdedor == 409) {
            assertThat(respostaPerdedora.getBody()).contains("Esse horário acabou de ser reservado");
        } else {
            assertThat(respostaPerdedora.getBody()).contains("Horário indisponível");
        }
    }
}
```

Nota: os dois POSTs passam a checagem de `horariosLivres` (corrida) e só a exclusion constraint decide — é exatamente o cenário que valida a trava no banco. Telefones devem ser distintos e válidos (11 dígitos) para o upsert não serializar as transações na unique de `clientes`.

- [ ] **Step 3: Rodar** — esperado: FAIL.

- [ ] **Step 4: Implementar.** `TelefoneBR`:

```java
package com.seusistema.barbearia.common.validacao;

public final class TelefoneBR {

    private TelefoneBR() {}

    public static String normalizar(String telefone) {
        return telefone == null ? "" : telefone.replaceAll("\\D", "");
    }

    public static boolean valido(String normalizado) {
        return normalizado.length() == 10 || normalizado.length() == 11;
    }
}
```

`ClienteService.upsert` (`@Service`, usa `ClienteRepository`); `AgendamentoService.criarPublico` com a cadeia de validações da seção **Interfaces** e `AgendamentoPublicoController`:

```java
@PostMapping("/agendamentos")
@ResponseStatus(HttpStatus.CREATED)
public AgendamentoCriadoDTO criar(@PathVariable String slug,
                                  @Valid @RequestBody CriarAgendamentoRequest req) {
    return agendamentoService.criarPublico(slug, req);
}
```

- [ ] **Step 5: Rodar** — `./mvnw -q test -Dtest='AgendamentoPublicoTest,ConcorrenciaAgendamentoTest'`. Esperado: PASS. Suíte completa verde.

- [ ] **Step 6: Commit** — `git commit -am "feat(backend): agendamento público com upsert de cliente e trava de concorrência"`

---

### Task 11: Agenda do dia, checkout e cancelamento (/app)

**Files:**
- Create: `backend/src/main/java/com/seusistema/barbearia/agendamento/AgendamentoController.java`, `agendamento/dto/AgendamentoDTO.java`, `agendamento/dto/FinalizarRequest.java`, `agendamento/dto/CancelarRequest.java`
- Modify: `agendamento/AgendamentoService.java`, `agendamento/AgendamentoRepository.java` (novo `@Query` com `JOIN FETCH` p/ `listarDia`)
- Test: `backend/src/test/java/com/seusistema/barbearia/agendamento/AgendaAppTest.java`

**Interfaces:**
- Consumes: `AgendamentoService`, `AgendamentoRepository` (Tasks 3/10); `@AuthenticationPrincipal Long barbeiroId`.
- Produces:
  - `AgendamentoDTO(Long id, LocalDateTime dataHoraInicio, LocalDateTime dataHoraFim, String status, String formaPagamento, String servicoNome, BigDecimal servicoPreco, String clienteNome, String clienteTelefone)` — telefone incluso: barbeiro usa para contato manual no no-show.
  - `FinalizarRequest(FormaPagamento formaPagamento)` — `@NotNull`.
  - `CancelarRequest(StatusAgendamento status)` — `@NotNull`; service aceita apenas `CANCELADO` ou `NAO_COMPARECEU`, senão `RegraDeNegocioException("Status de cancelamento inválido")`.
  - Novos métodos no `AgendamentoService` (todos escopados por `findByIdAndBarbeiroId`, 404 se não achar):
    - `List<AgendamentoDTO> listarDia(Long barbeiroId, LocalDate data)` — ordenado por início; entidades com `JOIN FETCH` de cliente/serviço (query `@Query` no repository: `SELECT a FROM Agendamento a JOIN FETCH a.cliente JOIN FETCH a.servico WHERE a.barbeiroId = :barbeiroId AND a.dataHoraInicio >= :ini AND a.dataHoraInicio < :fim ORDER BY a.dataHoraInicio`, com `fim` exclusivo = `data.plusDays(1).atStartOfDay()`) para evitar N+1/lazy na montagem do DTO.
    - `AgendamentoDTO finalizar(Long barbeiroId, Long id, FinalizarRequest req)` — só de `AGENDADO` (senão `RegraDeNegocioException("Agendamento não pode ser finalizado")`); seta `CONCLUIDO` + forma.
    - `AgendamentoDTO cancelar(Long barbeiroId, Long id, CancelarRequest req)` — só de `AGENDADO` (senão `"Agendamento não pode ser cancelado"`); seta o status pedido; `forma_pagamento` permanece null.
- Endpoints: `GET /api/v1/app/agendamentos?data=2026-08-03` → 200 lista; `POST /api/v1/app/agendamentos/{id}/finalizar` → 200; `POST /api/v1/app/agendamentos/{id}/cancelar` → 200.

- [ ] **Step 1: Teste falhando** — `AgendaAppTest extends IntegrationTestBase` (barbeiro + login + serviço + cliente + 2 agendamentos no dia via repositories). Casos:
  - GET dia → 200, 2 itens ordenados, com `servicoNome`, `clienteTelefone`.
  - GET outro dia → lista vazia.
  - POST finalizar {formaPagamento: "PIX"} → 200; banco: CONCLUIDO + PIX.
  - POST finalizar em agendamento já CONCLUIDO → 400.
  - POST cancelar {status: "NAO_COMPARECEU"} → 200; banco reflete; slot volta a aparecer na disponibilidade pública (assert extra chamando o GET público).
  - POST cancelar {status: "CONCLUIDO"} → 400 status inválido.
  - Agendamento de outro barbeiro → 404.

- [ ] **Step 2: Rodar** — esperado: FAIL.

- [ ] **Step 3: Implementar.** `AgendamentoController`:

```java
package com.seusistema.barbearia.agendamento;

import com.seusistema.barbearia.agendamento.dto.*;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.List;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/app/agendamentos")
public class AgendamentoController {

    private final AgendamentoService agendamentoService;

    public AgendamentoController(AgendamentoService agendamentoService) {
        this.agendamentoService = agendamentoService;
    }

    @GetMapping
    public List<AgendamentoDTO> listarDia(@AuthenticationPrincipal Long barbeiroId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate data) {
        return agendamentoService.listarDia(barbeiroId, data);
    }

    @PostMapping("/{id}/finalizar")
    public AgendamentoDTO finalizar(@AuthenticationPrincipal Long barbeiroId, @PathVariable Long id,
                                    @Valid @RequestBody FinalizarRequest req) {
        return agendamentoService.finalizar(barbeiroId, id, req);
    }

    @PostMapping("/{id}/cancelar")
    public AgendamentoDTO cancelar(@AuthenticationPrincipal Long barbeiroId, @PathVariable Long id,
                                   @Valid @RequestBody CancelarRequest req) {
        return agendamentoService.cancelar(barbeiroId, id, req);
    }
}
```

Métodos do service com `@Transactional`; mapeamento entidade → `AgendamentoDTO` num método privado `toDTO(Agendamento a)`.

- [ ] **Step 4: Rodar** — esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(backend): agenda do dia, checkout e cancelamento no app"`

---

### Task 12: Caixa (/app)

**Files:**
- Create: `backend/src/main/java/com/seusistema/barbearia/caixa/CaixaService.java`, `caixa/CaixaController.java`, `caixa/dto/CaixaDTO.java`
- Test: `backend/src/test/java/com/seusistema/barbearia/caixa/CaixaTest.java`

**Interfaces:**
- Consumes: `AgendamentoRepository.findByBarbeiroIdAndStatusAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThan` (Task 3); `FormaPagamento` (Task 3).
- Produces: `CaixaDTO(BigDecimal total, int quantidade, Map<FormaPagamento, BigDecimal> porFormaPagamento)` — mapa sempre com as 4 formas (ausentes = `BigDecimal.ZERO`, usar `EnumMap` para ordem estável). `CaixaService.consultar(Long barbeiroId, String periodo, String data)`:
  - `periodo="dia"` + `data=2026-07-18` → intervalo do dia; `periodo="mes"` + `data=2026-07` → primeiro a último dia do mês (`YearMonth.parse`).
  - Outro `periodo` ou `data` malformada → `RegraDeNegocioException("Período inválido")`.
  - Soma `servico.preco` dos agendamentos `CONCLUIDO` no intervalo, agrupado por `formaPagamento`.
- Endpoint: `GET /api/v1/app/caixa?periodo=dia&data=2026-07-18` → 200 `CaixaDTO` | 400.

- [ ] **Step 1: Teste falhando** — `CaixaTest extends IntegrationTestBase`: barbeiro + serviços de preços distintos (50.00 e 30.00); agendamentos: 2 CONCLUIDO/PIX (50+50), 1 CONCLUIDO/DINHEIRO (30), 1 AGENDADO (50), 1 CANCELADO (30), espalhados em dois dias do mesmo mês. Casos:
  - `?periodo=dia&data=<dia1>` → total/quantidade/mapa contando só os CONCLUIDO do dia 1.
  - `?periodo=mes&data=<ano-mes>` → total 130.00, quantidade 3, PIX 100.00, DINHEIRO 30.00, DEBITO 0, CREDITO 0.
  - `?periodo=semana` → 400 `{"erro": "Período inválido"}`.
  - `?periodo=mes&data=2026-13` → 400.

- [ ] **Step 2: Rodar** — esperado: FAIL.

- [ ] **Step 3: Implementar:**

```java
package com.seusistema.barbearia.caixa;

import com.seusistema.barbearia.agendamento.*;
import com.seusistema.barbearia.caixa.dto.CaixaDTO;
import com.seusistema.barbearia.common.exception.RegraDeNegocioException;
import java.math.BigDecimal;
import java.time.*;
import java.time.format.DateTimeParseException;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CaixaService {

    private final AgendamentoRepository agendamentos;

    public CaixaService(AgendamentoRepository agendamentos) {
        this.agendamentos = agendamentos;
    }

    @Transactional(readOnly = true)
    public CaixaDTO consultar(Long barbeiroId, String periodo, String data) {
        LocalDateTime inicio;
        LocalDateTime fim;
        try {
            if ("dia".equals(periodo)) {
                LocalDate dia = LocalDate.parse(data);
                inicio = dia.atStartOfDay();
                fim = dia.plusDays(1).atStartOfDay();   // exclusivo
            } else if ("mes".equals(periodo)) {
                YearMonth mes = YearMonth.parse(data);
                inicio = mes.atDay(1).atStartOfDay();
                fim = mes.plusMonths(1).atDay(1).atStartOfDay();   // exclusivo
            } else {
                throw new RegraDeNegocioException("Período inválido");
            }
        } catch (DateTimeParseException e) {
            throw new RegraDeNegocioException("Período inválido");
        }

        List<Agendamento> concluidos = agendamentos
            .findByBarbeiroIdAndStatusAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThan(
                barbeiroId, StatusAgendamento.CONCLUIDO, inicio, fim);   // fim exclusivo

        Map<FormaPagamento, BigDecimal> porForma = new EnumMap<>(FormaPagamento.class);
        for (FormaPagamento f : FormaPagamento.values()) {
            porForma.put(f, BigDecimal.ZERO);
        }
        BigDecimal total = BigDecimal.ZERO;
        for (Agendamento a : concluidos) {
            BigDecimal preco = a.getServico().getPreco();
            total = total.add(preco);
            porForma.merge(a.getFormaPagamento(), preco, BigDecimal::add);
        }
        return new CaixaDTO(total, concluidos.size(), porForma);
    }
}
```

`CaixaController`: `GET /api/v1/app/caixa` com `@RequestParam String periodo, @RequestParam String data` → `caixaService.consultar(barbeiroId, periodo, data)`. Nota: `@Transactional(readOnly = true)` mantém a sessão aberta para o lazy `a.getServico()`; alternativa é `JOIN FETCH` — qualquer uma serve, registrar a escolhida.

- [ ] **Step 4: Rodar** — esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(backend): caixa dia/mês por forma de pagamento"`

---

### Task 13: Rate limit por IP (Bucket4j) nas duas rotas públicas sensíveis

**Files:**
- Create: `backend/src/main/java/com/seusistema/barbearia/common/ratelimit/RateLimitInterceptor.java`, `config/WebConfig.java`
- Test: `backend/src/test/java/com/seusistema/barbearia/common/RateLimitIT.java`

**Interfaces:**
- Consumes: nada novo.
- Produces: `RateLimitInterceptor` (o do MVP doc seção 5.3, verbatim — 3 req/10min por IP, `ConcurrentHashMap` em memória, 429 sem body extra: adicionar `response.setContentType("application/json;charset=UTF-8")` e body `{"erro": "Muitas requisições. Tente novamente em alguns minutos."}`). `WebConfig implements WebMvcConfigurer` registra o interceptor **apenas** nos paths `/api/v1/public/*/disponibilidade` e `/api/v1/public/*/agendamentos`.

- [ ] **Step 1: Teste falhando** — `RateLimitIT extends IntegrationTestBase` (barbeiro com horário; Clock real ok):
  - 3 GETs `/disponibilidade?data=<amanhã>` → nenhum 429; 4º → 429 com `{"erro": ...}`.
  - Mistura conta no mesmo balde: 2 GETs disponibilidade + 1 POST agendamentos + 1 GET disponibilidade → 4º recebe 429.
  - `GET /api/v1/public/{slug}` e `GET .../servicos` repetidos 5× → nunca 429 (fora do escopo do limite).
  - Nota: cada método de teste precisa de balde limpo — expor `void limpar()` no interceptor (limpa o map) e chamar no `@BeforeEach` do teste. IP nos testes é sempre localhost, então o balde é compartilhado entre métodos sem isso.

- [ ] **Step 2: Rodar** — esperado: FAIL (sem 429).

- [ ] **Step 3: Implementar** interceptor (MVP doc) + registro:

```java
package com.seusistema.barbearia.config;

import com.seusistema.barbearia.common.ratelimit.RateLimitInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final RateLimitInterceptor rateLimitInterceptor;

    public WebConfig(RateLimitInterceptor rateLimitInterceptor) {
        this.rateLimitInterceptor = rateLimitInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(rateLimitInterceptor)
            .addPathPatterns("/api/v1/public/*/disponibilidade", "/api/v1/public/*/agendamentos");
    }
}
```

- [ ] **Step 4: Rodar** — esperado: PASS. Rodar suíte completa.

- [ ] **Step 5: Commit** — `git commit -am "feat(backend): rate limit por IP nas rotas públicas de disponibilidade e agendamento"`

---

### Task 14: README + verificação final da Fase 1

**Files:**
- Create: `README.md` (raiz)
- Modify: nada de código (só se a verificação achar furo)

- [ ] **Step 1: Escrever `README.md`**: visão do projeto (1 parágrafo + link pro MVP doc); pré-requisitos (Java 21, Docker, Node 20+, Flutter — os dois últimos marcados "Fase 2/3"); subir banco (`docker compose up -d`); rodar backend (`cd backend && ./mvnw spring-boot:run -Dspring-boot.run.profiles=dev`); criar barbeiro via CLI (`./mvnw spring-boot:run -Dspring-boot.run.arguments="--criar-barbeiro --nome='João' --email=joao@x.com --senha=senha123 --slug=joao"`); credencial do seed dev (`dev@barbearia.local` / `senha123`); rodar testes (`./mvnw test` — exige Docker para Testcontainers); tabela resumida de endpoints (copiar seção 10 do MVP doc); variáveis de ambiente (`DB_URL`, `DB_USER`, `DB_PASSWORD`, `JWT_SECRET`).

- [ ] **Step 2: Verificação do zero** (definição de pronto da Fase 1):

```bash
docker compose down -v && docker compose up -d && sleep 5
cd backend && ./mvnw -q clean test
```

Esperado: migrations rodam do zero no container novo, suíte inteira verde (disponibilidade, concorrência 409, checkout+caixa, rate limit 429, JWT 401). Registrar saída.

- [ ] **Step 3: Commit** — `git add -A && git commit -m "docs: README com instruções de execução — fecha Fase 1"`

- [ ] **Step 4: Checkpoint de fase**: solicitar revisão do usuário antes de iniciar a Fase 2. Registrar resumo na memória (claude-mem): decisões, concluído, pendências, desvios.

---

# FASE 2 — Web público (React + TypeScript + Vite)

Pré-condição: Fase 1 revisada e verde. Sem router, sem estado global, sem login. Testes com Vitest + Testing Library (jsdom).

### Task 15: Scaffold Vite + types + API client

**Files:**
- Create: `web/` (via `npm create vite`), `web/src/types/dto.ts`, `web/src/api/httpClient.ts`, `web/src/api/agendamentoPublicoApi.ts`, `web/.env.development`
- Test: `web/src/api/agendamentoPublicoApi.test.ts`

**Interfaces:**
- Produces (consumidos pelas Tasks 16–18):

```typescript
// types/dto.ts — espelham os DTOs públicos do backend (Tasks 6, 9, 10)
export interface BarbeiroPublicoDTO { nome: string; slug: string; telefone: string | null; }
export interface ServicoDTO { id: number; nome: string; preco: number; duracaoMinutos: number; }
export interface DisponibilidadeDTO { data: string; horarios: string[]; }
export interface CriarAgendamentoRequest {
  servicoId: number; dataHora: string; nomeCliente: string; telefoneCliente: string;
}
export interface AgendamentoCriadoDTO {
  id: number; servicoNome: string; dataHoraInicio: string; nomeCliente: string;
}
export interface ErroAPI { erro: string; campos?: Record<string, string>; }
```

  - `httpClient.ts`: `export class ApiError extends Error { constructor(public status: number, public body: ErroAPI) }`; `export async function api<T>(path: string, init?: RequestInit): Promise<T>` — `fetch` sobre `import.meta.env.VITE_API_URL`, JSON, lança `ApiError` em não-2xx (parseando o body `{erro}`).
  - `agendamentoPublicoApi.ts`: `getBarbeiro(slug)`, `getServicos(slug)`, `getDisponibilidade(slug, data: string /* yyyy-MM-dd */)`, `criarAgendamento(slug, req: CriarAgendamentoRequest)` — todas tipadas com os DTOs acima.

- [ ] **Step 1: Scaffold**

```bash
cd /home/artur/Projetos/Barbearia
npm create vite@latest web -- --template react-ts
cd web && npm install
npm install @tanstack/react-query zod
npm install -D vitest @testing-library/react @testing-library/user-event @testing-library/jest-dom jsdom
```

Adicionar em `web/package.json` scripts: `"test": "vitest run"`. Criar `web/vitest.config.ts` (environment jsdom, globals true, setupFiles com jest-dom). `web/.env.development`: `VITE_API_URL=http://localhost:8080`.

- [ ] **Step 2: Teste falhando** — `agendamentoPublicoApi.test.ts`: mocka `global.fetch` (vi.stubGlobal); casos: `getServicos` monta URL `/api/v1/public/joao/servicos` e retorna JSON tipado; resposta 409 → lança `ApiError` com `status=409` e `body.erro` preservado; 429 idem.

- [ ] **Step 3: Rodar** — `npm test`. Esperado: FAIL.

- [ ] **Step 4: Implementar** `types/dto.ts` (acima), `httpClient.ts`:

```typescript
import type { ErroAPI } from '../types/dto';

export class ApiError extends Error {
  constructor(public status: number, public body: ErroAPI) {
    super(body.erro);
  }
}

const BASE_URL = import.meta.env.VITE_API_URL ?? '';

export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${BASE_URL}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...init,
  });
  if (!response.ok) {
    // Checar a CHAVE `erro`, não a parseabilidade: o corpo de erro padrão do Boot
    // ({"timestamp","status","error","path"}) é JSON válido e sobrescreveria o
    // fallback, deixando body.erro undefined. O backend tem catch-all garantindo
    // `erro` em toda resposta tratada, mas o guard não depende disso.
    let body: ErroAPI = { erro: 'Erro inesperado. Tente novamente.' };
    try {
      const json = await response.json();
      if (json && typeof json.erro === 'string') body = json;
    } catch { /* corpo não-JSON */ }
    throw new ApiError(response.status, body);
  }
  return response.json() as Promise<T>;
}
```

e `agendamentoPublicoApi.ts`:

```typescript
import { api } from './httpClient';
import type {
  AgendamentoCriadoDTO, BarbeiroPublicoDTO, CriarAgendamentoRequest,
  DisponibilidadeDTO, ServicoDTO,
} from '../types/dto';

export const getBarbeiro = (slug: string) =>
  api<BarbeiroPublicoDTO>(`/api/v1/public/${slug}`);

export const getServicos = (slug: string) =>
  api<ServicoDTO[]>(`/api/v1/public/${slug}/servicos`);

export const getDisponibilidade = (slug: string, data: string) =>
  api<DisponibilidadeDTO>(`/api/v1/public/${slug}/disponibilidade?data=${data}`);

export const criarAgendamento = (slug: string, req: CriarAgendamentoRequest) =>
  api<AgendamentoCriadoDTO>(`/api/v1/public/${slug}/agendamentos`, {
    method: 'POST',
    body: JSON.stringify(req),
  });
```

- [ ] **Step 5: Rodar** — `npm test`. Esperado: PASS.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat(web): scaffold Vite + tipos e client da API pública"`

---

### Task 16: useAgendamentoFlow (state machine) + schema Zod

**Files:**
- Create: `web/src/hooks/useAgendamentoFlow.ts`, `web/src/validacao/clienteSchema.ts`
- Test: `web/src/hooks/useAgendamentoFlow.test.ts`, `web/src/validacao/clienteSchema.test.ts`

**Interfaces:**
- Consumes: `ServicoDTO` (Task 15).
- Produces:

```typescript
// hooks/useAgendamentoFlow.ts
export type Etapa = 'servico' | 'horario' | 'identificacao' | 'sucesso';

export interface AgendamentoFlowState {
  etapa: Etapa;
  servicoSelecionado?: ServicoDTO;
  dataHorarioSelecionado?: string; // ISO datetime "2026-08-03T14:00:00"
  nomeCliente?: string;
  telefoneCliente?: string;
}

export function useAgendamentoFlow(): {
  state: AgendamentoFlowState;
  selecionarServico(servico: ServicoDTO): void;      // → etapa 'horario'
  selecionarHorario(dataHorario: string): void;      // → etapa 'identificacao'
  identificar(nome: string, telefone: string): void; // guarda dados (POST é da Task 18)
  concluir(): void;                                  // → etapa 'sucesso'
  voltarParaHorario(): void;   // usado no 409: limpa horário, volta a 'horario'
  voltarParaServico(): void;   // limpa horário e serviço, volta a 'servico'
};
```

```typescript
// validacao/clienteSchema.ts — espelha TelefoneBR do backend (Task 10)
export const normalizarTelefone = (t: string) => t.replace(/\D/g, '');

export const clienteSchema = z.object({
  nome: z.string().trim().min(1, 'Nome é obrigatório').max(120, 'Nome muito longo'),
  telefone: z.string().transform(normalizarTelefone).refine(
    (t) => t.length === 10 || t.length === 11,
    'Telefone inválido — use DDD + número',
  ),
});
export type ClienteFormData = z.infer<typeof clienteSchema>;
```

- [ ] **Step 1: Testes falhando.** `useAgendamentoFlow.test.ts` com `renderHook`/`act` do Testing Library: fluxo feliz servico→horario→identificacao→sucesso carregando os dados; `voltarParaHorario` limpa `dataHorarioSelecionado` e mantém serviço; `voltarParaServico` limpa os dois. `clienteSchema.test.ts`: `"(11) 98765-4321"` → válido, output `"11987654321"`; `"11 3456-7890"` → válido (10 dígitos); `"987654321"` → inválido; `"+5511987654321"` → inválido (13 dígitos); nome vazio → mensagem `"Nome é obrigatório"`.

- [ ] **Step 2: Rodar** — `npm test`. Esperado: FAIL.

- [ ] **Step 3: Implementar** — hook com `useState<AgendamentoFlowState>({ etapa: 'servico' })` e callbacks imutáveis (`setState(prev => ...)`); schema como acima.

- [ ] **Step 4: Rodar** — esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(web): state machine do fluxo e validação Zod do cliente"`

---

### Task 17: Componentes EtapaServico e EtapaHorario

**Files:**
- Create: `web/src/components/EtapaServico.tsx`, `web/src/components/EtapaHorario.tsx`, `web/src/components/Estados.tsx` (Loading/Erro compartilhados)
- Test: `web/src/components/EtapaServico.test.tsx`, `web/src/components/EtapaHorario.test.tsx`

**Interfaces:**
- Consumes: `getServicos`, `getDisponibilidade` (Task 15) via TanStack Query.
- Produces:
  - `Estados.tsx`: `export function Carregando()` (spinner/texto "Carregando...") e `export function MensagemErro({ mensagem, onTentarNovamente }: { mensagem: string; onTentarNovamente?: () => void })`.
  - `EtapaServico({ slug, onSelecionar }: { slug: string; onSelecionar: (s: ServicoDTO) => void })` — `useQuery(['servicos', slug], () => getServicos(slug))`; lista de cards nome + preço formatado (`Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' })`) + duração; clique chama `onSelecionar`.
  - `EtapaHorario({ slug, servico, onSelecionar, onVoltar }: { slug: string; servico: ServicoDTO; onSelecionar: (dataHoraISO: string) => void; onVoltar: () => void })` — seletor de data (input `type="date"`, default hoje, `min` hoje, `max` hoje+30d); `useQuery(['disponibilidade', slug, data], ...)`; grid de botões "HH:mm"; clique monta `"${data}T${horario}:00"` e chama `onSelecionar`; dia sem slots → "Nenhum horário disponível neste dia".

- [ ] **Step 1: Testes falhando** (Testing Library; `QueryClientProvider` com `retry: false` num helper `renderComQuery`; mock do módulo `agendamentoPublicoApi` com `vi.mock`):
  - `EtapaServico`: renderiza 2 serviços mockados com preço `R$ 50,00`; clique dispara `onSelecionar` com o DTO; API rejeitando → `MensagemErro` visível.
  - `EtapaHorario`: renderiza botões dos horários mockados (`["09:00","10:00"]`); clique em `10:00` chama `onSelecionar("2026-08-03T10:00:00")` (data controlada no teste); lista vazia → mensagem de vazio; troca de data refaz a query (assert de chamada com a nova data).

- [ ] **Step 2: Rodar** — esperado: FAIL.

- [ ] **Step 3: Implementar** os componentes (função + `useQuery`; sem estado global; CSS simples em `App.css` — mobile-first, é link de bio do Instagram).

- [ ] **Step 4: Rodar** — esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(web): etapas de serviço e horário"`

---

### Task 18: EtapaIdentificacao + TelaSucesso + App integrado (409 volta para horário)

**Files:**
- Create: `web/src/components/EtapaIdentificacao.tsx`, `web/src/components/TelaSucesso.tsx`
- Modify: `web/src/App.tsx`, `web/src/main.tsx` (QueryClientProvider)
- Test: `web/src/components/EtapaIdentificacao.test.tsx`, `web/src/App.test.tsx`

**Interfaces:**
- Consumes: tudo das Tasks 15–17.
- Produces:
  - `EtapaIdentificacao({ onConfirmar, onVoltar, erroEnvio, enviando }: { onConfirmar: (dados: ClienteFormData) => void; onVoltar: () => void; erroEnvio?: string; enviando: boolean })` — form nome+telefone; submit valida com `clienteSchema.safeParse`; erros de campo inline; `erroEnvio` (mensagem da API) exibido acima do botão; botão desabilitado enquanto `enviando`.
  - `TelaSucesso({ agendamento }: { agendamento: AgendamentoCriadoDTO })` — resumo: serviço, data/hora formatada pt-BR, nome.
  - `App.tsx`: slug de `window.location.pathname.replaceAll('/', '')` (vazio → tela "Barbearia não encontrada"); `useQuery` do barbeiro (404 → mesma tela); cabeçalho com nome do barbeiro; switch da `state.etapa` renderizando as 4 etapas; `useMutation(criarAgendamento)`:
    - sucesso → `concluir()` + guarda `AgendamentoCriadoDTO`.
    - `ApiError` 409 → `voltarParaHorario()` + `queryClient.invalidateQueries(['disponibilidade'])` + banner "Esse horário acabou de ser reservado. Escolha outro." na etapa horário.
    - `ApiError` 429 → permanece na identificação com `erroEnvio` = mensagem da API.
    - Outros erros → `erroEnvio` genérico.

- [ ] **Step 1: Testes falhando:**
  - `EtapaIdentificacao.test.tsx`: telefone inválido → mensagem Zod, `onConfirmar` não chamado; válido com máscara → `onConfirmar` recebe telefone normalizado; `enviando` desabilita botão.
  - `App.test.tsx` (fluxo integrado, API inteira mockada): caminho feliz até `TelaSucesso`; POST rejeitando com `ApiError(409, ...)` → volta à etapa horário, banner visível e `getDisponibilidade` rechamado; barbeiro 404 → tela não encontrada.

- [ ] **Step 2: Rodar** — esperado: FAIL.

- [ ] **Step 3: Implementar** (mutation no `App`, propagando `enviando`/`erroEnvio`; `main.tsx` com `QueryClientProvider`).

- [ ] **Step 4: Rodar** — `npm test` completo. Esperado: PASS.

- [ ] **Step 5: Verificação manual contra backend local** (definição de pronto da Fase 2): subir banco+backend (profile dev, seed), cadastrar horário/serviço via API com token, `npm run dev`, abrir `http://localhost:5173/barbeiro-dev`, completar fluxo real das 3 etapas + sucesso; conferir 409 real (criar conflito via curl antes de confirmar) voltando para horário com slots atualizados. Registrar resultado.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat(web): fluxo completo de agendamento com tratamento de 409/429"`

- [ ] **Step 7: Checkpoint de fase**: revisão do usuário + resumo na memória (claude-mem).

---

# FASE 3 — Mobile Flutter (MVVM com provider/ChangeNotifier)

Pré-condição: Fase 2 revisada e verde. NÃO usar Riverpod nem BLoC. Testes de unidade dos ViewModels com repository mockado (`mockito` + `build_runner`). Estrutura da seção 7 do MVP doc.

### Task 19: Scaffold Flutter + core (Dio/JWT/storage) + models

**Files:**
- Create: `mobile/` (via `flutter create`), `mobile/lib/core/storage/token_storage.dart`, `mobile/lib/core/network/api_client.dart`, `mobile/lib/core/errors/api_exception.dart`, `mobile/lib/data/models/agendamento.dart`, `models/servico.dart`, `models/horario_funcionamento.dart`, `models/excecao_horario.dart`, `models/caixa.dart`, `models/enums.dart`
- Test: `mobile/test/core/api_client_test.dart`, `mobile/test/data/models_test.dart`

**Interfaces:**
- Produces:
  - `TokenStorage`: `Future<void> salvar(String token)`, `Future<String?> ler()`, `Future<void> limpar()` — wrapper de `FlutterSecureStorage` (chave `jwt_token`), injetável/mockável.
  - `ApiException implements Exception { final int? statusCode; final String mensagem; }` — mensagem extraída do body `{"erro": ...}` quando houver; senão genérica "Erro de conexão. Tente novamente.".
  - `criarDio(TokenStorage storage, {required String baseUrl, void Function()? onSessaoExpirada})` → `Dio` com `InterceptorsWrapper`:
    - `onRequest`: anexa `Authorization: Bearer <token>` se houver token e o path não for `/login`.
    - `onError`: 401 em rota `/app` (exceto login) → `storage.limpar()` + `onSessaoExpirada?.call()`; sempre converte `DioException` → `ApiException`.
  - `enums.dart`: `enum StatusAgendamento { agendado, concluido, cancelado, naoCompareceu }` e `enum FormaPagamento { pix, dinheiro, debito, credito }` com `fromApi(String)`/`toApi()` mapeando `AGENDADO`/`NAO_COMPARECEU`/etc.
  - Models com `fromJson`/`toJson` espelhando os DTOs do backend: `Agendamento(id, dataHoraInicio: DateTime, dataHoraFim, status, formaPagamento?, servicoNome, servicoPreco: double, clienteNome, clienteTelefone)` (espelha `AgendamentoDTO` Task 11); `Servico(id, nome, preco, duracaoMinutos)`; `HorarioFuncionamento(id, diaSemana, horaInicio: String "HH:mm", horaFim, ativo)`; `ExcecaoHorario(id, data: DateTime, disponivel, horaInicio?, horaFim?)`; `Caixa(total: double, quantidade: int, porFormaPagamento: Map<FormaPagamento, double>)`.

- [ ] **Step 1: Scaffold**

```bash
cd /home/artur/Projetos/Barbearia
flutter create mobile --org com.seusistema --project-name barbearia_app --platforms android,ios
cd mobile
flutter pub add dio provider flutter_secure_storage
flutter pub add -d mockito build_runner
```

- [ ] **Step 2: Testes falhando.** `models_test.dart`: `Agendamento.fromJson` com JSON real do backend (status `"NAO_COMPARECEU"` → enum, preço `50.00`, datas ISO); `Caixa.fromJson` com mapa de formas. `api_client_test.dart`: com `dio.httpClientAdapter` fake (ou pacote `http_mock_adapter` — adicionar como dev dependency se preferir): request a `/api/v1/app/x` com token salvo ganha header `Authorization`; 401 chama `onSessaoExpirada` e limpa storage (TokenStorage fake em memória); erro vira `ApiException` com mensagem do body `{"erro": ...}`.

- [ ] **Step 3: Rodar** — `flutter test`. Esperado: FAIL.

- [ ] **Step 4: Implementar** core e models conforme **Interfaces** (models com construtores const e `fromJson` manuais — sem codegen de JSON; codegen só do mockito).

- [ ] **Step 5: Rodar** — `flutter test`. Esperado: PASS.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat(mobile): scaffold Flutter, core de rede/storage e models"`

---

### Task 20: Repositories

**Files:**
- Create: `mobile/lib/data/repositories/auth_repository.dart`, `agendamento_repository.dart`, `servico_repository.dart`, `horario_repository.dart`, `caixa_repository.dart`
- Test: `mobile/test/data/repositories_test.dart`

**Interfaces:**
- Consumes: `Dio` configurado, models, `TokenStorage` (Task 19).
- Produces (assinaturas exatas — ViewModels das Tasks 21–26 dependem delas):

```dart
class AuthRepository {
  AuthRepository(this._dio, this._storage);
  Future<void> login(String email, String senha);   // POST /api/v1/app/login; salva token no storage
  Future<void> logout();                            // limpa storage
  Future<bool> temSessao();                         // storage tem token?
}

class AgendamentoRepository {
  AgendamentoRepository(this._dio);
  Future<List<Agendamento>> buscarAgendaDoDia(DateTime dia); // GET /api/v1/app/agendamentos?data=yyyy-MM-dd
  Future<void> finalizar(int id, FormaPagamento forma);      // POST .../{id}/finalizar
  Future<void> cancelar(int id, StatusAgendamento status);   // POST .../{id}/cancelar (CANCELADO|NAO_COMPARECEU)
}

class ServicoRepository {
  ServicoRepository(this._dio);
  Future<List<Servico>> listar();
  Future<Servico> criar(String nome, double preco, int duracaoMinutos);
  Future<Servico> atualizar(int id, String nome, double preco, int duracaoMinutos);
  Future<void> excluir(int id);
}

class HorarioRepository {
  HorarioRepository(this._dio);
  Future<List<HorarioFuncionamento>> listarHorarios();
  Future<HorarioFuncionamento> criarHorario(int diaSemana, String horaInicio, String horaFim);
  Future<HorarioFuncionamento> atualizarHorario(HorarioFuncionamento horario);
  Future<void> excluirHorario(int id);
  Future<List<ExcecaoHorario>> listarExcecoes();
  Future<ExcecaoHorario> criarExcecao(DateTime data, bool disponivel, String? horaInicio, String? horaFim);
  Future<void> excluirExcecao(int id);
}

class CaixaRepository {
  CaixaRepository(this._dio);
  Future<Caixa> consultarDia(DateTime dia);     // ?periodo=dia&data=yyyy-MM-dd
  Future<Caixa> consultarMes(DateTime mesAno);  // ?periodo=mes&data=yyyy-MM
}
```

- [ ] **Step 1: Teste falhando** — `repositories_test.dart` com Dio mockado (mesma técnica da Task 19): `buscarAgendaDoDia` formata `data=2026-08-03` e parseia lista; `finalizar` envia `{"formaPagamento": "PIX"}`; `cancelar` envia `{"status": "NAO_COMPARECEU"}`; `consultarMes` formata `data=2026-08`; `login` salva token retornado no storage; `logout` limpa.

- [ ] **Step 2: Rodar** — esperado: FAIL.

- [ ] **Step 3: Implementar** os 5 repositories (formatação de data com `DateFormat`? Não — usar `toIso8601String().substring(0, 10)` e `padLeft`; sem dependência `intl` aqui; `intl` entra nas telas se precisar).

- [ ] **Step 4: Rodar** — esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(mobile): repositories de auth, agendamento, serviço, horário e caixa"`

---

### Task 21: Login (ViewModel + tela) + DI no main.dart + shell de navegação

**Files:**
- Create: `mobile/lib/features/auth/login_view_model.dart`, `features/auth/tela_login.dart`, `mobile/lib/app.dart` (MaterialApp + decisão login/home + logout), `mobile/lib/home.dart` (BottomNavigationBar: Agenda, Caixa, Serviços, Config)
- Modify: `mobile/lib/main.dart`
- Test: `mobile/test/features/auth/login_view_model_test.dart`

**Interfaces:**
- Consumes: `AuthRepository` (Task 20).
- Produces:

```dart
enum LoginStatus { inicial, carregando, sucesso, erro }

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._repository);
  LoginStatus status = LoginStatus.inicial;
  String? mensagemErro;
  Future<void> entrar(String email, String senha);
  // carregando → notify; sucesso → notify; ApiException → mensagemErro = e.mensagem, erro → notify
}
```

  - `main.dart`: `MultiProvider` global — `Provider<TokenStorage>`, `Provider<Dio>` (via `criarDio`, `baseUrl` de `String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080')` — emulador Android; `onSessaoExpirada` navega para login via `GlobalKey<NavigatorState>`), e os 5 repositories via `context.read<Dio>()` (padrão do MVP doc seção 7).
  - `app.dart`: `FutureBuilder` de `authRepository.temSessao()` decide tela inicial; ação de logout (ícone na AppBar do `home.dart`) chama `authRepository.logout()` e volta ao login.
  - Cada aba do `home.dart` instancia seu `ChangeNotifierProvider` de ViewModel (padrão da seção 7 do MVP doc).

- [ ] **Step 1: Teste falhando** — `login_view_model_test.dart` (mockito; gerar mocks com `dart run build_runner build`):
  - `entrar` ok → estados `carregando` depois `sucesso`; `notifyListeners` ≥ 2 (contar via listener).
  - repository lança `ApiException(mensagem: 'E-mail ou senha inválidos')` → status `erro`, `mensagemErro` exposta.

- [ ] **Step 2: Rodar** — esperado: FAIL.

- [ ] **Step 3: Implementar** ViewModel + `tela_login.dart` (form email/senha, `Consumer<LoginViewModel>`, botão desabilitado em `carregando`, erro em `SnackBar`/texto) + DI + shell.

- [ ] **Step 4: Rodar** — `flutter test`. Esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(mobile): login com JWT, injeção de dependências e navegação"`

---

### Task 22: Agenda do dia (ViewModel com teste + tela timeline)

**Files:**
- Create: `mobile/lib/features/agenda/agenda_view_model.dart`, `features/agenda/tela_agenda_do_dia.dart`, `features/agenda/agendamento_tile.dart`
- Test: `mobile/test/features/agenda/agenda_view_model_test.dart`

**Interfaces:**
- Consumes: `AgendamentoRepository` (Task 20).
- Produces:

```dart
enum AgendaStatus { carregando, sucesso, erro }

class AgendaViewModel extends ChangeNotifier {
  AgendaViewModel(this._repository) { carregar(); }
  AgendaStatus status = AgendaStatus.carregando;
  DateTime diaSelecionado = DateTime.now();
  List<Agendamento> agendamentos = [];
  String? mensagemErro;

  Future<void> carregar();                    // busca diaSelecionado; padrão do MVP doc seção 7
  Future<void> mudarDia(DateTime novoDia);    // troca dia + carregar()
  Future<void> cancelar(int id, StatusAgendamento status); // repository.cancelar + carregar()
}
```

  - `tela_agenda_do_dia.dart`: `Consumer<AgendaViewModel>` com switch de status (padrão MVP doc); seletor de dia (setas ±1 dia + `showDatePicker`); `ListView` de `AgendamentoTile`.
  - `agendamento_tile.dart`: hora, cliente, serviço, preço, badge de status; agendamento `AGENDADO` mostra botões "Finalizar e Receber" (navega ao checkout, Task 23) e "Cancelar" → dialog com opções "Cancelar agendamento" (CANCELADO) / "Cliente não veio" (NAO_COMPARECEU) + telefone do cliente visível para contato manual (tela 7 da seção 7 do MVP doc).

- [ ] **Step 1: Teste falhando** — `agenda_view_model_test.dart` (repository mockado):
  - carregar ok → `sucesso` + lista preenchida; erro (`ApiException`) → `erro` + `mensagemErro`.
  - `mudarDia` chama repository com o novo dia.
  - `cancelar` chama repository com `StatusAgendamento.naoCompareceu` e recarrega (verify 2× `buscarAgendaDoDia`).
  - Toda transição notifica (listener count).

- [ ] **Step 2: Rodar** — esperado: FAIL.

- [ ] **Step 3: Implementar** ViewModel + telas (sem lógica de negócio na View).

- [ ] **Step 4: Rodar** — esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(mobile): agenda do dia com cancelamento e no-show"`

---

### Task 23: Checkout — "Finalizar e Receber" (ViewModel com teste + tela)

**Files:**
- Create: `mobile/lib/features/checkout/checkout_view_model.dart`, `features/checkout/tela_checkout.dart`
- Test: `mobile/test/features/checkout/checkout_view_model_test.dart`

**Interfaces:**
- Consumes: `AgendamentoRepository.finalizar` (Task 20).
- Produces:

```dart
enum CheckoutStatus { inicial, enviando, sucesso, erro }

class CheckoutViewModel extends ChangeNotifier {
  CheckoutViewModel(this._repository, this.agendamento);
  final Agendamento agendamento;
  CheckoutStatus status = CheckoutStatus.inicial;
  FormaPagamento? formaSelecionada;
  String? mensagemErro;

  void selecionarForma(FormaPagamento forma);  // + notifyListeners
  Future<void> confirmar();                    // exige forma selecionada; enviando → sucesso|erro
}
```

  - `tela_checkout.dart`: resumo do agendamento (cliente, serviço, preço); 4 botões de forma de pagamento (Pix/Dinheiro/Débito/Crédito, seleção destacada); "Confirmar" desabilitado sem forma ou em `enviando`; sucesso → pop com resultado para a agenda recarregar (fluxo da seção 8 do MVP doc).

- [ ] **Step 1: Teste falhando:**
  - `confirmar` sem forma → status inalterado, repository não chamado.
  - `selecionarForma(pix)` + `confirmar` ok → `enviando` depois `sucesso`; repository recebeu `(agendamento.id, FormaPagamento.pix)`.
  - repository lança → `erro` + mensagem.

- [ ] **Step 2: Rodar** — esperado: FAIL.

- [ ] **Step 3: Implementar** ViewModel + tela; na agenda, retorno do checkout com sucesso → `agendaViewModel.carregar()`.

- [ ] **Step 4: Rodar** — esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(mobile): checkout com forma de pagamento"`

---

### Task 24: Caixa (ViewModel com teste + tela)

**Files:**
- Create: `mobile/lib/features/caixa/caixa_view_model.dart`, `features/caixa/tela_caixa.dart`
- Test: `mobile/test/features/caixa/caixa_view_model_test.dart`

**Interfaces:**
- Consumes: `CaixaRepository` (Task 20).
- Produces:

```dart
enum CaixaStatus { carregando, sucesso, erro }
enum PeriodoCaixa { dia, mes }

class CaixaViewModel extends ChangeNotifier {
  CaixaViewModel(this._repository) { carregar(); }
  CaixaStatus status = CaixaStatus.carregando;
  PeriodoCaixa periodo = PeriodoCaixa.dia;
  DateTime referencia = DateTime.now();
  Caixa? caixa;
  String? mensagemErro;

  Future<void> carregar();                     // dia → consultarDia; mes → consultarMes
  Future<void> mudarPeriodo(PeriodoCaixa p);   // troca + carregar()
  Future<void> mudarReferencia(DateTime ref);  // troca data/mês + carregar()
}
```

  - `tela_caixa.dart`: toggle Dia/Mês (`SegmentedButton`); seletor de referência; total em destaque, quantidade de atendimentos, lista das 4 formas com valores (pt-BR via `intl` — adicionar `flutter pub add intl`).

- [ ] **Step 1: Teste falhando:**
  - Inicial → `consultarDia` chamado, `sucesso` com dados.
  - `mudarPeriodo(mes)` → `consultarMes` chamado com a referência.
  - Erro → `erro` + mensagem.
  - Notificações em toda transição.

- [ ] **Step 2: Rodar** — esperado: FAIL.

- [ ] **Step 3: Implementar** ViewModel + tela.

- [ ] **Step 4: Rodar** — esperado: PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(mobile): caixa dia/mês por forma de pagamento"`

---

### Task 25: CRUD de serviços (ViewModel + telas)

**Files:**
- Create: `mobile/lib/features/servicos/servicos_view_model.dart`, `features/servicos/tela_servicos.dart`, `features/servicos/tela_servico_form.dart`
- Test: `mobile/test/features/servicos/servicos_view_model_test.dart`

**Interfaces:**
- Consumes: `ServicoRepository` (Task 20).
- Produces:

```dart
enum ServicosStatus { carregando, sucesso, erro }

class ServicosViewModel extends ChangeNotifier {
  ServicosViewModel(this._repository) { carregar(); }
  ServicosStatus status = ServicosStatus.carregando;
  List<Servico> servicos = [];
  String? mensagemErro;

  Future<void> carregar();
  Future<bool> salvar({int? id, required String nome, required double preco, required int duracaoMinutos});
  // id null → criar; senão atualizar; sucesso → carregar(), retorna true; ApiException → mensagemErro, false
  Future<bool> excluir(int id); // erro 400 do backend (serviço com agendamentos) → mensagemErro, false
}
```

  - `tela_servicos.dart`: lista nome/preço/duração + FAB para novo + tap para editar + swipe/menu para excluir (falha → SnackBar com `mensagemErro`).
  - `tela_servico_form.dart`: form nome (obrigatório), preço (`TextInputType.number`, > 0), duração (default 60, com hint "informativo — slot é sempre 1h"); validação local no `Form`; salva via ViewModel e faz pop em sucesso.

- [ ] **Step 1: Teste falhando** — carregar/salvar(criar e atualizar)/excluir com mock; excluir falhando com `ApiException` → retorna false e expõe mensagem.

- [ ] **Step 2: Rodar** — esperado: FAIL. **Step 3: Implementar.** **Step 4: Rodar** — PASS.

- [ ] **Step 5: Commit** — `git commit -am "feat(mobile): cadastro e edição de serviços"`

---

### Task 26: Configuração de horário + exceções (ViewModel + telas) e verificação final

**Files:**
- Create: `mobile/lib/features/configuracao/configuracao_view_model.dart`, `features/configuracao/tela_configuracao.dart`, `features/configuracao/tela_horario_form.dart`, `features/configuracao/tela_excecao_form.dart`
- Test: `mobile/test/features/configuracao/configuracao_view_model_test.dart`

**Interfaces:**
- Consumes: `HorarioRepository` (Task 20).
- Produces:

```dart
enum ConfiguracaoStatus { carregando, sucesso, erro }

class ConfiguracaoViewModel extends ChangeNotifier {
  ConfiguracaoViewModel(this._repository) { carregar(); }
  ConfiguracaoStatus status = ConfiguracaoStatus.carregando;
  List<HorarioFuncionamento> horarios = [];
  List<ExcecaoHorario> excecoes = [];
  String? mensagemErro;

  Future<void> carregar(); // Future.wait dos dois listares
  Future<bool> salvarHorario({int? id, required int diaSemana, required String horaInicio, required String horaFim, bool ativo = true});
  Future<bool> excluirHorario(int id);
  Future<bool> salvarExcecao({required DateTime data, required bool disponivel, String? horaInicio, String? horaFim});
  Future<bool> excluirExcecao(int id);
  // todos: sucesso → carregar() + true; ApiException → mensagemErro + false
}
```

  - `tela_configuracao.dart`: duas seções — grade semanal (dom…sáb com janelas ou "Fechado") e lista de exceções futuras ("Folga" ou horário especial); FABs para adicionar; `tela_horario_form.dart` (dropdown dia da semana + `showTimePicker` início/fim); `tela_excecao_form.dart` (date picker + switch "Vou trabalhar neste dia" revelando horários).

- [ ] **Step 1: Teste falhando** — carregar (2 repositórios), salvarHorario, salvarExcecao folga (horas null) e especial, exclusões; erros expõem mensagem.

- [ ] **Step 2: Rodar** — esperado: FAIL. **Step 3: Implementar.** **Step 4: Rodar** — PASS.

- [ ] **Step 5: Verificação final da Fase 3** (definição de pronto):
  - `flutter test` completo verde (ViewModels de agenda, checkout e caixa cobertos, mais login/serviços/configuração).
  - `flutter analyze` sem erros.
  - Smoke manual no emulador contra backend local (`flutter run --dart-define=API_URL=http://10.0.2.2:8080`): login com seed dev → agenda mostra agendamento criado pela web → checkout PIX → caixa reflete → logout limpa storage (fechar/reabrir exige login). As 7 telas da seção 7 do MVP doc existem: Login, Agenda, Checkout, Caixa, Serviços, Configuração, Cancelamento (dialog na agenda com telefone visível).
  - Atualizar `README.md` com instruções do mobile.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat(mobile): configuração de horários e exceções — fecha Fase 3"`

- [ ] **Step 7: Checkpoint final**: revisão do usuário + resumo na memória (claude-mem): decisões, concluído, desvios.

---

## Notas de execução

- **Ordem estrita**: Task N+1 só começa com a N commitada e verde. Fases 2 e 3 só após checkpoint de revisão da fase anterior.
- **Início de sessão**: consultar memória (claude-mem) e este plano; marcar checkboxes conforme conclusão.
- **Desvios**: qualquer desvio do plano deve ser registrado na memória com justificativa.
- **Testcontainers** exige Docker rodando na máquina.
