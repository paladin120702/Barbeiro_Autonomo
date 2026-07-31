package com.seusistema.barbearia.agendamento;

import com.seusistema.barbearia.agendamento.dto.*;
import jakarta.validation.Valid;
import java.time.LocalDate;
import java.util.List;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/app/agendamentos")
public class AgendamentoController {

    private final AgendamentoService agendamentoService;

    public AgendamentoController(AgendamentoService agendamentoService) {
        this.agendamentoService = agendamentoService;
    }

    @GetMapping
    public List<AgendamentoDTO> listarDia(@AuthenticationPrincipal Long barbeiroId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate data) {
        return agendamentoService.listarDia(barbeiroId, data);
    }

    @PostMapping("/{id}/finalizar")
    public AgendamentoDTO finalizar(@AuthenticationPrincipal Long barbeiroId, @PathVariable Long id,
                                    @Valid @RequestBody FinalizarRequest req) {
        return agendamentoService.finalizar(barbeiroId, id, req);
    }

    @PostMapping("/{id}/cancelar")
    public AgendamentoDTO cancelar(@AuthenticationPrincipal Long barbeiroId, @PathVariable Long id,
                                   @Valid @RequestBody CancelarRequest req) {
        return agendamentoService.cancelar(barbeiroId, id, req);
    }
}
