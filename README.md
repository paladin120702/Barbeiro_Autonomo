# Barbearia — SaaS de Agendamento

SaaS de agendamento para barbeiro individual: backend Spring Boot com vitrine pública, agenda, caixa e proteção contra agendamento duplicado; web React (vitrine pública, sem login); app Flutter de gestão (Fases 2 e 3, ainda não implementadas). Detalhes completos da arquitetura e das decisões de design em [`MVP-SaaS-Barbearia.md`](MVP-SaaS-Barbearia.md).

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
