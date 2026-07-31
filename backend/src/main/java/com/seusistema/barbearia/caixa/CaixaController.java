package com.seusistema.barbearia.caixa;

import com.seusistema.barbearia.caixa.dto.CaixaDTO;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/app/caixa")
public class CaixaController {

    private final CaixaService caixaService;

    public CaixaController(CaixaService caixaService) {
        this.caixaService = caixaService;
    }

    @GetMapping
    public CaixaDTO consultar(@AuthenticationPrincipal Long barbeiroId,
            @RequestParam String periodo, @RequestParam String data) {
        return caixaService.consultar(barbeiroId, periodo, data);
    }
}
