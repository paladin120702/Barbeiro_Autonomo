package com.seusistema.barbearia.agendamento;

import com.seusistema.barbearia.agendamento.dto.AgendamentoCriadoDTO;
import com.seusistema.barbearia.agendamento.dto.CriarAgendamentoRequest;
import com.seusistema.barbearia.agendamento.dto.DisponibilidadeDTO;
import com.seusistema.barbearia.barbeiro.*;
import com.seusistema.barbearia.common.exception.RegraDeNegocioException;
import jakarta.validation.Valid;
import java.time.Clock;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/public/{slug}")
public class AgendamentoPublicoController {

    private final BarbeiroService barbeiroService;
    private final DisponibilidadeService disponibilidadeService;
    private final AgendamentoService agendamentoService;
    private final Clock clock;

    public AgendamentoPublicoController(BarbeiroService barbeiroService,
                                        DisponibilidadeService disponibilidadeService,
                                        AgendamentoService agendamentoService,
                                        Clock clock) {
        this.barbeiroService = barbeiroService;
        this.disponibilidadeService = disponibilidadeService;
        this.agendamentoService = agendamentoService;
        this.clock = clock;
    }

    @GetMapping("/disponibilidade")
    public DisponibilidadeDTO disponibilidade(@PathVariable String slug,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate data) {
        Barbeiro b = barbeiroService.buscarAtivoPorSlug(slug);
        LocalDate hoje = LocalDate.now(clock);
        if (data.isBefore(hoje) || data.isAfter(hoje.plusDays(30))) {
            throw new RegraDeNegocioException("Data fora do período de agendamento");
        }
        var horarios = disponibilidadeService.horariosLivres(b.getId(), data).stream()
            .map(h -> h.format(DateTimeFormatter.ofPattern("HH:mm")))
            .toList();
        return new DisponibilidadeDTO(data, horarios);
    }

    @PostMapping("/agendamentos")
    @ResponseStatus(HttpStatus.CREATED)
    public AgendamentoCriadoDTO criar(@PathVariable String slug,
                                      @Valid @RequestBody CriarAgendamentoRequest req) {
        return agendamentoService.criarPublico(slug, req);
    }
}
