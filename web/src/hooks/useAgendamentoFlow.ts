import { useState } from 'react';
import type { ServicoDTO } from '../types/dto';

export type Etapa = 'servico' | 'horario' | 'identificacao' | 'sucesso';

export interface AgendamentoFlowState {
  etapa: Etapa;
  servicoSelecionado?: ServicoDTO;
  dataHorarioSelecionado?: string; // ISO datetime "2026-08-03T14:00:00"
  nomeCliente?: string;
  telefoneCliente?: string;
}

export function useAgendamentoFlow() {
  const [state, setState] = useState<AgendamentoFlowState>({ etapa: 'servico' });

  const selecionarServico = (servico: ServicoDTO) => {
    setState((prev) => ({
      ...prev,
      etapa: 'horario',
      servicoSelecionado: servico,
    }));
  };

  const selecionarHorario = (dataHorario: string) => {
    setState((prev) => ({
      ...prev,
      etapa: 'identificacao',
      dataHorarioSelecionado: dataHorario,
    }));
  };

  const identificar = (nome: string, telefone: string) => {
    setState((prev) => ({
      ...prev,
      nomeCliente: nome,
      telefoneCliente: telefone,
    }));
  };

  const concluir = () => {
    setState((prev) => ({
      ...prev,
      etapa: 'sucesso',
    }));
  };

  const voltarParaHorario = () => {
    setState((prev) => ({
      ...prev,
      etapa: 'horario',
      dataHorarioSelecionado: undefined,
    }));
  };

  const voltarParaServico = () => {
    setState((prev) => ({
      ...prev,
      etapa: 'servico',
      servicoSelecionado: undefined,
      dataHorarioSelecionado: undefined,
    }));
  };

  return {
    state,
    selecionarServico,
    selecionarHorario,
    identificar,
    concluir,
    voltarParaHorario,
    voltarParaServico,
  };
}
