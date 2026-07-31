package com.seusistema.barbearia.agendamento.dto;

import java.time.LocalDateTime;

public record AgendamentoCriadoDTO(Long id, String servicoNome, LocalDateTime dataHoraInicio, String nomeCliente) {
}
