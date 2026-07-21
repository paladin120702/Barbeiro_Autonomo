package com.seusistema.barbearia;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.agendamento.Agendamento;
import com.seusistema.barbearia.agendamento.AgendamentoRepository;
import com.seusistema.barbearia.agendamento.StatusAgendamento;
import com.seusistema.barbearia.barbeiro.Barbeiro;
import com.seusistema.barbearia.barbeiro.BarbeiroRepository;
import com.seusistema.barbearia.cliente.Cliente;
import com.seusistema.barbearia.cliente.ClienteRepository;
import com.seusistema.barbearia.servico.Servico;
import com.seusistema.barbearia.servico.ServicoRepository;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * Prova que as queries de range do AgendamentoRepository são half-open [ini, fim),
 * espelhando o tsrange [) da constraint sem_sobreposicao.
 *
 * Sem estes testes, trocar as queries por Between volta a compilar e a subir o
 * contexto sem nada ficar vermelho — e o limite superior inclusivo contaria
 * agendamento da meia-noite seguinte no dia (e no mês) errado.
 */
class AgendamentoRepositoryTest extends IntegrationTestBase {

    @Autowired BarbeiroRepository barbeiros;
    @Autowired ServicoRepository servicos;
    @Autowired ClienteRepository clientes;
    @Autowired AgendamentoRepository agendamentos;

    static final LocalDate DIA = LocalDate.of(2026, 8, 3);
    static final LocalDateTime INICIO_DIA = DIA.atStartOfDay();
    static final LocalDateTime FIM_EXCLUSIVO = DIA.plusDays(1).atStartOfDay();

    Long barbeiroId;
    Cliente cliente;
    Servico servico;

    @BeforeEach
    void criarFixtures() {
        Barbeiro b = new Barbeiro();
        b.setNome("B");
        b.setEmail("b@b.com");
        b.setSenha("x");
        b.setSlug("b");
        barbeiroId = barbeiros.save(b).getId();

        Servico s = new Servico();
        s.setBarbeiroId(barbeiroId);
        s.setNome("Corte");
        s.setPreco(new BigDecimal("50.00"));
        servico = servicos.save(s);

        Cliente c = new Cliente();
        c.setBarbeiroId(barbeiroId);
        c.setNome("C");
        c.setTelefone("11999999999");
        cliente = clientes.save(c);
    }

    private Agendamento inserir(LocalDateTime inicio, StatusAgendamento status) {
        Agendamento a = new Agendamento();
        a.setBarbeiroId(barbeiroId);
        a.setCliente(cliente);
        a.setServico(servico);
        a.setDataHoraInicio(inicio);
        a.setStatus(status);
        return agendamentos.save(a);
    }

    @Test
    void queryDoDiaExcluiAgendamentoNaMeiaNoiteSeguinteEIncluiODaMeiaNoiteDoDia() {
        inserir(INICIO_DIA, StatusAgendamento.AGENDADO);                       // limite inferior: dentro
        inserir(DIA.atTime(9, 0), StatusAgendamento.AGENDADO);                 // meio do dia: dentro
        inserir(FIM_EXCLUSIVO, StatusAgendamento.AGENDADO);                    // limite superior: FORA

        List<Agendamento> doDia = agendamentos
            .findByBarbeiroIdAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThanOrderByDataHoraInicio(
                barbeiroId, INICIO_DIA, FIM_EXCLUSIVO);

        assertThat(doDia)
            .extracting(Agendamento::getDataHoraInicio)
            .containsExactly(INICIO_DIA, DIA.atTime(9, 0));
    }

    /**
     * Documentação viva do motivo da regra half-open: nos MESMOS dados, o BETWEEN
     * cru devolve a linha da meia-noite seguinte, a query do repository não.
     * Se alguém trocar o repository de volta para Between, é esta diferença que
     * desaparece — e o agendamento passa a ser contado em dois dias.
     */
    @Test
    void betweenInclusivoDevolveUmaLinhaAMaisQueAQueryHalfOpen() {
        inserir(INICIO_DIA, StatusAgendamento.AGENDADO);
        inserir(DIA.atTime(9, 0), StatusAgendamento.AGENDADO);
        inserir(FIM_EXCLUSIVO, StatusAgendamento.AGENDADO);

        List<LocalDateTime> viaBetween = jdbc.queryForList("""
            SELECT data_hora_inicio FROM agendamentos
            WHERE barbeiro_id = ? AND data_hora_inicio BETWEEN ? AND ?
            ORDER BY data_hora_inicio
            """, LocalDateTime.class, barbeiroId, INICIO_DIA, FIM_EXCLUSIVO);

        List<LocalDateTime> viaRepository = agendamentos
            .findByBarbeiroIdAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThanOrderByDataHoraInicio(
                barbeiroId, INICIO_DIA, FIM_EXCLUSIVO)
            .stream()
            .map(Agendamento::getDataHoraInicio)
            .toList();

        assertThat(viaBetween).containsExactly(INICIO_DIA, DIA.atTime(9, 0), FIM_EXCLUSIVO);
        assertThat(viaRepository).containsExactly(INICIO_DIA, DIA.atTime(9, 0));
        assertThat(viaBetween).hasSize(viaRepository.size() + 1);
    }

    @Test
    void queryPorStatusExcluiAgendamentoNaMeiaNoiteSeguinte() {
        inserir(DIA.atTime(9, 0), StatusAgendamento.CONCLUIDO);
        inserir(FIM_EXCLUSIVO, StatusAgendamento.CONCLUIDO);                   // vira faturamento do dia seguinte

        List<Agendamento> concluidosDoDia = agendamentos
            .findByBarbeiroIdAndStatusAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThan(
                barbeiroId, StatusAgendamento.CONCLUIDO, INICIO_DIA, FIM_EXCLUSIVO);

        assertThat(concluidosDoDia)
            .extracting(Agendamento::getDataHoraInicio)
            .containsExactly(DIA.atTime(9, 0));
    }
}
