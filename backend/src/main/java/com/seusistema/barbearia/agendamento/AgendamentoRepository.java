package com.seusistema.barbearia.agendamento;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AgendamentoRepository extends JpaRepository<Agendamento, Long> {

    // Range half-open [ini, fimExclusivo), espelhando o tsrange [) da constraint
    // sem_sobreposicao. Between seria inclusivo nas duas pontas e casaria com um
    // agendamento no limite superior.
    List<Agendamento> findByBarbeiroIdAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThanOrderByDataHoraInicio(
            Long id, LocalDateTime ini, LocalDateTime fimExclusivo);

    Optional<Agendamento> findByIdAndBarbeiroId(Long id, Long barbeiroId);

    List<Agendamento> findByBarbeiroIdAndStatusAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThan(
            Long id, StatusAgendamento status, LocalDateTime ini, LocalDateTime fimExclusivo);
}
