package com.seusistema.barbearia.cliente;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ClienteService {

    private final ClienteRepository repository;

    public ClienteService(ClienteRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public Cliente upsert(Long barbeiroId, String nome, String telefoneNormalizado) {
        Cliente cliente = repository.findByBarbeiroIdAndTelefone(barbeiroId, telefoneNormalizado)
            .orElseGet(() -> {
                Cliente novo = new Cliente();
                novo.setBarbeiroId(barbeiroId);
                novo.setTelefone(telefoneNormalizado);
                return novo;
            });
        cliente.setNome(nome);
        return repository.save(cliente);
    }
}
