package com.seusistema.barbearia.servico;

import com.seusistema.barbearia.servico.dto.ServicoDTO;
import java.util.Comparator;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class ServicoService {

    private final ServicoRepository repository;

    public ServicoService(ServicoRepository repository) {
        this.repository = repository;
    }

    public List<ServicoDTO> listarPorBarbeiro(Long barbeiroId) {
        return repository.findByBarbeiroId(barbeiroId).stream()
            .sorted(Comparator.comparing(Servico::getNome))
            .map(s -> new ServicoDTO(s.getId(), s.getNome(), s.getPreco(), s.getDuracaoMinutos()))
            .toList();
    }
}
