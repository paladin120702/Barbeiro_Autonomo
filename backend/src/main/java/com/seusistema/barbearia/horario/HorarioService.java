package com.seusistema.barbearia.horario;

import com.seusistema.barbearia.common.exception.RecursoNaoEncontradoException;
import com.seusistema.barbearia.common.exception.RegraDeNegocioException;
import com.seusistema.barbearia.horario.dto.ExcecaoHorarioDTO;
import com.seusistema.barbearia.horario.dto.HorarioFuncionamentoDTO;
import com.seusistema.barbearia.horario.dto.SalvarExcecaoRequest;
import com.seusistema.barbearia.horario.dto.SalvarHorarioRequest;
import java.time.LocalTime;
import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class HorarioService {

    private final HorarioFuncionamentoRepository horarioRepository;
    private final ExcecaoHorarioRepository excecaoRepository;

    public HorarioService(HorarioFuncionamentoRepository horarioRepository, ExcecaoHorarioRepository excecaoRepository) {
        this.horarioRepository = horarioRepository;
        this.excecaoRepository = excecaoRepository;
    }

    public List<HorarioFuncionamentoDTO> listarHorarios(Long barbeiroId) {
        return horarioRepository.findByBarbeiroId(barbeiroId).stream()
            .map(this::paraDTO)
            .toList();
    }

    public HorarioFuncionamentoDTO criarHorario(Long barbeiroId, SalvarHorarioRequest req) {
        validarJanela(req.horaInicio(), req.horaFim());
        HorarioFuncionamento h = new HorarioFuncionamento();
        h.setBarbeiroId(barbeiroId);
        h.setDiaSemana(req.diaSemana());
        h.setHoraInicio(req.horaInicio());
        h.setHoraFim(req.horaFim());
        h.setAtivo(req.ativo() == null ? true : req.ativo());
        HorarioFuncionamento salvo = horarioRepository.save(h);
        return paraDTO(salvo);
    }

    public HorarioFuncionamentoDTO atualizarHorario(Long barbeiroId, Long id, SalvarHorarioRequest req) {
        validarJanela(req.horaInicio(), req.horaFim());
        HorarioFuncionamento h = horarioRepository.findByIdAndBarbeiroId(id, barbeiroId)
            .orElseThrow(() -> new RecursoNaoEncontradoException("Horário não encontrado"));
        h.setDiaSemana(req.diaSemana());
        h.setHoraInicio(req.horaInicio());
        h.setHoraFim(req.horaFim());
        h.setAtivo(req.ativo() == null ? true : req.ativo());
        HorarioFuncionamento salvo = horarioRepository.save(h);
        return paraDTO(salvo);
    }

    public void excluirHorario(Long barbeiroId, Long id) {
        HorarioFuncionamento h = horarioRepository.findByIdAndBarbeiroId(id, barbeiroId)
            .orElseThrow(() -> new RecursoNaoEncontradoException("Horário não encontrado"));
        horarioRepository.delete(h);
    }

    public List<ExcecaoHorarioDTO> listarExcecoes(Long barbeiroId) {
        return excecaoRepository.findByBarbeiroId(barbeiroId).stream()
            .map(this::paraDTO)
            .toList();
    }

    public ExcecaoHorarioDTO criarExcecao(Long barbeiroId, SalvarExcecaoRequest req) {
        boolean disponivel = req.disponivel() != null && req.disponivel();
        if (disponivel) {
            validarJanela(req.horaInicio(), req.horaFim());
        }
        if (excecaoRepository.findByBarbeiroIdAndData(barbeiroId, req.data()).isPresent()) {
            throw new RegraDeNegocioException("Já existe exceção para esta data");
        }
        ExcecaoHorario e = new ExcecaoHorario();
        e.setBarbeiroId(barbeiroId);
        e.setData(req.data());
        e.setDisponivel(disponivel);
        e.setHoraInicio(disponivel ? req.horaInicio() : null);
        e.setHoraFim(disponivel ? req.horaFim() : null);
        ExcecaoHorario salvo = excecaoRepository.save(e);
        return paraDTO(salvo);
    }

    public void excluirExcecao(Long barbeiroId, Long id) {
        ExcecaoHorario e = excecaoRepository.findByIdAndBarbeiroId(id, barbeiroId)
            .orElseThrow(() -> new RecursoNaoEncontradoException("Exceção não encontrada"));
        excecaoRepository.delete(e);
    }

    private void validarJanela(LocalTime inicio, LocalTime fim) {
        if (inicio == null || fim == null || !inicio.isBefore(fim)) {
            throw new RegraDeNegocioException("Hora de início deve ser antes da hora de fim");
        }
    }

    private HorarioFuncionamentoDTO paraDTO(HorarioFuncionamento h) {
        return new HorarioFuncionamentoDTO(h.getId(), h.getDiaSemana(), h.getHoraInicio(), h.getHoraFim(), h.isAtivo());
    }

    private ExcecaoHorarioDTO paraDTO(ExcecaoHorario e) {
        return new ExcecaoHorarioDTO(e.getId(), e.getData(), e.isDisponivel(), e.getHoraInicio(), e.getHoraFim());
    }
}
