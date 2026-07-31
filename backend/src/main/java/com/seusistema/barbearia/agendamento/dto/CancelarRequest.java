package com.seusistema.barbearia.agendamento.dto;

import com.seusistema.barbearia.agendamento.StatusAgendamento;
import jakarta.validation.constraints.NotNull;

public record CancelarRequest(@NotNull StatusAgendamento status) {
}
