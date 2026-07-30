package com.seusistema.barbearia.horario.dto;

import java.time.LocalTime;

public record HorarioFuncionamentoDTO(Long id, Integer diaSemana, LocalTime horaInicio, LocalTime horaFim, Boolean ativo) {
}
