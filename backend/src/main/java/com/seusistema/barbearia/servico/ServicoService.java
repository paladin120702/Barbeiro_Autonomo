package com.seusistema.barbearia.servico;

import com.seusistema.barbearia.agendamento.AgendamentoRepository;
import com.seusistema.barbearia.common.exception.RecursoNaoEncontradoException;
import com.seusistema.barbearia.common.exception.RegraDeNegocioException;
import com.seusistema.barbearia.servico.dto.SalvarServicoRequest;
import com.seusistema.barbearia.servico.dto.ServicoDTO;
import java.util.Comparator;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class ServicoService {

    private final ServicoRepository repository;
    private final AgendamentoRepository agendamentoRepository;

    public ServicoService(ServicoRepository repository, AgendamentoRepository agendamentoRepository) {
        this.repository = repository;
        this.agendamentoRepository = agendamentoRepository;
    }

    public List<ServicoDTO> listarPorBarbeiro(Long barbeiroId) {
        return repository.findByBarbeiroId(barbeiroId).stream()
            .sorted(Comparator.comparing(Servico::getNome))
            .map(s -> new ServicoDTO(s.getId(), s.getNome(), s.getPreco(), s.getDuracaoMinutos()))
            .toList();
    }

    public ServicoDTO criar(Long barbeiroId, SalvarServicoRequest req) {
        Servico s = new Servico();
        s.setBarbeiroId(barbeiroId);
        s.setNome(req.nome());
        s.setPreco(req.preco());
        s.setDuracaoMinutos(req.duracaoMinutos() == null ? 60 : req.duracaoMinutos());
        Servico salvo = repository.save(s);
        return new ServicoDTO(salvo.getId(), salvo.getNome(), salvo.getPreco(), salvo.getDuracaoMinutos());
    }

    public ServicoDTO atualizar(Long barbeiroId, Long id, SalvarServicoRequest req) {
        Servico s = repository.findByIdAndBarbeiroId(id, barbeiroId)
            .orElseThrow(() -> new RecursoNaoEncontradoException("Serviço não encontrado"));
        s.setNome(req.nome());
        s.setPreco(req.preco());
        s.setDuracaoMinutos(req.duracaoMinutos() == null ? 60 : req.duracaoMinutos());
        Servico salvo = repository.save(s);
        return new ServicoDTO(salvo.getId(), salvo.getNome(), salvo.getPreco(), salvo.getDuracaoMinutos());
    }

    public void excluir(Long barbeiroId, Long id) {
        Servico s = repository.findByIdAndBarbeiroId(id, barbeiroId)
            .orElseThrow(() -> new RecursoNaoEncontradoException("Serviço não encontrado"));
        if (agendamentoRepository.existsByServicoId(id)) {
            throw new RegraDeNegocioException("Serviço possui agendamentos e não pode ser excluído");
        }
        repository.delete(s);
    }
}
