# Barbearia — SaaS de Agendamento

SaaS de agendamento para barbeiro individual: backend Spring Boot com vitrine pública, agenda, caixa e proteção contra agendamento duplicado; web React (vitrine pública, sem login); app Flutter de gestão (agenda, checkout, caixa, serviços e configuração de horários). Detalhes completos da arquitetura e das decisões de design em [`MVP-SaaS-Barbearia.md`](MVP-SaaS-Barbearia.md).

Este é o **único README do repositório** — os três módulos estão documentados aqui, cada um na sua seção. Não há README por módulo, de propósito: um só arquivo não diverge do outro.

## Estrutura

| Pasta | O que é | Stack |
|---|---|---|
| `backend/` | API REST, regras de negócio, autenticação | Spring Boot, Java 21, Postgres, Flyway |
| `web/` | Vitrine pública de agendamento (cliente final, sem login) | React 19, TypeScript, Vite, TanStack Query |
| `mobile/` | App de gestão do barbeiro (requer login) | Flutter, provider (MVVM), dio |

## Pré-requisitos

- **Java 21**
- **Docker** (Postgres local + Testcontainers nos testes)
- **Node 20+** — módulo web
- **Flutter 3.x** — módulo mobile

## Subir o banco de dados

```bash
docker compose up -d
```

Sobe um Postgres 16 local (`barbearia-db`, porta 5432, credenciais `barbearia`/`barbearia`/`barbearia`).

---

## Backend

```bash
cd backend
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

Sobe em `http://localhost:8080`. O profile `dev` aplica também as migrations de seed (`db/dev`), que criam um barbeiro de exemplo:

- **E-mail:** `dev@barbearia.local`
- **Senha:** `senha123`
- **Slug:** `barbeiro-dev`

### Criar um novo barbeiro via CLI

```bash
cd backend
./mvnw spring-boot:run -Dspring-boot.run.arguments="--criar-barbeiro --nome='João' --email=joao@x.com --senha=senha123 --slug=joao"
```

### Testes

```bash
cd backend
./mvnw test
```

Requer Docker (Testcontainers sobe um Postgres efêmero por execução). Suíte de integração completa — sem mocks de banco.

---

## Web (vitrine pública)

```bash
cd web
npm install
npm run dev
```

A URL da API vem de `VITE_API_URL`, já configurada em `web/.env.development` como `http://localhost:8080` — com o backend rodando localmente, não precisa mexer.

**O slug do barbeiro vem do path da URL**, não de rota configurada: `App.tsx` lê `window.location.pathname`. Com o Vite em `http://localhost:5173`, a vitrine do barbeiro de seed é `http://localhost:5173/barbeiro-dev`. Abrir a raiz (`/`) sem slug mostra a tela de "barbearia não encontrada" — não é bug.

O fluxo é de etapas (serviço → horário → identificação → sucesso), com `useAgendamentoFlow` guardando o estado e `TanStack Query` cuidando do cache das consultas públicas. Validação de formulário com `zod` (`src/validacao/`).

### Testes, lint e build

```bash
cd web
npm test          # vitest (jsdom + Testing Library)
npm run lint      # oxlint
npm run build     # tsc -b && vite build
```

---

## Mobile (app do barbeiro)

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

`10.0.2.2` é o alias do host da máquina a partir do emulador Android (o backend deve estar rodando localmente na porta 8080) e **já é o padrão** em `lib/main.dart` — o `--dart-define` só é necessário pra apontar pra outro host (dispositivo físico, staging). Login com o barbeiro de seed (`dev@barbearia.local` / `senha123`).

### Arquitetura

MVVM: cada aba (`agenda`, `checkout`, `caixa`, `servicos`, `configuracao`, `auth`) tem sua pasta em `lib/features/`, com um `*_view_model.dart` (`ChangeNotifier`, sem dependência de widgets) e uma ou mais telas (`tela_*.dart`) que só leem o view model e disparam ações — sem lógica de negócio na view. `lib/data/repositories/` concentra as chamadas HTTP (via `dio`) e `lib/data/models/` os DTOs (`fromJson`/`toJson`) espelhando o backend. `lib/core/` tem o cliente HTTP (interceptors de token e conversão de erro para `ApiException`), o armazenamento seguro do token e os formatadores de exibição.

