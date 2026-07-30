package com.seusistema.barbearia.horario.dto;

import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;
import java.time.LocalTime;

public record SalvarExcecaoRequest(
    @NotNull LocalDate data,
    Boolean disponivel,
    LocalTime horaInicio,
    LocalTime horaFim
) {
}
