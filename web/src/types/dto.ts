// Espelham os DTOs públicos do backend (Tasks 6, 9, 10).

export interface BarbeiroPublicoDTO {
  nome: string;
  slug: string;
  telefone: string | null;
}

export interface ServicoDTO {
  id: number;
  nome: string;
  preco: number;
  duracaoMinutos: number;
}

export interface DisponibilidadeDTO {
  data: string;
  horarios: string[];
}

export interface CriarAgendamentoRequest {
  servicoId: number;
  dataHora: string;
  nomeCliente: string;
  telefoneCliente: string;
}

export interface AgendamentoCriadoDTO {
  id: number;
  servicoNome: string;
  dataHoraInicio: string;
  nomeCliente: string;
}

export interface ErroAPI {
  erro: string;
  campos?: Record<string, string>;
}
