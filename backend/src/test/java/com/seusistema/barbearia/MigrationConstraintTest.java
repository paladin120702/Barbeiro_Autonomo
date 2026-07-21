package com.seusistema.barbearia;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class MigrationConstraintTest extends IntegrationTestBase {

    Long barbeiroId;
    Long clienteId;
    Long servicoId;

    // A limpeza vem do @BeforeEach de IntegrationTestBase, que roda antes deste.
    @BeforeEach
    void setUp() {
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

    private void inserir(String inicio, String fim, String status) {
        inserir(barbeiroId, clienteId, servicoId, inicio, fim, status);
    }

    private void inserir(Long barbeiro, Long cliente, Long servico, String inicio, String fim, String status) {
        jdbc.update("""
            INSERT INTO agendamentos (barbeiro_id, cliente_id, servico_id, data_hora_inicio, data_hora_fim, status)
            VALUES (?, ?, ?, ?::timestamp, ?::timestamp, ?)
            """, barbeiro, cliente, servico, inicio, fim, status);
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

    @Test
    void constraintPermiteAgendamentosAdjacentes() {
        inserir("2026-08-03 09:00", "2026-08-03 10:00", "AGENDADO");
        assertThatCode(() -> inserir("2026-08-03 10:00", "2026-08-03 11:00", "AGENDADO"))
            .doesNotThrowAnyException();
    }

    @Test
    void constraintBloqueiaSobreposicaoParcial() {
        inserir("2026-08-03 09:00", "2026-08-03 10:30", "AGENDADO");
        assertThatThrownBy(() -> inserir("2026-08-03 10:00", "2026-08-03 11:00", "AGENDADO"))
            .hasMessageContaining("sem_sobreposicao");
    }

    @Test
    void constraintBloqueiaAgendamentoContidoEmOutro() {
        inserir("2026-08-03 09:00", "2026-08-03 11:00", "AGENDADO");
        assertThatThrownBy(() -> inserir("2026-08-03 09:30", "2026-08-03 10:30", "AGENDADO"))
            .hasMessageContaining("sem_sobreposicao");
    }

    @Test
    void constraintPermiteMesmoHorarioParaBarbeirosDiferentes() {
        Long outroBarbeiroId = jdbc.queryForObject(
            "INSERT INTO barbeiros (nome, email, senha, slug) VALUES ('B2', 'b2@b.com', 'x', 'b2') RETURNING id", Long.class);
        Long outroClienteId = jdbc.queryForObject(
            "INSERT INTO clientes (barbeiro_id, nome, telefone) VALUES (?, 'C2', '11988888888') RETURNING id", Long.class, outroBarbeiroId);
        Long outroServicoId = jdbc.queryForObject(
            "INSERT INTO servicos (barbeiro_id, nome, preco) VALUES (?, 'Barba', 40) RETURNING id", Long.class, outroBarbeiroId);

        inserir("2026-08-03 09:00", "2026-08-03 10:00", "AGENDADO");
        assertThatCode(() -> inserir(outroBarbeiroId, outroClienteId, outroServicoId,
                "2026-08-03 09:00", "2026-08-03 10:00", "AGENDADO"))
            .doesNotThrowAnyException();
    }
}
