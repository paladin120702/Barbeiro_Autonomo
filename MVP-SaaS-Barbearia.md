# MVP — SaaS de Agendamento para Barbeiro Individual

## 1. Visão Geral

Sistema SaaS de agendamento e controle de caixa focado no barbeiro autônomo/individual. O barbeiro contrata o sistema, recebe um link exclusivo (`seusistema.com/{slug}`) para colocar na bio do Instagram, e gerencia toda sua operação (agenda, serviços, caixa) por um aplicativo mobile.

**Fora do escopo do MVP** (decisão consciente para reduzir complexidade e validar o produto mais rápido):
- Envio automático de mensagens via WhatsApp
- Programa de fidelização (pontos)
- Cobrança de assinatura automatizada (apenas um status manual)

---

## 2. Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| Backend | Java + Spring Boot (API REST) |
| Banco de dados | PostgreSQL (Railway ou Render) |
| Migrations | Flyway |
| Frontend Web (cliente) | React.js + TypeScript (Vite) |
| Mobile (barbeiro) | Flutter |
| Arquitetura Backend | MVC em camadas (Controller → Service → Repository) |
| Arquitetura Mobile | MVVM (View / ViewModel via Provider `ChangeNotifier` / Repository) |

---

## 3. Divisão de Responsabilidade

| Área | Onde vive |
|---|---|
| Cliente vê serviços e agenda | React (web, **público, sem login**, página única) |
| Barbeiro faz login | Flutter |
| Barbeiro vê agenda do dia | Flutter |
| Barbeiro finaliza corte + registra forma de pagamento | Flutter |
| Barbeiro vê caixa (dia/mês) | Flutter |
| Barbeiro cadastra/edita serviços | Flutter |
| Barbeiro configura horário de funcionamento e folgas | Flutter |
| Barbeiro cancela agendamento (falta do cliente) | Flutter |
| Toda regra de negócio (disponibilidade, sobreposição, checkout) | Spring Boot |

O React **não tem nenhuma tela autenticada** — é só a vitrine pública de agendamento. Tudo que o barbeiro gerencia é feito no app Flutter.

---

## 4. Modelo de Dados (PostgreSQL)

Regra fixa do MVP: **cada serviço ocupa sempre um slot de 1 hora cheia** (9h, 10h, 11h...), independente da duração informada no serviço. Isso simplifica o cálculo de disponibilidade.

```sql
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE barbeiros (
    id BIGSERIAL PRIMARY KEY,
    nome VARCHAR(120) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    senha VARCHAR(255) NOT NULL,
    slug VARCHAR(60) UNIQUE NOT NULL,
    telefone VARCHAR(20),
    status_conta VARCHAR(20) NOT NULL DEFAULT 'ATIVO' -- ATIVO / INATIVO
);

CREATE TABLE servicos (
    id BIGSERIAL PRIMARY KEY,
    barbeiro_id BIGINT NOT NULL REFERENCES barbeiros(id),
    nome VARCHAR(120) NOT NULL,
    preco NUMERIC(10,2) NOT NULL,
    duracao_minutos INT NOT NULL DEFAULT 60 -- informativo; slot real é sempre 1h
);

CREATE TABLE clientes (
    id BIGSERIAL PRIMARY KEY,
    barbeiro_id BIGINT NOT NULL REFERENCES barbeiros(id),
    nome VARCHAR(120) NOT NULL,
    telefone VARCHAR(20) NOT NULL, -- só para o barbeiro entrar em contato manualmente
    UNIQUE (barbeiro_id, telefone)
);

CREATE TABLE horario_funcionamento (
    id BIGSERIAL PRIMARY KEY,
    barbeiro_id BIGINT NOT NULL REFERENCES barbeiros(id),
    dia_semana SMALLINT NOT NULL, -- 0=domingo ... 6=sábado
    hora_inicio TIME NOT NULL,
    hora_fim TIME NOT NULL,
    ativo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE excecoes_horario (
    id BIGSERIAL PRIMARY KEY,
    barbeiro_id BIGINT NOT NULL REFERENCES barbeiros(id),
    data DATE NOT NULL,
    disponivel BOOLEAN NOT NULL DEFAULT FALSE, -- FALSE = dia fechado (folga/feriado)
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
    data_hora_fim TIMESTAMP NOT NULL, -- sempre data_hora_inicio + 1h
    status VARCHAR(20) NOT NULL DEFAULT 'AGENDADO', -- AGENDADO, CONCLUIDO, CANCELADO, NAO_COMPARECEU
    forma_pagamento VARCHAR(20), -- preenchido só no checkout: PIX, DINHEIRO, DEBITO, CREDITO

    CONSTRAINT sem_sobreposicao EXCLUDE USING gist (
        barbeiro_id WITH =,
        tsrange(data_hora_inicio, data_hora_fim) WITH &&
    ) WHERE (status NOT IN ('CANCELADO', 'NAO_COMPARECEU'))
);
```

