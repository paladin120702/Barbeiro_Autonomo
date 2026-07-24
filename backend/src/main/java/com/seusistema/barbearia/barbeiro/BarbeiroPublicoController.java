package com.seusistema.barbearia.barbeiro;

import com.seusistema.barbearia.barbeiro.dto.BarbeiroPublicoDTO;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/public/{slug}")
public class BarbeiroPublicoController {

    private final BarbeiroService barbeiroService;

    public BarbeiroPublicoController(BarbeiroService barbeiroService) {
        this.barbeiroService = barbeiroService;
    }

    @GetMapping
    public BarbeiroPublicoDTO buscar(@PathVariable String slug) {
        Barbeiro b = barbeiroService.buscarAtivoPorSlug(slug);
        return new BarbeiroPublicoDTO(b.getNome(), b.getSlug(), b.getTelefone());
    }
}
