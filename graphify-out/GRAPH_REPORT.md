# Graph Report - Barbearia  (2026-08-05)

## Corpus Check
- 118 files · ~34,874 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 907 nodes · 2048 edges · 45 communities (41 shown, 4 thin omitted)
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 358 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `f5f419ef`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Agendamento Domain Model
- Cliente Barbeiro Servico Entities
- ServicoRepository
- Web Lint & Agendamento API Client
- Rate Limit Interceptor
- Frontend Dev Dependencies
- Global Exception Handling
- DisponibilidadeService
- Horário Funcionamento DTOs & Repo
- Plano de Implementação MVP
- Serviço CRUD Controller
- Documentação Design MVP
- Security Config & JWT Filter
- HorarioFuncionamento Entity
- Vite TS App Config
- Horário CRUD Requests & Tests
- ExcecaoHorario Entity
- Vite Node TS Config
- AgendamentoRepositoryTest
- Caixa & Forma Pagamento
- Barbeiro Login Controller
- Autenticação Tests
- Design Doc Fase 1/2
- Barbeiro Público Controller
- BarbeiroService Tests
- BarbeiroService Criação
- Runner Criação Barbeiro Inicial
- Maven Wrapper Script
- CORS Config
- Clock Config
- CaixaTest.java
- Application Entry Point
- Vite React Readme
- TS Project References
- CLAUDE.md Graphify Setup
- Maven Artifact Coordinates
- Agendamento
- MigrationConstraintTest
- BarbeiroService
- StatusAgendamento
- FormaPagamento

## God Nodes (most connected - your core abstractions)
1. `IntegrationTestBase` - 41 edges
2. `Agendamento` - 40 edges
3. `BarbeiroService` - 40 edges
4. `Servico` - 39 edges
5. `Cliente` - 33 edges
6. `CriarBarbeiroRequest` - 30 edges
7. `AgendamentoRepository` - 28 edges
8. `Barbeiro` - 26 edges
9. `DisponibilidadeTest` - 24 edges
10. `ExcecaoHorario` - 23 edges

## Surprising Connections (you probably didn't know these)
- `Agendamento` --references--> `FormaPagamento`  [EXTRACTED]
  backend/src/main/java/com/seusistema/barbearia/agendamento/Agendamento.java → backend/src/main/java/com/seusistema/barbearia/agendamento/FormaPagamento.java
- `Agendamento` --references--> `StatusAgendamento`  [EXTRACTED]
  backend/src/main/java/com/seusistema/barbearia/agendamento/Agendamento.java → backend/src/main/java/com/seusistema/barbearia/agendamento/StatusAgendamento.java
- `Agendamento` --references--> `Cliente`  [EXTRACTED]
  backend/src/main/java/com/seusistema/barbearia/agendamento/Agendamento.java → backend/src/main/java/com/seusistema/barbearia/cliente/Cliente.java
- `Agendamento` --references--> `Servico`  [EXTRACTED]
  backend/src/main/java/com/seusistema/barbearia/agendamento/Agendamento.java → backend/src/main/java/com/seusistema/barbearia/servico/Servico.java
- `AgendamentoRepository` --references--> `Agendamento`  [EXTRACTED]
  backend/src/main/java/com/seusistema/barbearia/agendamento/AgendamentoRepository.java → backend/src/main/java/com/seusistema/barbearia/agendamento/Agendamento.java

## Import Cycles
- None detected.

## Communities (45 total, 4 thin omitted)

### Community 0 - "Agendamento Domain Model"
Cohesion: 0.26
Nodes (5): AgendaAppTest, BeforeEach, HttpHeaders, Import, Test

### Community 1 - "Cliente Barbeiro Servico Entities"
Cohesion: 0.05
Nodes (27): Barbeiro, Entity, Table, CriarBarbeiroRequest, StatusConta, ATIVO, INATIVO, Cliente (+19 more)

### Community 2 - "ServicoRepository"
Cohesion: 0.18
Nodes (3): HorarioFuncionamento, Entity, Table

### Community 3 - "Web Lint & Agendamento API Client"
Cohesion: 0.09
Nodes (35): react, criarAgendamento(), getBarbeiro(), getDisponibilidade(), getServicos(), api(), ApiError, App() (+27 more)

### Community 4 - "Rate Limit Interceptor"
Cohesion: 0.07
Nodes (30): Component, HttpServletRequest, HttpServletResponse, Override, RateLimitInterceptor, Configuration, Override, WebConfig (+22 more)

### Community 5 - "Frontend Dev Dependencies"
Cohesion: 0.04
Nodes (44): jsdom, oxlint, react, react-dom, @tanstack/react-query, @testing-library/jest-dom, @testing-library/react, @testing-library/user-event (+36 more)