**6 tabelas no total.** A constraint `sem_sobreposicao` garante, no nível do banco, que dois agendamentos ativos do mesmo barbeiro nunca se sobreponham — mesmo sob concorrência (dois clientes clicando ao mesmo tempo). Agendamentos cancelados ou com falta do cliente liberam o horário automaticamente.

---

## 5. Backend — Spring Boot (MVC em camadas)

### 5.1 Estrutura de pacotes (por feature)

```
com.seusistema.barbearia
├── config/                        → SecurityConfig, CorsConfig, FlywayConfig
├── security/                      → JWT filter, UserDetailsService (protege /api/v1/app/**)
├── barbeiro/
│   ├── Barbeiro.java
│   ├── BarbeiroRepository.java
│   ├── BarbeiroService.java
│   ├── BarbeiroController.java         → login, perfil (/app)
│   ├── BarbeiroPublicoController.java  → dados públicos da vitrine (/public)
│   └── dto/
├── servico/
│   ├── Servico.java
│   ├── ServicoRepository.java
│   ├── ServicoService.java
│   ├── ServicoController.java          → CRUD (/app)
│   ├── ServicoPublicoController.java   → listar por slug (/public)
│   └── dto/
├── cliente/
│   ├── Cliente.java
│   ├── ClienteRepository.java
│   └── dto/                            → sem controller público direto (criado via agendamento)
├── agendamento/
│   ├── Agendamento.java
│   ├── AgendamentoRepository.java
│   ├── AgendamentoService.java
│   ├── DisponibilidadeService.java     → cruza horário + exceções + agendamentos
│   ├── AgendamentoController.java      → listar dia, finalizar, cancelar (/app)
│   ├── AgendamentoPublicoController.java → criar agendamento (/public)
│   └── dto/
├── horario/
│   ├── HorarioFuncionamento.java
│   ├── ExcecaoHorario.java
│   ├── HorarioRepository.java
│   ├── HorarioService.java
│   └── HorarioController.java          → configuração (/app)
├── caixa/
│   ├── CaixaService.java               → agrega faturamento dia/mês por forma de pagamento
│   └── CaixaController.java            → (/app)
└── common/
    ├── exception/GlobalExceptionHandler.java
    └── ratelimit/RateLimitInterceptor.java  → aplicado só em /public
```

### 5.2 Divisão de rotas

- **`/api/v1/public/{slug}/**`** — sem autenticação. Consumido pelo React. Rate limit por IP aplicado aqui.
- **`/api/v1/app/**`** — protegido por JWT. Consumido exclusivamente pelo Flutter.

### 5.3 Regras principais

**Trava de sobreposição**: garantida pela exclusion constraint do PostgreSQL (seção 4), criada via migration Flyway — **não** pelo Hibernate/JPA. A entidade é mapeada normalmente:

```java
@Entity
@Table(name = "agendamentos")
public class Agendamento {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long barbeiroId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "cliente_id")
    private Cliente cliente;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "servico_id")
    private Servico servico;

    private LocalDateTime dataHoraInicio;
    private LocalDateTime dataHoraFim;

    @Enumerated(EnumType.STRING)
    private StatusAgendamento status = StatusAgendamento.AGENDADO;

    @Enumerated(EnumType.STRING)
    private FormaPagamento formaPagamento;

    @PrePersist
    public void calcularFim() {
        this.dataHoraFim = this.dataHoraInicio.plusHours(1);
    }
}

public enum StatusAgendamento { AGENDADO, CONCLUIDO, CANCELADO, NAO_COMPARECEU }
public enum FormaPagamento { PIX, DINHEIRO, DEBITO, CREDITO }
```

