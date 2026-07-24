package com.seusistema.barbearia.servico;

import com.seusistema.barbearia.servico.dto.*;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/app/servicos")
public class ServicoController {

    private final ServicoService servicoService;

    public ServicoController(ServicoService servicoService) {
        this.servicoService = servicoService;
    }

    @GetMapping
    public List<ServicoDTO> listar(@AuthenticationPrincipal Long barbeiroId) {
        return servicoService.listarPorBarbeiro(barbeiroId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ServicoDTO criar(@AuthenticationPrincipal Long barbeiroId,
                            @Valid @RequestBody SalvarServicoRequest req) {
        return servicoService.criar(barbeiroId, req);
    }

    @PutMapping("/{id}")
    public ServicoDTO atualizar(@AuthenticationPrincipal Long barbeiroId, @PathVariable Long id,
                                @Valid @RequestBody SalvarServicoRequest req) {
        return servicoService.atualizar(barbeiroId, id, req);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void excluir(@AuthenticationPrincipal Long barbeiroId, @PathVariable Long id) {
        servicoService.excluir(barbeiroId, id);
    }
}
