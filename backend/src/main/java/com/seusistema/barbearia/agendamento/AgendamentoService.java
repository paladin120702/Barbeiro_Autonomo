package com.seusistema.barbearia.agendamento;

import com.seusistema.barbearia.agendamento.dto.AgendamentoCriadoDTO;
import com.seusistema.barbearia.agendamento.dto.AgendamentoDTO;
import com.seusistema.barbearia.agendamento.dto.CancelarRequest;
import com.seusistema.barbearia.agendamento.dto.CriarAgendamentoRequest;
import com.seusistema.barbearia.agendamento.dto.FinalizarRequest;
import com.seusistema.barbearia.barbeiro.Barbeiro;
import com.seusistema.barbearia.barbeiro.BarbeiroService;
import com.seusistema.barbearia.cliente.Cliente;
import com.seusistema.barbearia.cliente.ClienteService;
import com.seusistema.barbearia.common.exception.RecursoNaoEncontradoException;
import com.seusistema.barbearia.common.exception.RegraDeNegocioException;
import com.seusistema.barbearia.common.validacao.TelefoneBR;
import com.seusistema.barbearia.servico.Servico;
import com.seusistema.barbearia.servico.ServicoRepository;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AgendamentoService {

    private final BarbeiroService barbeiroService;
    private final ServicoRepository servicoRepository;
    private final ClienteService clienteService;
    private final AgendamentoRepository agendamentoRepository;
    private final DisponibilidadeService disponibilidadeService;
    private final Clock clock;

    public AgendamentoService(BarbeiroService barbeiroService,
                              ServicoRepository servicoRepository,
                              ClienteService clienteService,
                              AgendamentoRepository agendamentoRepository,
                              DisponibilidadeService disponibilidadeService,
                              Clock clock) {
        this.barbeiroService = barbeiroService;
        this.servicoRepository = servicoRepository;
        this.clienteService = clienteService;
        this.agendamentoRepository = agendamentoRepository;
        this.disponibilidadeService = disponibilidadeService;
        this.clock = clock;
    }

    @Transactional
    public AgendamentoCriadoDTO criarPublico(String slug, CriarAgendamentoRequest req) {
        Barbeiro barbeiro = barbeiroService.buscarAtivoPorSlug(slug);

        String telefoneNormalizado = TelefoneBR.normalizar(req.telefoneCliente());
        if (!TelefoneBR.valido(telefoneNormalizado)) {
            throw new RegraDeNegocioException("Telefone inválido");
        }

        Servico servico = servicoRepository.findByIdAndBarbeiroId(req.servicoId(), barbeiro.getId())
            .orElseThrow(() -> new RecursoNaoEncontradoException("Serviço não encontrado"));

        LocalDateTime dataHoraInicio;
        try {
            dataHoraInicio = LocalDateTime.parse(req.dataHora());
        } catch (DateTimeParseException e) {
            throw new RegraDeNegocioException("Data/hora inválida");
        }

        if (dataHoraInicio.getMinute() != 0 || dataHoraInicio.getSecond() != 0 || dataHoraInicio.getNano() != 0) {
            throw new RegraDeNegocioException("Horário deve ser em hora cheia");
        }

        LocalDateTime agora = LocalDateTime.now(clock);
        LocalDate limite = agora.toLocalDate().plusDays(30);
        if (!dataHoraInicio.isAfter(agora) || dataHoraInicio.toLocalDate().isAfter(limite)) {
            throw new RegraDeNegocioException("Data fora do período de agendamento");
        }

        LocalTime horario = dataHoraInicio.toLocalTime();
        boolean livre = disponibilidadeService.horariosLivres(barbeiro.getId(), dataHoraInicio.toLocalDate())
            .contains(horario);
        if (!livre) {
            throw new RegraDeNegocioException("Horário indisponível");
        }

        Cliente cliente = clienteService.upsert(barbeiro.getId(), req.nomeCliente(), telefoneNormalizado);

        Agendamento agendamento = new Agendamento();
        agendamento.setBarbeiroId(barbeiro.getId());
        agendamento.setCliente(cliente);
        agendamento.setServico(servico);
        agendamento.setDataHoraInicio(dataHoraInicio);
        Agendamento salvo = agendamentoRepository.save(agendamento);

        return new AgendamentoCriadoDTO(salvo.getId(), servico.getNome(), salvo.getDataHoraInicio(), cliente.getNome());
    }

    @Transactional
    public List<AgendamentoDTO> listarDia(Long barbeiroId, LocalDate data) {
        return agendamentoRepository
            .listarDia(barbeiroId, data.atStartOfDay(), data.plusDays(1).atStartOfDay())
            .stream()
            .map(this::toDTO)
            .toList();
    }

    @Transactional
    public AgendamentoDTO finalizar(Long barbeiroId, Long id, FinalizarRequest req) {
        Agendamento agendamento = agendamentoRepository.findByIdAndBarbeiroId(id, barbeiroId)
            .orElseThrow(() -> new RecursoNaoEncontradoException("Agendamento não encontrado"));

        if (agendamento.getStatus() != StatusAgendamento.AGENDADO) {
            throw new RegraDeNegocioException("Agendamento não pode ser finalizado");
        }

        agendamento.setStatus(StatusAgendamento.CONCLUIDO);
        agendamento.setFormaPagamento(req.formaPagamento());
        return toDTO(agendamentoRepository.save(agendamento));
    }

    @Transactional
    public AgendamentoDTO cancelar(Long barbeiroId, Long id, CancelarRequest req) {
        Agendamento agendamento = agendamentoRepository.findByIdAndBarbeiroId(id, barbeiroId)
            .orElseThrow(() -> new RecursoNaoEncontradoException("Agendamento não encontrado"));

        if (req.status() != StatusAgendamento.CANCELADO && req.status() != StatusAgendamento.NAO_COMPARECEU) {
            throw new RegraDeNegocioException("Status de cancelamento inválido");
        }

        if (agendamento.getStatus() != StatusAgendamento.AGENDADO) {
            throw new RegraDeNegocioException("Agendamento não pode ser cancelado");
        }

        agendamento.setStatus(req.status());
        return toDTO(agendamentoRepository.save(agendamento));
    }

    private AgendamentoDTO toDTO(Agendamento a) {
        return new AgendamentoDTO(
            a.getId(),
            a.getDataHoraInicio(),
            a.getDataHoraFim(),
            a.getStatus().name(),
            a.getFormaPagamento() != null ? a.getFormaPagamento().name() : null,
            a.getServico().getNome(),
            a.getServico().getPreco(),
            a.getCliente().getNome(),
            a.getCliente().getTelefone());
    }
}