Quando a constraint é violada, o Postgres lança erro que o Spring propaga como `DataIntegrityViolationException`, tratado no `GlobalExceptionHandler`:

```java
@ExceptionHandler(DataIntegrityViolationException.class)
public ResponseEntity<?> handleConflito(DataIntegrityViolationException ex) {
    if (ex.getMessage().contains("sem_sobreposicao")) {
        return ResponseEntity.status(HttpStatus.CONFLICT)
            .body(Map.of("erro", "Esse horário acabou de ser reservado. Escolha outro."));
    }
    throw ex;
}
```

**Rate limit por IP** (Bucket4j), aplicado só nas rotas públicas:

```java
@Component
public class RateLimitInterceptor implements HandlerInterceptor {
    private final Map<String, Bucket> cache = new ConcurrentHashMap<>();

    private Bucket criarBucket() {
        Bandwidth limite = Bandwidth.classic(3, Refill.intervally(3, Duration.ofMinutes(10)));
        return Bucket.builder().addLimit(limite).build();
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String ip = request.getRemoteAddr();
        Bucket bucket = cache.computeIfAbsent(ip, k -> criarBucket());
        if (bucket.tryConsume(1)) return true;
        response.setStatus(429);
        return false;
    }
}
```
> Nota: contador em memória funciona bem para instância única (Railway/Render). Se escalar para múltiplas instâncias, migrar para Redis.

**Cálculo de disponibilidade** (`DisponibilidadeService`):
1. Busca `horario_funcionamento` do dia da semana.
2. Verifica se existe `excecoes_horario` para a data específica (folga/feriado sobrepõe a regra semanal).
3. Gera os slots de hora em hora dentro da janela de funcionamento.
4. Remove os slots que já possuem `agendamentos` com status `AGENDADO` ou `CONCLUIDO`.
5. Retorna a lista de horários livres.

**DTOs sempre** entre Controller e o mundo externo — nunca expor entidade JPA diretamente (evita vazar `senha`, evita `LazyInitializationException` na serialização).

---

## 6. Frontend Web — React + TypeScript (página única, pública)

Projeto simples, sem login, sem rotas complexas, sem estado global.

```
src/
├── api/
│   ├── httpClient.ts
│   └── agendamentoPublicoApi.ts   → getBarbeiro, getServicos, getDisponibilidade, criarAgendamento
├── types/
│   └── dto.ts                     → interfaces espelhando os DTOs públicos do backend
├── components/
│   ├── EtapaServico.tsx
│   ├── EtapaHorario.tsx
│   ├── EtapaIdentificacao.tsx
│   └── TelaSucesso.tsx
├── hooks/
│   └── useAgendamentoFlow.ts
└── App.tsx
```

**Fluxo de estado (state machine simples, sem router):**

```typescript
interface AgendamentoFlowState {
  etapa: 'servico' | 'horario' | 'identificacao' | 'sucesso';
  servicoSelecionado?: ServicoDTO;
  dataHorarioSelecionado?: string; // ISO datetime
  nomeCliente?: string;
  telefoneCliente?: string;
}
```

**Recomendações:**
- **Vite** (não Next.js), a menos que SEO por barbeiro seja relevante — se o tráfego vem majoritariamente do link na bio do Instagram, SSR não traz benefício que justifique a complexidade extra.
- **TanStack Query (React Query)** para cache e tratamento de loading/erro nas chamadas de disponibilidade e serviços.
- **Zod** para validar nome/telefone no formulário, espelhando as regras do backend.

**Fluxo da tela:**
1. Acessa `seusistema.com/{slug}` → carrega dados do barbeiro e lista de serviços.
2. Cliente escolhe o serviço.
3. Sistema busca `GET /api/v1/public/{slug}/disponibilidade?data=...` e exibe horários livres.
4. Cliente informa nome e telefone.
5. `POST /api/v1/public/{slug}/agendamentos` → tela de sucesso.

