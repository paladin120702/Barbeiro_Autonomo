package com.seusistema.barbearia.servico.dto;

import java.math.BigDecimal;

public record ServicoDTO(Long id, String nome, BigDecimal preco, Integer duracaoMinutos) {
}