### Convenções que valem a pena saber antes de mexer

Cada uma nasceu de um bug real; quebrá-las traz o bug de volta.

- **ViewModel estende `BaseViewModel` e notifica com `notificarSeAtivo()`**, nunca `notifyListeners()` direto. Trocar de aba descarta o view model, e uma requisição em voo notificando um `ChangeNotifier` descartado quebra o app em debug.
- **Erro de ação pontual volta como `Future<bool>`**, não como campo de estado. Sinal de erro guardado no estado sobrevive ao consumo e reaparece no próximo rebuild (teclado, rotação) — aconteceu três vezes antes de padronizar.
- **`carregar()` usa contador de geração** para descartar resposta antiga que chegue depois de uma mais nova. Sem isso, tocar rápido nas setas de dia deixa a tela com o dia de um lado e os dados de outro, sem indicação nenhuma.
- **Formatação de exibição só via `lib/core/formatadores.dart`.** Atenção: `lib/data/repositories/repository_utils.dart` tem `formatarData`/`formatarMesAno` homônimos, mas são de *wire* (`yyyy-MM-dd` para query param) — não são intercambiáveis.
- **`flutter_localizations` não é cosmético.** Sem os delegates, o date picker por teclado volta pra `mm/dd/yyyy` e cadastrar folga em `08/12` grava 12 de agosto.

### Testes

```bash
cd mobile
flutter test
flutter analyze
```

Testes de `ViewModel` e os widget tests de `App`/`Home` usam `mockito` — sem chamadas HTTP reais. Ao mudar a assinatura de um repository, regenerar os mocks:

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
```

---

## Endpoints principais

| Método | Rota | Autenticação | Descrição |
|---|---|---|---|
| GET | `/api/v1/public/{slug}` | Não | Dados do barbeiro para a vitrine |
| GET | `/api/v1/public/{slug}/servicos` | Não | Lista de serviços |
| GET | `/api/v1/public/{slug}/disponibilidade?data=` | Não (rate limit) | Horários livres do dia |
| POST | `/api/v1/public/{slug}/agendamentos` | Não (rate limit) | Cria agendamento + cliente (se novo) |
| POST | `/api/v1/app/login` | Não | Login do barbeiro, retorna JWT |
| GET | `/api/v1/app/agendamentos?data=` | JWT | Agenda do dia |
| POST | `/api/v1/app/agendamentos/{id}/finalizar` | JWT | Checkout (forma de pagamento) |
| POST | `/api/v1/app/agendamentos/{id}/cancelar` | JWT | Cancelamento (CANCELADO ou NAO_COMPARECEU) |
| GET | `/api/v1/app/caixa?periodo=` | JWT | Faturamento dia/mês |
| CRUD | `/api/v1/app/servicos` | JWT | Gestão de serviços |
| CRUD | `/api/v1/app/horarios` | JWT | Horário de funcionamento + exceções |

Erros seguem sempre `{"erro": "..."}`; o 400 de validação acrescenta `{"campos": {"email": "..."}}`.

## Variáveis de ambiente

### Backend

| Variável | Padrão (dev) | Descrição |
|---|---|---|
| `DB_URL` | `jdbc:postgresql://localhost:5432/barbearia` | URL de conexão do Postgres |
| `DB_USER` | `barbearia` | Usuário do banco |
| `DB_PASSWORD` | `barbearia` | Senha do banco |
| `JWT_SECRET` | chave insegura de dev | Secret HMAC do JWT — **trocar em produção** |

### Web

| Variável | Padrão (dev) | Descrição |
|---|---|---|
| `VITE_API_URL` | `http://localhost:8080` (em `.env.development`) | Base das chamadas à API |

### Mobile

| Variável | Padrão | Descrição |
|---|---|---|
| `API_URL` (via `--dart-define`) | `http://10.0.2.2:8080` | Base das chamadas à API |
