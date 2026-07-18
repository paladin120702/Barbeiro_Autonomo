# Design — MVP SaaS de Agendamento para Barbeiro Individual

**Data:** 2026-07-18
**Fonte de verdade:** `MVP-SaaS-Barbearia.md` (raiz do repositório). Este documento registra as decisões que complementam o MVP doc e o design consolidado aprovado. Em conflito, o MVP doc prevalece, exceto onde uma decisão abaixo resolve explicitamente uma ambiguidade dele.

---

## 1. Escopo

Três entregas, em ordem estrita:

1. **Fase 1 — Backend** (Java 21, Spring Boot 3, PostgreSQL, Flyway, MVC em camadas, pacotes por feature)
2. **Fase 2 — Web público** (React + TypeScript + Vite, página única, sem login, sem router)
3. **Fase 3 — Mobile** (Flutter, MVVM com `provider`/`ChangeNotifier`)

Fora do escopo (não implementar, não sugerir, não deixar "preparado"): WhatsApp/mensageria, fidelidade/pontos, cobrança de assinatura, multi-barbeiro, comissões, push, DDD/Clean/hexagonal/CQRS/microsserviços.

## 2. Decisões que complementam o MVP doc

| Tema | Decisão |
|---|---|
| Rate limit | Bucket4j, 3 req/10 min por IP, **somente** em `GET /api/v1/public/{slug}/disponibilidade` e `POST /api/v1/public/{slug}/agendamentos`. Demais rotas públicas sem limite. Resolve a contradição entre a seção 5.2 e a tabela da seção 10 do MVP doc (vale a tabela). 429 na 4ª requisição dentro da janela. |
| Timezone | `America/Sao_Paulo` fixo. `LocalDateTime` puro no backend, colunas `TIMESTAMP` sem TZ. JVM roda com `-Duser.timezone=America/Sao_Paulo`. Sem conversão de fuso em nenhuma camada. |
| Formato de erro | Corpo padrão `{"erro": "mensagem"}` para 401, 404, 409, 429 e 400 genérico. Erros de validação (400) adicionam mapa de campos: `{"erro": "Dados inválidos", "campos": {"telefone": "Telefone inválido"}}`. |
| Criação de barbeiro | Sem endpoint de registro. CLI admin: `ApplicationRunner` ativado por argumento (`--criar-barbeiro`), camada fina que delega a `BarbeiroService.criar()`. Toda a lógica (validação, geração de slug, BCrypt, `status_conta` default ATIVO) vive no service, desacoplada do CLI, para reuso futuro por um endpoint de registro self-service — que **não** será implementado agora. |
| Telefone BR | Normalização: remover todo caractere não-dígito. Validação: 10 ou 11 dígitos após normalizar (DDD + fixo/celular). Rejeitar fora disso (inclusive 13 dígitos com código de país). Armazenar apenas dígitos. Upsert de cliente (`barbeiro_id + telefone`) usa a forma normalizada. Mesma regra espelhada no Zod (web). |
| JWT | Expiração 7 dias. Sem refresh token. Secret via variável de ambiente (`JWT_SECRET`). Claim principal: id do barbeiro (subject). |
| Janela de agendamento | Início do slot deve ser `> agora` e no máximo 30 dias à frente. Disponibilidade do dia atual omite horas já passadas. Validação no service (400/422 → usar 400 com `{"erro": ...}`). |
| Conta INATIVO | Todas as rotas `/api/v1/public/{slug}/**` retornam 404 quando `status_conta = INATIVO` (vitrine some, POST bloqueado). Login e rotas `/app` continuam funcionando normalmente. |
| Caixa | `GET /api/v1/app/caixa?periodo=dia\|mes&data=` — `data=2026-07-18` para dia, `data=2026-07` para mês. Resposta: `{"total": 250.00, "quantidade": 5, "porFormaPagamento": {"PIX": ..., "DINHEIRO": ..., "DEBITO": ..., "CREDITO": ...}}`. Somente agendamentos `CONCLUIDO` contam. Formas sem lançamento aparecem com 0. |
| Exceções de horário | Ambos os casos do schema: `disponivel=false` → dia fechado; `disponivel=true` com `hora_inicio`/`hora_fim` → horário especial que sobrepõe a regra semanal naquele dia. |
| Estrutura do repo | Monorepo: `backend/`, `web/`, `mobile/`, `docs/`, `docker-compose.yml` e `README.md` na raiz. |
| Package Java | `com.seusistema.barbearia`. |

## 3. Backend (Fase 1)

### 3.1 Estrutura

Pacotes por feature, exatamente como a seção 5.1 do MVP doc: `config`, `security`, `barbeiro`, `servico`, `cliente`, `agendamento`, `horario`, `caixa`, `common`. Controller → Service → Repository. DTOs em `dto/` por feature; entidade JPA nunca sai do controller.

### 3.2 Migrations (Flyway, SQL puro)

