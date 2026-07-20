package com.seusistema.barbearia.horario;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ExcecaoHorarioRepository extends JpaRepository<ExcecaoHorario, Long> {

    List<ExcecaoHorario> findByBarbeiroId(Long id);

    Optional<ExcecaoHorario> findByBarbeiroIdAndData(Long id, LocalDate data);

    Optional<ExcecaoHorario> findByIdAndBarbeiroId(Long id, Long barbeiroId);
}
