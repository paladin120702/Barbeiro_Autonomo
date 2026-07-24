package com.seusistema.barbearia.servico.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import java.math.BigDecimal;

public record SalvarServicoRequest(
    @NotBlank String nome,
    @NotNull @Positive BigDecimal preco,
    Integer duracaoMinutos
) {
}
