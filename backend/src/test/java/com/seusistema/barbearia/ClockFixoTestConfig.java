package com.seusistema.barbearia;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/**
 * Clock fixo em 2026-08-03T10:30 America/Sao_Paulo (segunda-feira), compartilhado
 * pelos testes que precisam de "agora" controlável (disponibilidade, agendamento,
 * concorrência). Nome do bean method NÃO pode ser "clock": colidiria de nome com
 * o bean clock() do ClockConfig de produção, e o Spring Boot 3.4 rejeita com
 * BeanDefinitionOverrideException antes do @Primary desempatar por tipo.
 */
@TestConfiguration
public class ClockFixoTestConfig {

    @Bean
    @Primary
    Clock clockDeTeste() {
        return Clock.fixed(
            LocalDateTime.of(2026, 8, 3, 10, 30)
                .atZone(ZoneId.of("America/Sao_Paulo"))
                .toInstant(),
            ZoneId.of("America/Sao_Paulo"));
    }
}
