package com.seusistema.barbearia.agendamento;

import com.seusistema.barbearia.horario.*;
import java.time.*;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Service;

@Service
public class DisponibilidadeService {

    private final HorarioFuncionamentoRepository horarios;
    private final ExcecaoHorarioRepository excecoes;
    private final AgendamentoRepository agendamentos;
    private final Clock clock;

    public DisponibilidadeService(HorarioFuncionamentoRepository horarios,
                                  ExcecaoHorarioRepository excecoes,
                                  AgendamentoRepository agendamentos,
                                  Clock clock) {
        this.horarios = horarios;
        this.excecoes = excecoes;
        this.agendamentos = agendamentos;
        this.clock = clock;
    }

    public List<LocalTime> horariosLivres(Long barbeiroId, LocalDate data) {
        List<LocalTime[]> janelas = janelasDoDia(barbeiroId, data);
        if (janelas.isEmpty()) {
            return List.of();
        }

        Set<LocalTime> ocupados = agendamentos
            .findByBarbeiroIdAndDataHoraInicioGreaterThanEqualAndDataHoraInicioLessThanOrderByDataHoraInicio(
                barbeiroId, data.atStartOfDay(), data.plusDays(1).atStartOfDay())
            .stream()
            .filter(a -> a.getStatus() == StatusAgendamento.AGENDADO
                      || a.getStatus() == StatusAgendamento.CONCLUIDO)
            .map(a -> a.getDataHoraInicio().toLocalTime())
            .collect(java.util.stream.Collectors.toSet());

        LocalDateTime agora = LocalDateTime.now(clock);
        List<LocalTime> livres = new ArrayList<>();
        for (LocalTime[] janela : janelas) {
            LocalTime slot = arredondarParaCima(janela[0]);
            while (!slot.plusHours(1).isAfter(janela[1]) && !slot.plusHours(1).equals(LocalTime.MIDNIGHT)) {
                boolean passado = data.equals(agora.toLocalDate()) && !data.atTime(slot).isAfter(agora);
                if (!ocupados.contains(slot) && !passado) {
                    livres.add(slot);
                }
                slot = slot.plusHours(1);
            }
        }
        return livres.stream().sorted().toList();
    }

    private List<LocalTime[]> janelasDoDia(Long barbeiroId, LocalDate data) {
        var excecao = excecoes.findByBarbeiroIdAndData(barbeiroId, data);
        if (excecao.isPresent()) {
            ExcecaoHorario e = excecao.get();
            if (!e.isDisponivel()) {
                return List.of();
            }
            return List.<LocalTime[]>of(new LocalTime[]{e.getHoraInicio(), e.getHoraFim()});
        }
        int diaSemana = data.getDayOfWeek().getValue() % 7;
        return horarios.findByBarbeiroIdAndDiaSemanaAndAtivoTrue(barbeiroId, diaSemana).stream()
            .map(h -> new LocalTime[]{h.getHoraInicio(), h.getHoraFim()})
            .toList();
    }

    private LocalTime arredondarParaCima(LocalTime hora) {
        return hora.getMinute() == 0 && hora.getSecond() == 0
            ? hora
            : hora.plusHours(1).withMinute(0).withSecond(0).withNano(0);
    }
}