### Community 6 - "Global Exception Handling"
Cohesion: 0.12
Nodes (16): GlobalExceptionHandler, ResponseEntity, ControllerDeTeste, GlobalExceptionHandlerRoteamentoTest, GetMapping, RestController, Test, GlobalExceptionHandlerTest (+8 more)

### Community 7 - "DisponibilidadeService"
Cohesion: 0.23
Nodes (5): SalvarExcecaoRequest, SalvarHorarioRequest, HorarioCrudTest, HttpHeaders, Test

### Community 8 - "Horário Funcionamento DTOs & Repo"
Cohesion: 0.13
Nodes (10): ExcecaoHorarioDTO, HorarioFuncionamentoDTO, HorarioController, DeleteMapping, GetMapping, PostMapping, PutMapping, RequestMapping (+2 more)

### Community 9 - "Plano de Implementação MVP"
Cohesion: 0.06
Nodes (32): FASE 1 — Backend, FASE 2 — Web público (React + TypeScript + Vite), FASE 3 — Mobile Flutter (MVVM com provider/ChangeNotifier), Global Constraints, Notas de execução, Plano de Implementação — MVP SaaS Barbearia, Task 10: Agendamento público (POST) — upsert de cliente, validações e conflito concorrente, Task 11: Agenda do dia, checkout e cancelamento (/app) (+24 more)

### Community 10 - "Serviço CRUD Controller"
Cohesion: 0.18
Nodes (8): BarbeiroRepository, ClienteRepository, ClienteService, Service, Transactional, ServicoRepository, EntidadesMapeamentoTest, JpaRepository

### Community 11 - "Documentação Design MVP"
Cohesion: 0.08
Nodes (24): 10. Endpoints Principais (resumo), 11. Resumo das Decisões-Chave, 1. Visão Geral, 2. Stack Tecnológica, 3. Divisão de Responsabilidade, 4. Modelo de Dados (PostgreSQL), 5.1 Estrutura de pacotes (por feature), 5.2 Divisão de rotas (+16 more)

### Community 12 - "Security Config & JWT Filter"
Cohesion: 0.13
Nodes (16): Bean, Configuration, PasswordEncoder, SecurityConfig, Component, HttpServletRequest, HttpServletResponse, Override (+8 more)

### Community 13 - "HorarioFuncionamento Entity"
Cohesion: 0.19
Nodes (8): AgendamentoController, GetMapping, PostMapping, RequestMapping, RestController, AgendamentoService, Transactional, AgendamentoDTO

### Community 14 - "Vite TS App Config"
Cohesion: 0.08
Nodes (23): DOM, src, vite/client, compilerOptions, allowArbitraryExtensions, allowImportingTsExtensions, erasableSyntaxOnly, jsx (+15 more)

### Community 15 - "Horário CRUD Requests & Tests"
Cohesion: 0.18
Nodes (5): RecursoNaoEncontradoException, ExcecaoHorarioRepository, HorarioFuncionamentoRepository, HorarioService, Service

### Community 16 - "ExcecaoHorario Entity"
Cohesion: 0.24
Nodes (6): DisponibilidadeDTO, DisponibilidadeTest, BeforeEach, Import, ResponseEntity, Test

### Community 17 - "Vite Node TS Config"
Cohesion: 0.10
Nodes (19): node, vite.config.ts, compilerOptions, allowImportingTsExtensions, erasableSyntaxOnly, lib, module, moduleDetection (+11 more)

### Community 18 - "AgendamentoRepositoryTest"
Cohesion: 0.23
Nodes (7): AgendamentoPublicoController, DisponibilidadeDTO, GetMapping, RequestMapping, RestController, DisponibilidadeService, Service

### Community 19 - "Caixa & Forma Pagamento"
Cohesion: 0.17
Nodes (9): CaixaController, GetMapping, RequestMapping, RestController, CaixaService, Service, Transactional, CaixaDTO (+1 more)

### Community 20 - "Barbeiro Login Controller"
Cohesion: 0.27
Nodes (4): AgendamentoRepository, Service, ServicoService, Query

### Community 21 - "Autenticação Tests"
Cohesion: 0.16
Nodes (7): PostMapping, ResponseStatus, AgendamentoCriadoDTO, Service, AgendamentoCriadoDTO, CriarAgendamentoRequest, TelefoneBR

### Community 22 - "Design Doc Fase 1/2"
Cohesion: 0.13
Nodes (14): 1. Escopo, 2. Decisões que complementam o MVP doc, 3.1 Estrutura, 3.2 Migrations (Flyway, SQL puro), 3.3 Segurança, 3.4 Regras de negócio centrais, 3.5 Endpoints, 3.6 Testes (Testcontainers, PostgreSQL real) (+6 more)