- `V1__schema.sql`: `CREATE EXTENSION btree_gist`, 6 tabelas (`barbeiros`, `servicos`, `clientes`, `horario_funcionamento`, `excecoes_horario`, `agendamentos`), exclusion constraint `sem_sobreposicao` (`EXCLUDE USING gist (barbeiro_id WITH =, tsrange(data_hora_inicio, data_hora_fim) WITH &&) WHERE (status NOT IN ('CANCELADO','NAO_COMPARECEU'))`). Nunca via anotação Hibernate; `ddl-auto=validate`.
- Seed de desenvolvimento: barbeiro de exemplo apenas em profile dev/test, via location extra do Flyway (`db/dev`) ativada por profile — fora do caminho de migração de produção.

### 3.3 Segurança

- Spring Security + filtro JWT. `/api/v1/app/**` exige token (401 sem/expirado). `/api/v1/public/**` e `POST /api/v1/app/login` liberados.
- Senha com BCrypt.
- `RateLimitInterceptor` (Bucket4j, bucket por IP em `ConcurrentHashMap`) registrado apenas nos dois endpoints públicos definidos na seção 2.

### 3.4 Regras de negócio centrais

- **Disponibilidade** (`DisponibilidadeService`): horário semanal do dia → exceção da data sobrepõe (fechado ⇒ lista vazia; horário especial ⇒ usa a janela da exceção) → gera slots de 1h cheia dentro da janela → remove slots com agendamento `AGENDADO`/`CONCLUIDO` → remove slots passados (hoje) → retorna livres.
- **Agendamento público**: valida serviço pertence ao barbeiro do slug, valida janela temporal, valida slot dentro da disponibilidade, upsert do cliente por `(barbeiro_id, telefone normalizado)`, insere com `data_hora_fim = inicio + 1h` (`@PrePersist`). Violação da constraint → `DataIntegrityViolationException` → `GlobalExceptionHandler` verifica `sem_sobreposicao` na mensagem → 409 `{"erro": "Esse horário acabou de ser reservado. Escolha outro."}`.
- **Checkout**: `POST /app/agendamentos/{id}/finalizar` → status `CONCLUIDO` + `forma_pagamento`. Só a partir de `AGENDADO`.
- **Cancelamento**: `POST /app/agendamentos/{id}/cancelar` com corpo indicando `CANCELADO` ou `NAO_COMPARECEU`. Só a partir de `AGENDADO`. Libera o slot (constraint ignora esses status).
- **Caixa** (`CaixaService`): agrega `CONCLUIDO` por dia ou mês, quebrado por forma de pagamento.

### 3.5 Endpoints

Exatamente a tabela da seção 10 do MVP doc, com o CRUD de `/app/servicos` e `/app/horarios` (horário semanal + exceções) expandido em REST convencional.

### 3.6 Testes (Testcontainers, PostgreSQL real)

Cobertura mínima obrigatória:
1. Disponibilidade: horário semanal + exceção de folga + exceção de horário especial + slots ocupados + horas passadas do dia atual.
2. Conflito concorrente: duas requisições simultâneas para o mesmo slot — uma cria, outra recebe 409 (exercita a exclusion constraint de verdade).
3. Checkout: status + forma de pagamento + reflexo no caixa.
4. Rate limit: 4ª requisição em 10 min recebe 429.
5. JWT: rota `/app` sem token recebe 401.
6. Upsert de cliente: mesmo telefone com máscara diferente não duplica.

### 3.7 Infra local

`docker-compose.yml` com PostgreSQL para desenvolvimento; `README.md` com instruções de execução (subir banco, rodar backend, criar barbeiro via CLI, rodar testes).

## 4. Web público (Fase 2)

- Vite + React + TS. Estrutura da seção 6 do MVP doc (`api/`, `types/`, `components/`, `hooks/`, `App.tsx`).
- Slug extraído de `window.location.pathname`.
- State machine em `useAgendamentoFlow`: `servico → horario → identificacao → sucesso`.
- TanStack Query para barbeiro, serviços, disponibilidade e mutation de agendamento; estados de loading/erro em todas.
- Zod valida nome (obrigatório, até 120 chars) e telefone (mesma regra do backend: normaliza, 10–11 dígitos).
- 409 no POST → volta à etapa `horario` com refetch da disponibilidade e mensagem amigável. 429 → mensagem para aguardar. Slug 404 → tela "barbeiro não encontrado".

## 5. Mobile Flutter (Fase 3)

- MVVM com `provider`/`ChangeNotifier`. Sem Riverpod, sem BLoC. Estrutura da seção 7 do MVP doc (`core/`, `data/`, `features/`).
- Dio com interceptor: anexa `Authorization: Bearer` do `flutter_secure_storage`; resposta 401 → limpa storage e redireciona ao login.
- Logout limpa o secure storage.
- 7 telas: Login, Agenda do dia, Checkout (forma de pagamento), Caixa (dia/mês), CRUD de serviços, Configuração de horário + exceções, Cancelamento (com telefone do cliente visível).
- ViewModels: `notifyListeners()` ao final de toda mutação de estado; `dispose()` onde houver recursos.
- Testes de unidade dos ViewModels de agenda, checkout e caixa com repositories mockados.

## 6. Definição de pronto

A do prompt do projeto, por fase (migrations do zero, endpoints da seção 10, suíte de testes da seção 3.6, docker-compose + README; fluxo web completo com tratamento de 409; 7 telas Flutter com testes de ViewModel).
