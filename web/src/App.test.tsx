import { beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactElement } from 'react';
import App from './App';
import {
  criarAgendamento,
  getBarbeiro,
  getDisponibilidade,
  getServicos,
} from './api/agendamentoPublicoApi';
import { ApiError } from './api/httpClient';
import type {
  AgendamentoCriadoDTO,
  BarbeiroPublicoDTO,
  DisponibilidadeDTO,
  ServicoDTO,
} from './types/dto';

vi.mock('./api/agendamentoPublicoApi');

function renderComQuery(ui: ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>,
  );
}

function definirPathname(pathname: string) {
  Object.defineProperty(window, 'location', {
    value: { ...window.location, pathname },
    writable: true,
    configurable: true,
  });
}

const barbeiro: BarbeiroPublicoDTO = {
  nome: 'João Barbeiro',
  slug: 'joao',
  telefone: null,
};

const servicos: ServicoDTO[] = [
  { id: 1, nome: 'Corte', preco: 50, duracaoMinutos: 30 },
];

function disponibilidadeDe(data: string, horarios: string[]): DisponibilidadeDTO {
  return { data, horarios };
}

describe('App', () => {
  beforeEach(() => {
    vi.mocked(getBarbeiro).mockReset();
    vi.mocked(getServicos).mockReset();
    vi.mocked(getDisponibilidade).mockReset();
    vi.mocked(criarAgendamento).mockReset();
  });

  it('slug vazio mostra tela "Barbearia não encontrada" sem chamar a API', async () => {
    definirPathname('/');

    renderComQuery(<App />);

    expect(
      await screen.findByText('Barbearia não encontrada'),
    ).toBeInTheDocument();
    expect(getBarbeiro).not.toHaveBeenCalled();
  });

  it('getBarbeiro retornando 404 mostra tela "Barbearia não encontrada"', async () => {
    definirPathname('/joao');
    vi.mocked(getBarbeiro).mockRejectedValue(
      new ApiError(404, { erro: 'não encontrado' }),
    );

    renderComQuery(<App />);

    expect(
      await screen.findByText('Barbearia não encontrada'),
    ).toBeInTheDocument();
  });

  it('caminho feliz: seleciona serviço, horário, identifica e chega à tela de sucesso', async () => {
    definirPathname('/joao');
    vi.mocked(getBarbeiro).mockResolvedValue(barbeiro);
    vi.mocked(getServicos).mockResolvedValue(servicos);
    vi.mocked(getDisponibilidade).mockImplementation((_slug, data) =>
      Promise.resolve(disponibilidadeDe(data, ['09:00'])),
    );
    const agendamentoCriado: AgendamentoCriadoDTO = {
      id: 1,
      servicoNome: 'Corte',
      dataHoraInicio: '2026-08-03T09:00:00',
      nomeCliente: 'João Silva',
    };
    vi.mocked(criarAgendamento).mockResolvedValue(agendamentoCriado);
    const user = userEvent.setup();

    renderComQuery(<App />);

    expect(await screen.findByText('João Barbeiro')).toBeInTheDocument();

    const cardCorte = await screen.findByText('Corte');
    await user.click(cardCorte);

    const botao0900 = await screen.findByText('09:00');
    await user.click(botao0900);

    await user.type(await screen.findByLabelText(/nome/i), 'João Silva');
    await user.type(screen.getByLabelText(/telefone/i), '(11) 98888-7777');
    await user.click(screen.getByRole('button', { name: /confirmar/i }));

    expect(await screen.findByText('Agendamento confirmado!')).toBeInTheDocument();
    expect(screen.getByText('Corte')).toBeInTheDocument();
    expect(screen.getByText('João Silva')).toBeInTheDocument();
    expect(criarAgendamento).toHaveBeenCalledWith('joao', {
      servicoId: 1,
      dataHora: expect.stringContaining('T09:00:00'),
      nomeCliente: 'João Silva',
      telefoneCliente: '11988887777',
    });
  });

  it('conflito 409 ao confirmar volta para etapa horário, mostra banner e refaz a busca de disponibilidade', async () => {
    definirPathname('/joao');
    vi.mocked(getBarbeiro).mockResolvedValue(barbeiro);
    vi.mocked(getServicos).mockResolvedValue(servicos);
    vi.mocked(getDisponibilidade).mockImplementation((_slug, data) =>
      Promise.resolve(disponibilidadeDe(data, ['09:00'])),
    );
    vi.mocked(criarAgendamento).mockRejectedValue(
      new ApiError(409, { erro: 'conflito' }),
    );
    const user = userEvent.setup();

    renderComQuery(<App />);

    await screen.findByText('João Barbeiro');

    const cardCorte = await screen.findByText('Corte');
    await user.click(cardCorte);

    const botao0900 = await screen.findByText('09:00');
    await user.click(botao0900);

    const chamadasAntes = vi.mocked(getDisponibilidade).mock.calls.length;

    await user.type(await screen.findByLabelText(/nome/i), 'João Silva');
    await user.type(screen.getByLabelText(/telefone/i), '(11) 98888-7777');
    await user.click(screen.getByRole('button', { name: /confirmar/i }));

    expect(
      await screen.findByText('Esse horário acabou de ser reservado. Escolha outro.'),
    ).toBeInTheDocument();

    // etapa horário está de volta: horários visíveis de novo
    expect(await screen.findByText('09:00')).toBeInTheDocument();

    await waitFor(() => {
      expect(vi.mocked(getDisponibilidade).mock.calls.length).toBeGreaterThan(
        chamadasAntes,
      );
    });
  });

  it('horário indisponível (400, checagem de aplicação) ao confirmar volta para etapa horário, mostra banner e refaz a busca de disponibilidade', async () => {
    definirPathname('/joao');
    vi.mocked(getBarbeiro).mockResolvedValue(barbeiro);
    vi.mocked(getServicos).mockResolvedValue(servicos);
    vi.mocked(getDisponibilidade).mockImplementation((_slug, data) =>
      Promise.resolve(disponibilidadeDe(data, ['09:00'])),
    );
    vi.mocked(criarAgendamento).mockRejectedValue(
      new ApiError(400, { erro: 'Horário indisponível' }),
    );
    const user = userEvent.setup();

    renderComQuery(<App />);

    await screen.findByText('João Barbeiro');

    const cardCorte = await screen.findByText('Corte');
    await user.click(cardCorte);

    const botao0900 = await screen.findByText('09:00');
    await user.click(botao0900);

    const chamadasAntes = vi.mocked(getDisponibilidade).mock.calls.length;

    await user.type(await screen.findByLabelText(/nome/i), 'João Silva');
    await user.type(screen.getByLabelText(/telefone/i), '(11) 98888-7777');
    await user.click(screen.getByRole('button', { name: /confirmar/i }));

    expect(
      await screen.findByText('Esse horário acabou de ser reservado. Escolha outro.'),
    ).toBeInTheDocument();

    expect(await screen.findByText('09:00')).toBeInTheDocument();

    await waitFor(() => {
      expect(vi.mocked(getDisponibilidade).mock.calls.length).toBeGreaterThan(
        chamadasAntes,
      );
    });
  });

  it('erro 400 de outra causa (não "Horário indisponível") permanece na identificação com erro genérico', async () => {
    definirPathname('/joao');
    vi.mocked(getBarbeiro).mockResolvedValue(barbeiro);
    vi.mocked(getServicos).mockResolvedValue(servicos);
    vi.mocked(getDisponibilidade).mockImplementation((_slug, data) =>
      Promise.resolve(disponibilidadeDe(data, ['09:00'])),
    );
    vi.mocked(criarAgendamento).mockRejectedValue(
      new ApiError(400, { erro: 'Telefone inválido' }),
    );
    const user = userEvent.setup();

    renderComQuery(<App />);

    await screen.findByText('João Barbeiro');

    const cardCorte = await screen.findByText('Corte');
    await user.click(cardCorte);

    const botao0900 = await screen.findByText('09:00');
    await user.click(botao0900);

    await user.type(await screen.findByLabelText(/nome/i), 'João Silva');
    await user.type(screen.getByLabelText(/telefone/i), '(11) 98888-7777');
    await user.click(screen.getByRole('button', { name: /confirmar/i }));

    expect(
      await screen.findByText('Erro inesperado. Tente novamente.'),
    ).toBeInTheDocument();
    expect(screen.getByLabelText(/nome/i)).toBeInTheDocument();
  });
});
