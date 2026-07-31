package com.seusistema.barbearia.agendamento.dto;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record AgendamentoDTO(
    Long id,
    LocalDateTime dataHoraInicio,
    LocalDateTime dataHoraFim,
    String status,
    String formaPagamento,
    String servicoNome,
    BigDecimal servicoPreco,
    String clienteNome,
    String clienteTelefone
) {
}
