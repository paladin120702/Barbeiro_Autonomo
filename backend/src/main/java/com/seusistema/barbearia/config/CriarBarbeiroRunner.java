package com.seusistema.barbearia.config;

import com.seusistema.barbearia.barbeiro.Barbeiro;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.stereotype.Component;

@Component
public class CriarBarbeiroRunner implements ApplicationRunner {

    private final BarbeiroService barbeiroService;
    private final ConfigurableApplicationContext context;

    public CriarBarbeiroRunner(BarbeiroService barbeiroService, ConfigurableApplicationContext context) {
        this.barbeiroService = barbeiroService;
        this.context = context;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!args.containsOption("criar-barbeiro")) {
            return;
        }
        Barbeiro b = barbeiroService.criar(new CriarBarbeiroRequest(
            primeiro(args, "nome"), primeiro(args, "email"),
            primeiro(args, "senha"), primeiro(args, "slug")));
        System.out.printf("Barbeiro criado: id=%d slug=%s%n", b.getId(), b.getSlug());
        System.exit(SpringApplication.exit(context, () -> 0));
    }

    private String primeiro(ApplicationArguments args, String nome) {
        var valores = args.getOptionValues(nome);
        return (valores == null || valores.isEmpty()) ? null : valores.get(0);
    }
}
