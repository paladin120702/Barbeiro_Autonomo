package com.seusistema.barbearia.servico;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ServicoRepository extends JpaRepository<Servico, Long> {

    List<Servico> findByBarbeiroId(Long barbeiroId);

    Optional<Servico> findByIdAndBarbeiroId(Long id, Long barbeiroId);
}
