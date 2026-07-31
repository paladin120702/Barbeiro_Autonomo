package com.seusistema.barbearia.caixa.dto;

import com.seusistema.barbearia.agendamento.FormaPagamento;
import java.math.BigDecimal;
import java.util.Map;

public record CaixaDTO(
    BigDecimal total,
    int quantidade,
    Map<FormaPagamento, BigDecimal> porFormaPagamento
) {
}
