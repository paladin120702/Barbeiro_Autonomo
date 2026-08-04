import { act, renderHook } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { useAgendamentoFlow } from './useAgendamentoFlow';
import type { ServicoDTO } from '../types/dto';

describe('useAgendamentoFlow', () => {
  const servico: ServicoDTO = {
    id: 1,
    nome: 'Corte',
    preco: 50,
    duracaoMinutos: 30,
  };

  it('fluxo feliz: servico → horario → identificacao → sucesso, carregando os dados', () => {
    const { result } = renderHook(() => useAgendamentoFlow());

    expect(result.current.state).toEqual({ etapa: 'servico' });

    act(() => {
      result.current.selecionarServico(servico);
    });
    expect(result.current.state).toEqual({
      etapa: 'horario',
      servicoSelecionado: servico,
    });

    act(() => {
      result.current.selecionarHorario('2026-08-03T14:00:00');
    });
    expect(result.current.state).toEqual({
      etapa: 'identificacao',
      servicoSelecionado: servico,
      dataHorarioSelecionado: '2026-08-03T14:00:00',
    });

    act(() => {
      result.current.identificar('João Silva', '11987654321');
    });
    expect(result.current.state).toEqual({
      etapa: 'identificacao',
      servicoSelecionado: servico,
      dataHorarioSelecionado: '2026-08-03T14:00:00',
      nomeCliente: 'João Silva',
      telefoneCliente: '11987654321',
    });

    act(() => {
      result.current.concluir();
    });
    expect(result.current.state).toEqual({
      etapa: 'sucesso',
      servicoSelecionado: servico,
      dataHorarioSelecionado: '2026-08-03T14:00:00',
      nomeCliente: 'João Silva',
      telefoneCliente: '11987654321',
    });
  });

  it('voltarParaHorario limpa apenas o horário e mantém o serviço', () => {
    const { result } = renderHook(() => useAgendamentoFlow());

    act(() => {
      result.current.selecionarServico(servico);
    });
    act(() => {
      result.current.selecionarHorario('2026-08-03T14:00:00');
    });
    act(() => {
      result.current.voltarParaHorario();
    });

    expect(result.current.state).toEqual({
      etapa: 'horario',
      servicoSelecionado: servico,
    });
  });

  it('voltarParaServico limpa horário e serviço', () => {
    const { result } = renderHook(() => useAgendamentoFlow());

    act(() => {
      result.current.selecionarServico(servico);
    });
    act(() => {
      result.current.selecionarHorario('2026-08-03T14:00:00');
    });
    act(() => {
      result.current.voltarParaServico();
    });

    expect(result.current.state).toEqual({ etapa: 'servico' });
  });
});