---

## 7. Mobile — Flutter (MVVM com Provider / ChangeNotifier)

O app concentra **toda** a gestão do negócio: login, agenda, checkout, caixa, cadastro de serviços e configuração de horário.

```
lib/
├── core/
│   ├── network/            → dio client + interceptor JWT
│   ├── storage/             → flutter_secure_storage (token)
│   └── errors/
├── data/
│   ├── models/              → classes Dart com fromJson/toJson
│   └── repositories/
│       ├── auth_repository.dart
│       ├── agendamento_repository.dart
│       ├── servico_repository.dart
│       ├── horario_repository.dart
│       └── caixa_repository.dart
├── features/
│   ├── auth/                        → login
│   ├── agenda/
│   │   ├── agenda_view_model.dart   → ChangeNotifier
│   │   └── tela_agenda_do_dia.dart  → View
│   ├── checkout/             → "Finalizar e Receber" + forma de pagamento
│   ├── caixa/                → faturamento dia/mês por forma de pagamento
│   ├── servicos/             → CRUD de serviços (nome, preço, duração)
│   └── configuracao/         → horário de funcionamento + exceções/folgas
└── main.dart
```

### Padrão MVVM na prática

```dart
// Model — repository
class AgendamentoRepository {
  final Dio dio;
  AgendamentoRepository(this.dio);

  Future<List<Agendamento>> buscarAgendaDoDia(DateTime dia) async {
    final response = await dio.get('/api/v1/app/agendamentos',
      queryParameters: {'data': dia.toIso8601String()});
    return (response.data as List)
        .map((json) => Agendamento.fromJson(json))
        .toList();
  }

  Future<void> finalizar(int id, FormaPagamento forma) async {
    await dio.post('/api/v1/app/agendamentos/$id/finalizar',
      data: {'formaPagamento': forma.name});
  }
}

// ViewModel — ChangeNotifier
enum AgendaStatus { carregando, sucesso, erro }

class AgendaViewModel extends ChangeNotifier {
  final AgendamentoRepository _repository;
  AgendaViewModel(this._repository) {
    carregar();
  }

  AgendaStatus status = AgendaStatus.carregando;
  List<Agendamento> agendamentos = [];
  String? mensagemErro;

  Future<void> carregar() async {
    status = AgendaStatus.carregando;
    notifyListeners();

    try {
      agendamentos = await _repository.buscarAgendaDoDia(DateTime.now());
      status = AgendaStatus.sucesso;
    } catch (e) {
      mensagemErro = 'Erro ao carregar agenda';
      status = AgendaStatus.erro;
    }
    notifyListeners();
  }

  Future<void> finalizarAgendamento(int id, FormaPagamento forma) async {
    await _repository.finalizar(id, forma);
    await carregar(); // recarrega a lista após a ação
  }
}

// View — Widget
class TelaAgendaDoDia extends StatelessWidget {
  const TelaAgendaDoDia({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AgendaViewModel>(
      builder: (context, viewModel, child) {
        switch (viewModel.status) {
          case AgendaStatus.carregando:
            return const Center(child: CircularProgressIndicator());
          case AgendaStatus.erro:
            return Center(child: Text(viewModel.mensagemErro ?? 'Erro'));
          case AgendaStatus.sucesso:
            return ListView.builder(
              itemCount: viewModel.agendamentos.length,
              itemBuilder: (context, index) {
                final agendamento = viewModel.agendamentos[index];
                return AgendamentoTile(
                  agendamento: agendamento,
                  onFinalizar: (forma) =>
                      viewModel.finalizarAgendamento(agendamento.id, forma),
                );
              },
            );
        }
      },
    );
  }
}
```

**Injeção de dependências (`main.dart`)** — repositórios registrados globalmente com `MultiProvider`, e o `ChangeNotifierProvider` da tela criado a partir deles:

```dart
void main() {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.seusistema.com'));

  runApp(
    MultiProvider(
      providers: [
        Provider<Dio>(create: (_) => dio),
        Provider<AgendamentoRepository>(
          create: (context) => AgendamentoRepository(context.read<Dio>()),
        ),
        Provider<AuthRepository>(
          create: (context) => AuthRepository(context.read<Dio>()),
        ),
      ],
      child: const MinhaApp(),
    ),
  );
}

// Na tela que usa a agenda:
ChangeNotifierProvider(
  create: (context) => AgendaViewModel(context.read<AgendamentoRepository>()),
  child: const TelaAgendaDoDia(),
)
```

**Dependências recomendadas:**
- **Dio** — HTTP client com interceptor para anexar JWT automaticamente.
- **provider** — estado (ViewModel via `ChangeNotifier`), mais simples que BLoC para este escopo e mais familiar/estabelecido que Riverpod.
- **flutter_secure_storage** — armazenamento seguro do token JWT.

**Pontos de atenção específicos do Provider/ChangeNotifier:**
- Sempre chamar `notifyListeners()` ao final de todo método do ViewModel que altera estado — é o erro mais comum (tela não atualiza porque foi esquecido).
- Usar `context.watch<T>()` (ou `Consumer`) dentro do `build()` para reagir a mudanças; usar `context.read<T>()` fora do `build()` (ex: dentro de `onPressed`) para apenas disparar uma ação sem se inscrever para rebuilds.
- Sobrescrever `dispose()` no ViewModel se houver recursos a liberar (streams, controllers).

**Telas essenciais (todas no Flutter, já que não existe painel web autenticado):**
1. Login
2. Agenda do dia (timeline)
3. Checkout — "Finalizar e Receber" → seleção da forma de pagamento
4. Caixa — faturamento dia/mês por forma de pagamento
5. Cadastro/edição de serviços
6. Configuração de horário de funcionamento + exceções (folgas pontuais)
7. Cancelamento de agendamento (com acesso ao telefone do cliente para contato manual)

---

## 8. Fluxo de Checkout (regra de negócio central)

1. Cliente senta na cadeira, corta o cabelo, paga fisicamente (Pix, maquininha ou dinheiro).
2. Barbeiro abre o Flutter, seleciona o agendamento, toca em **"Finalizar e Receber"**.
3. App pergunta a forma de pagamento (Pix, Dinheiro, Débito, Crédito).
4. `POST /api/v1/app/agendamentos/{id}/finalizar` — o Service:
   - Muda `status` para `CONCLUIDO`.
   - Grava `forma_pagamento`.
5. A tela de Caixa reflete o novo lançamento (dia/mês, separado por forma de pagamento).

## 9. Fluxo de Falta do Cliente (no-show)

1. Cliente não aparece no horário marcado.
2. Barbeiro abre o Flutter e cancela o agendamento, marcando explicitamente como `NAO_COMPARECEU` (não como `CANCELADO` genérico — mantém o dado histórico separado para métricas futuras).
3. O telefone do cliente (salvo na tabela `clientes`) fica disponível para o barbeiro entrar em contato manualmente, se quiser.
4. O horário é automaticamente liberado (a exclusion constraint ignora status `NAO_COMPARECEU`).

---

## 10. Endpoints Principais (resumo)

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

---

## 11. Resumo das Decisões-Chave

- **6 tabelas**: `barbeiros`, `servicos`, `clientes`, `horario_funcionamento`, `excecoes_horario`, `agendamentos`.
- Slot de agendamento **fixo em 1 hora**, independente do serviço escolhido.
- Sobreposição de horário garantida por **exclusion constraint no PostgreSQL** (não no Hibernate), criada via Flyway.
- Sem WhatsApp, sem fidelização, sem cobrança automatizada no MVP — apenas `status_conta` (ATIVO/INATIVO) manual.
- Telefone do cliente guardado **só para contato manual** do barbeiro.
- Abuso de formulário público mitigado com **rate limit por IP** (Bucket4j).
- Backend em **MVC por camadas** (Controller/Service/Repository) — sem DDD, por ser um domínio simples.
- Mobile em **MVVM** (View/ViewModel via Provider `ChangeNotifier` + Repository) — idioma natural do Flutter e opção mais estabelecida/familiar que Riverpod.
- React web é **só a vitrine pública**, sem autenticação; todo o gerenciamento do negócio acontece no Flutter.