### Community 23 - "Barbeiro Público Controller"
Cohesion: 0.22
Nodes (3): ExcecaoHorario, Entity, Table

### Community 24 - "BarbeiroService Tests"
Cohesion: 0.42
Nodes (3): AgendamentoRepositoryTest, BeforeEach, Test

### Community 25 - "BarbeiroService Criação"
Cohesion: 0.22
Nodes (8): oxc, typescript, warn, plugins, rules, react/only-export-components, react/rules-of-hooks, $schema

### Community 26 - "Runner Criação Barbeiro Inicial"
Cohesion: 0.06
Nodes (30): ActiveProfiles, SalvarServicoRequest, DeleteMapping, GetMapping, PostMapping, PutMapping, RequestMapping, ResponseStatus (+22 more)

### Community 27 - "Maven Wrapper Script"
Cohesion: 0.33
Nodes (6): mvnw script, clean(), die(), exec_maven(), set_java_home(), verbose()

### Community 28 - "CORS Config"
Cohesion: 0.53
Nodes (4): CorsConfig, Bean, Configuration, CorsConfigurationSource

### Community 29 - "Clock Config"
Cohesion: 0.60
Nodes (3): ClockConfig, Bean, Configuration

### Community 30 - "CaixaTest.java"
Cohesion: 0.36
Nodes (4): CaixaTest, BeforeEach, HttpHeaders, Test

### Community 32 - "Vite React Readme"
Cohesion: 0.50
Nodes (3): Expanding the Oxlint configuration, React Compiler, React + TypeScript + Vite

### Community 41 - "Agendamento"
Cohesion: 0.21
Nodes (4): Agendamento, Entity, Table, PrePersist

### Community 43 - "MigrationConstraintTest"
Cohesion: 0.36
Nodes (3): BeforeEach, Test, MigrationConstraintTest

### Community 44 - "BarbeiroService"
Cohesion: 0.05
Nodes (29): ApplicationArguments, ApplicationRunner, BarbeiroController, PostMapping, RequestMapping, RestController, BarbeiroPublicoController, GetMapping (+21 more)

### Community 49 - "StatusAgendamento"
Cohesion: 0.29
Nodes (6): CancelarRequest, StatusAgendamento, AGENDADO, CANCELADO, CONCLUIDO, NAO_COMPARECEU

### Community 50 - "FormaPagamento"
Cohesion: 0.29
Nodes (6): FinalizarRequest, FormaPagamento, CREDITO, DEBITO, DINHEIRO, PIX

## Knowledge Gaps
- **148 isolated node(s):** `com.seusistema:barbearia`, `PIX`, `DINHEIRO`, `DEBITO`, `CREDITO` (+143 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `BarbeiroService` connect `BarbeiroService` to `Cliente Barbeiro Servico Entities`, `Rate Limit Interceptor`, `DisponibilidadeService`, `Serviço CRUD Controller`, `Security Config & JWT Filter`, `HorarioFuncionamento Entity`, `AgendamentoRepositoryTest`, `Autenticação Tests`, `Runner Criação Barbeiro Inicial`, `CaixaTest.java`?**
  _High betweenness centrality (0.093) - this node is a cross-community bridge._
- **Why does `IntegrationTestBase` connect `Runner Criação Barbeiro Inicial` to `Agendamento Domain Model`, `Cliente Barbeiro Servico Entities`, `Rate Limit Interceptor`, `DisponibilidadeService`, `Serviço CRUD Controller`, `MigrationConstraintTest`, `BarbeiroService`, `Horário CRUD Requests & Tests`, `ExcecaoHorario Entity`, `BarbeiroService Tests`, `CaixaTest.java`?**
  _High betweenness centrality (0.093) - this node is a cross-community bridge._
- **Why does `RegraDeNegocioException` connect `Caixa & Forma Pagamento` to `ServicoRepository`, `Global Exception Handling`, `HorarioFuncionamento Entity`, `Horário CRUD Requests & Tests`, `AgendamentoRepositoryTest`, `Barbeiro Login Controller`, `Autenticação Tests`, `Barbeiro Público Controller`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `Agendamento` (e.g. with `.slotJaOcupadoRetorna400()` and `.criarAgendamento()`) actually correct?**
  _`Agendamento` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `Servico` (e.g. with `.criar()` and `.servicoDeOutroBarbeiroRetorna404()`) actually correct?**
  _`Servico` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `Cliente` (e.g. with `.slotJaOcupadoRetorna400()` and `.persisteGrafoCompletoECalculaFimNoPrePersist()`) actually correct?**
  _`Cliente` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `com.seusistema:barbearia`, `PIX`, `DINHEIRO` to the rest of the system?**
  _148 weakly-connected nodes found - possible documentation gaps or missing edges._