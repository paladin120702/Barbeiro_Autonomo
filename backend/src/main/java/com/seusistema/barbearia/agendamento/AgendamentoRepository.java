package com.seusistema.barbearia.agendamento;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AgendamentoRepository extends JpaRepository<Agendamento, Long> {

    List<Agendamento> findByBarbeiroIdAndDataHoraInicioBetweenOrderByDataHoraInicio(
            Long id, LocalDateTime ini, LocalDateTime fim);

    Optional<Agendamento> findByIdAndBarbeiroId(Long id, Long barbeiroId);

    List<Agendamento> findByBarbeiroIdAndStatusAndDataHoraInicioBetween(
            Long id, StatusAgendamento status, LocalDateTime ini, LocalDateTime fim);
}
