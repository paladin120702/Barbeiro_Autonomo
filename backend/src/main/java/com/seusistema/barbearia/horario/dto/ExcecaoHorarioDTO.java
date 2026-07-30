package com.seusistema.barbearia.horario.dto;

import java.time.LocalDate;
import java.time.LocalTime;

public record ExcecaoHorarioDTO(Long id, LocalDate data, Boolean disponivel, LocalTime horaInicio, LocalTime horaFim) {
}
