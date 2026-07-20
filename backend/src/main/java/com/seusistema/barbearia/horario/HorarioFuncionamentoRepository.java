package com.seusistema.barbearia.horario;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HorarioFuncionamentoRepository extends JpaRepository<HorarioFuncionamento, Long> {

    List<HorarioFuncionamento> findByBarbeiroId(Long id);

    List<HorarioFuncionamento> findByBarbeiroIdAndDiaSemanaAndAtivoTrue(Long id, int diaSemana);

    Optional<HorarioFuncionamento> findByIdAndBarbeiroId(Long id, Long barbeiroId);
}
