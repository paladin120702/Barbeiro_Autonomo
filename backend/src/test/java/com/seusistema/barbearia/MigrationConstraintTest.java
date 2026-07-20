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
