package com.seusistema.barbearia.caixa;

import com.seusistema.barbearia.agendamento.Agendamento;
import com.seusistema.barbearia.agendamento.AgendamentoRepository;
import com.seusistema.barbearia.agendamento.FormaPagamento;
import com.seusistema.barbearia.agendamento.StatusAgendamento;
import com.seusistema.barbearia.caixa.dto.CaixaDTO;
import com.seusistema.barbearia.common.exception.RegraDeNegocioException;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;
import java.time.format.DateTimeParseException;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CaixaService {

    private final AgendamentoRepository agendamentos;

    public CaixaService(AgendamentoRepository agendamentos) {
        this.agendamentos = agendamentos;
    }

    // @Transactional(readOnly = true) mantém a sessão Hibernate aberta durante a
    // iteração abaixo, permitindo o lazy loading de a.getServico() (ManyToOne LAZY
    // em Agendamento). Alternativa seria um JOIN FETCH dedicado no repository;
    // optamos por manter a sessão aberta para reaproveitar a query já existente
    // desde a Task 3 sem duplicar o repository.
    @Transactional(readOnly = true)
    public CaixaDTO consultar(Long barbeiroId, String periodo, String data) {
        LocalDateTime inicio;
        LocalDateTime fim;
        try {
            if ("dia".equals(periodo)) {
                LocalDate dia = LocalDate.parse(data);
                inicio = dia.atStartOfDay();
                fim = dia.plusDays(1).atStartOfDay();   // exclusivo
            } else if ("mes".equals(periodo)) {
                YearMonth mes = YearMonth.parse(data);
                inicio = mes.atDay(1).atStartOfDay();
                fim = mes.plusMonths(1).atDay(1).atStartOfDay();   // exclusivo
            } else {
                throw new RegraDeNegocioException("Período inválido");
            }
        } catch (DateTimeParseException e) {
            throw new RegraDeNegocioException("Período inválido");
        }

        List<Agendamento> concluidos = agendamentos
            .findByBarbeiroIdAndStatusAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThan(
                barbeiroId, StatusAgendamento.CONCLUIDO, inicio, fim);   // fim exclusivo

        Map<FormaPagamento, BigDecimal> porForma = new EnumMap<>(FormaPagamento.class);
        for (FormaPagamento f : FormaPagamento.values()) {
            porForma.put(f, BigDecimal.ZERO);
        }
        BigDecimal total = BigDecimal.ZERO;
        for (Agendamento a : concluidos) {
            BigDecimal preco = a.getServico().getPreco();
            total = total.add(preco);
            porForma.merge(a.getFormaPagamento(), preco, BigDecimal::add);
        }
        return new CaixaDTO(total, concluidos.size(), porForma);
    }
}
