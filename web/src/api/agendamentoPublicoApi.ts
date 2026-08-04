import { api } from './httpClient';
import type {
  AgendamentoCriadoDTO,
  BarbeiroPublicoDTO,
  CriarAgendamentoRequest,
  DisponibilidadeDTO,
  ServicoDTO,
} from '../types/dto';

export const getBarbeiro = (slug: string) =>
  api<BarbeiroPublicoDTO>(`/api/v1/public/${slug}`);

export const getServicos = (slug: string) =>
  api<ServicoDTO[]>(`/api/v1/public/${slug}/servicos`);

export const getDisponibilidade = (slug: string, data: string) =>
  api<DisponibilidadeDTO>(`/api/v1/public/${slug}/disponibilidade?data=${data}`);

export const criarAgendamento = (slug: string, req: CriarAgendamentoRequest) =>
  api<AgendamentoCriadoDTO>(`/api/v1/public/${slug}/agendamentos`, {
    method: 'POST',
    body: JSON.stringify(req),
  });
