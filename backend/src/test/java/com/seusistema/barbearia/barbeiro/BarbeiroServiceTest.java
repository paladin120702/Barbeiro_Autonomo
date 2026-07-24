package com.seusistema.barbearia.barbeiro;

import static org.assertj.core.api.Assertions.*;

import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import com.seusistema.barbearia.common.exception.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;

class BarbeiroServiceTest extends IntegrationTestBase {

    @Autowired BarbeiroService service;
    @Autowired BarbeiroRepository repository;
    @Autowired PasswordEncoder encoder;

    @Test
    void criaComSlugGeradoESenhaComHash() {
        Barbeiro b = service.criar(new CriarBarbeiroRequest("João Barber", "j@b.com", "senha123", null));
        assertThat(b.getSlug()).isEqualTo("joao-barber");
        assertThat(b.getSenha()).isNotEqualTo("senha123");
        assertThat(encoder.matches("senha123", b.getSenha())).isTrue();
        assertThat(b.getStatusConta()).isEqualTo(StatusConta.ATIVO);
    }

    @Test
    void rejeitaEmailDuplicado() {
        service.criar(new CriarBarbeiroRequest("A", "dup@b.com", "x12345", "a"));
        assertThatThrownBy(() -> service.criar(new CriarBarbeiroRequest("B", "dup@b.com", "x12345", "b")))
            .isInstanceOf(RegraDeNegocioException.class);
    }

    @Test
    void buscarAtivoPorSlugNaoRetornaInativo() {
        Barbeiro b = service.criar(new CriarBarbeiroRequest("C", "c@b.com", "x12345", "c"));
        b.setStatusConta(StatusConta.INATIVO);
        repository.save(b);
        assertThatThrownBy(() -> service.buscarAtivoPorSlug("c"))
            .isInstanceOf(RecursoNaoEncontradoException.class);
    }

    @Test
    void rejeitaNomeEmBranco() {
        assertThatThrownBy(() -> service.criar(new CriarBarbeiroRequest("   ", "x@b.com", "senha123", null)))
            .isInstanceOf(RegraDeNegocioException.class);
    }
}
