package com.seusistema.barbearia.agendamento.dto;

import java.time.LocalDate;
import java.util.List;

public record DisponibilidadeDTO(LocalDate data, List<String> horarios) {
}
