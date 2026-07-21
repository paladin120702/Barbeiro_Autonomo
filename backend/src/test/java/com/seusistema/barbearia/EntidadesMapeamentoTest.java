package com.seusistema.barbearia;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.agendamento.*;
import com.seusistema.barbearia.barbeiro.*;
import com.seusistema.barbearia.cliente.*;
import com.seusistema.barbearia.servico.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class EntidadesMapeamentoTest extends IntegrationTestBase {

    @Autowired BarbeiroRepository barbeiros;
    @Autowired ServicoRepository servicos;
    @Autowired ClienteRepository clientes;
    @Autowired AgendamentoRepository agendamentos;

    // A limpeza vem do @BeforeEach de IntegrationTestBase.

    @Test
    void persisteGrafoCompletoECalculaFimNoPrePersist() {
        Barbeiro b = new Barbeiro();
        b.setNome("João");
        b.setEmail("joao@teste.com");
        b.setSenha("hash");
        b.setSlug("joao-barber");
        b = barbeiros.save(b);
        assertThat(b.getStatusConta()).isEqualTo(StatusConta.ATIVO);

        Servico s = new Servico();
        s.setBarbeiroId(b.getId());
        s.setNome("Corte");
        s.setPreco(new BigDecimal("50.00"));
        s = servicos.save(s);
        assertThat(s.getDuracaoMinutos()).isEqualTo(60);

        Cliente c = new Cliente();
        c.setBarbeiroId(b.getId());
        c.setNome("Cliente");
        c.setTelefone("11999999999");
        c = clientes.save(c);

        Agendamento a = new Agendamento();
        a.setBarbeiroId(b.getId());
        a.setCliente(c);
        a.setServico(s);
        a.setDataHoraInicio(LocalDateTime.of(2026, 8, 3, 9, 0));
        a = agendamentos.save(a);

        assertThat(a.getDataHoraFim()).isEqualTo(LocalDateTime.of(2026, 8, 3, 10, 0));
        assertThat(a.getStatus()).isEqualTo(StatusAgendamento.AGENDADO);
    }
}
