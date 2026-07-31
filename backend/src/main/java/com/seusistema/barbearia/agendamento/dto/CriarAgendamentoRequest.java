package com.seusistema.barbearia.agendamento.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record CriarAgendamentoRequest(
    @NotNull Long servicoId,
    @NotBlank String dataHora,
    @NotBlank String nomeCliente,
    @NotBlank String telefoneCliente
) {
}
