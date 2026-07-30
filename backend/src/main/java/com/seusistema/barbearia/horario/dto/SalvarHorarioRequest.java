package com.seusistema.barbearia.horario.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.time.LocalTime;

public record SalvarHorarioRequest(
    @NotNull @Min(0) @Max(6) Integer diaSemana,
    @NotNull LocalTime horaInicio,
    @NotNull LocalTime horaFim,
    Boolean ativo
) {
}
