package com.seusistema.barbearia.agendamento.dto;

import com.seusistema.barbearia.agendamento.FormaPagamento;
import jakarta.validation.constraints.NotNull;

public record FinalizarRequest(@NotNull FormaPagamento formaPagamento) {
}
