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
