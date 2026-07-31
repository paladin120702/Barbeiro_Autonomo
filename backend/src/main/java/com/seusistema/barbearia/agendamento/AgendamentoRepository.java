package com.seusistema.barbearia.agendamento;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AgendamentoRepository extends JpaRepository<Agendamento, Long> {

    // Range half-open [ini, fimExclusivo), espelhando o tsrange [) da constraint
    // sem_sobreposicao. Between seria inclusivo nas duas pontas e casaria com um
    // agendamento no limite superior.
    List<Agendamento> findByBarbeiroIdAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThanOrderByDataHoraInicio(
            Long id, LocalDateTime ini, LocalDateTime fimExclusivo);

    // JOIN FETCH de cliente/serviço para evitar N+1/lazy na montagem do DTO da
    // agenda do dia; range half-open [ini, fim) igual às demais queries de data.
    @Query("SELECT a FROM Agendamento a JOIN FETCH a.cliente JOIN FETCH a.servico "
            + "WHERE a.barbeiroId = :barbeiroId AND a.dataHoraInicio >= :ini AND a.dataHoraInicio < :fim "
            + "ORDER BY a.dataHoraInicio")
    List<Agendamento> listarDia(@Param("barbeiroId") Long barbeiroId,
            @Param("ini") LocalDateTime ini, @Param("fim") LocalDateTime fim);

    Optional<Agendamento> findByIdAndBarbeiroId(Long id, Long barbeiroId);

    List<Agendamento> findByBarbeiroIdAndStatusAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThan(
            Long id, StatusAgendamento status, LocalDateTime ini, LocalDateTime fimExclusivo);

    boolean existsByServicoId(Long servicoId);
}
