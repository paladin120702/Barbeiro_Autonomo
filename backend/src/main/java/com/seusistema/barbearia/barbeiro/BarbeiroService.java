package com.seusistema.barbearia.barbeiro;

import com.seusistema.barbearia.barbeiro.dto.*;
import com.seusistema.barbearia.common.exception.*;
import com.seusistema.barbearia.security.JwtService;
import java.text.Normalizer;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class BarbeiroService {

    private final BarbeiroRepository repository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public BarbeiroService(BarbeiroRepository repository, PasswordEncoder passwordEncoder,
                           JwtService jwtService) {
        this.repository = repository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    @Transactional
    public Barbeiro criar(CriarBarbeiroRequest req) {
        if (embranco(req.nome()) || embranco(req.email()) || embranco(req.senha())) {
            throw new RegraDeNegocioException("Nome, e-mail e senha são obrigatórios");
        }
        if (repository.existsByEmail(req.email())) {
            throw new RegraDeNegocioException("E-mail já cadastrado");
        }
        String slug = (req.slug() == null || req.slug().isBlank()) ? gerarSlug(req.nome()) : req.slug();
        if (repository.existsBySlug(slug)) {
            throw new RegraDeNegocioException("Slug já em uso");
        }
        Barbeiro b = new Barbeiro();
        b.setNome(req.nome());
        b.setEmail(req.email());
        b.setSenha(passwordEncoder.encode(req.senha()));
        b.setSlug(slug);
        return repository.save(b);
    }

    public LoginResponse login(LoginRequest req) {
        Barbeiro b = repository.findByEmail(req.email())
            .orElseThrow(() -> new BadCredentialsException("credenciais"));
        if (!passwordEncoder.matches(req.senha(), b.getSenha())) {
            throw new BadCredentialsException("credenciais");
        }
        return new LoginResponse(jwtService.gerar(b.getId()), b.getNome(), b.getSlug());
    }

    public Barbeiro buscarAtivoPorSlug(String slug) {
        return repository.findBySlug(slug)
            .filter(b -> b.getStatusConta() == StatusConta.ATIVO)
            .orElseThrow(() -> new RecursoNaoEncontradoException("Barbeiro não encontrado"));
    }

    private String gerarSlug(String nome) {
        String semAcento = Normalizer.normalize(nome, Normalizer.Form.NFD).replaceAll("\\p{M}", "");
        return semAcento.toLowerCase().trim().replaceAll("[^a-z0-9]+", "-").replaceAll("(^-|-$)", "");
    }

    private boolean embranco(String s) {
        return s == null || s.isBlank();
    }
}
