package com.seusistema.barbearia.barbeiro;

import com.seusistema.barbearia.barbeiro.dto.*;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/app")
public class BarbeiroController {

    private final BarbeiroService barbeiroService;

    public BarbeiroController(BarbeiroService barbeiroService) {
        this.barbeiroService = barbeiroService;
    }

    @PostMapping("/login")
    public LoginResponse login(@Valid @RequestBody LoginRequest request) {
        return barbeiroService.login(request);
    }
}
