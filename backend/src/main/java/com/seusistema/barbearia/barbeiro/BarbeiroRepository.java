package com.seusistema.barbearia.barbeiro;

import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BarbeiroRepository extends JpaRepository<Barbeiro, Long> {

    Optional<Barbeiro> findBySlug(String slug);

    Optional<Barbeiro> findByEmail(String email);

    boolean existsBySlug(String slug);

    boolean existsByEmail(String email);
}
