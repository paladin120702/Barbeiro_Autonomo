package com.seusistema.barbearia.servico;

import com.seusistema.barbearia.barbeiro.Barbeiro;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.servico.dto.ServicoDTO;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/public/{slug}/servicos")
public class ServicoPublicoController {

    private final BarbeiroService barbeiroService;
    private final ServicoService servicoService;

    public ServicoPublicoController(BarbeiroService barbeiroService, ServicoService servicoService) {
        this.barbeiroService = barbeiroService;
        this.servicoService = servicoService;
    }

    @GetMapping
    public List<ServicoDTO> listar(@PathVariable String slug) {
        Barbeiro b = barbeiroService.buscarAtivoPorSlug(slug);
        return servicoService.listarPorBarbeiro(b.getId());
    }
}
