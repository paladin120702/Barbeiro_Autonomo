# Barbearia — SaaS de Agendamento

SaaS de agendamento para barbeiro individual: backend Spring Boot com vitrine pública, agenda, caixa e proteção contra agendamento duplicado; web React (vitrine pública, sem login); app Flutter de gestão (agenda, checkout, caixa, serviços e configuração de horários). Detalhes completos da arquitetura e das decisões de design em [`MVP-SaaS-Barbearia.md`](MVP-SaaS-Barbearia.md).

## Pré-requisitos

- **Java 21**
- **Docker** (Postgres local + Testcontainers nos testes)
- Node 20+ — *Fase 2 (web)*
- Flutter 3.x — *Fase 3 (mobile)*

## Subir o banco de dados

```bash
docker compose up -d
```

Sobe um Postgres 16 local (`barbearia-db`, porta 5432, credenciais `barbearia`/`barbearia`/`barbearia`).

## Rodar o backend

```bash
cd backend
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

O profile `dev` aplica também as migrations de seed (`db/dev`), que criam um barbeiro de exemplo:

- **E-mail:** `dev@barbearia.local`
- **Senha:** `senha123`
- **Slug:** `barbeiro-dev`

## Criar um novo barbeiro via CLI

```bash
./mvnw spring-boot:run -Dspring-boot.run.arguments="--criar-barbeiro --nome='João' --email=joao@x.com --senha=senha123 --slug=joao"
```

## Rodar os testes

```bash
cd backend
./mvnw test
```

Requer Docker (Testcontainers sobe um Postgres efêmero por execução). Suíte de integração completa — sem mocks de banco.

## Rodar o app mobile

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

`10.0.2.2` é o alias do host da máquina a partir do emulador Android (o backend deve estar rodando localmente na porta 8080). Login com o barbeiro de seed (`dev@barbearia.local` / `senha123`).

App Flutter com arquitetura MVVM: cada aba (`agenda`, `checkout`, `caixa`, `servicos`, `configuracao`, `auth`) tem sua pasta em `lib/features/`, com um `*_view_model.dart` (`ChangeNotifier`, sem dependência de widgets) e uma ou mais telas (`tela_*.dart`) que só leem o view model e disparam ações — sem lógica de negócio na view. `lib/data/repositories/` concentra as chamadas HTTP (via `Dio`) e `lib/data/models/` os DTOs (`fromJson`/`toJson`) espelhando o backend. `lib/core/` tem o cliente HTTP (interceptors de token e conversão de erro para `ApiException`) e o armazenamento seguro do token.

### Rodar os testes do mobile

```bash
cd mobile
flutter test
```

Testes de `ViewModel` usam `mockito` (mocks gerados com `dart run build_runner build --delete-conflicting-outputs`) — sem chamadas HTTP reais.

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

## Variáveis de ambiente

| Variável | Padrão (dev) | Descrição |
|---|---|---|
| `DB_URL` | `jdbc:postgresql://localhost:5432/barbearia` | URL de conexão do Postgres |
| `DB_USER` | `barbearia` | Usuário do banco |
| `DB_PASSWORD` | `barbearia` | Senha do banco |
| `JWT_SECRET` | chave insegura de dev | Secret HMAC do JWT — **trocar em produção** |
