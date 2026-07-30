package com.seusistema.barbearia.horario;

import com.seusistema.barbearia.horario.dto.*;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/app/horarios")
public class HorarioController {

    private final HorarioService horarioService;

    public HorarioController(HorarioService horarioService) {
        this.horarioService = horarioService;
    }

    @GetMapping
    public List<HorarioFuncionamentoDTO> listar(@AuthenticationPrincipal Long barbeiroId) {
        return horarioService.listarHorarios(barbeiroId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public HorarioFuncionamentoDTO criar(@AuthenticationPrincipal Long barbeiroId,
                                         @Valid @RequestBody SalvarHorarioRequest req) {
        return horarioService.criarHorario(barbeiroId, req);
    }

    @PutMapping("/{id}")
    public HorarioFuncionamentoDTO atualizar(@AuthenticationPrincipal Long barbeiroId,
                                             @PathVariable Long id,
                                             @Valid @RequestBody SalvarHorarioRequest req) {
        return horarioService.atualizarHorario(barbeiroId, id, req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void excluir(@AuthenticationPrincipal Long barbeiroId, @PathVariable Long id) {
        horarioService.excluirHorario(barbeiroId, id);
    }

    @GetMapping("/excecoes")
    public List<ExcecaoHorarioDTO> listarExcecoes(@AuthenticationPrincipal Long barbeiroId) {
        return horarioService.listarExcecoes(barbeiroId);
    }

    @PostMapping("/excecoes")
    @ResponseStatus(HttpStatus.CREATED)
    public ExcecaoHorarioDTO criarExcecao(@AuthenticationPrincipal Long barbeiroId,
                                          @Valid @RequestBody SalvarExcecaoRequest req) {
        return horarioService.criarExcecao(barbeiroId, req);
    }

    @DeleteMapping("/excecoes/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void excluirExcecao(@AuthenticationPrincipal Long barbeiroId, @PathVariable Long id) {
        horarioService.excluirExcecao(barbeiroId, id);
    }
}
