import { beforeEach, describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactElement } from 'react';
import { EtapaHorario } from './EtapaHorario';
import { getDisponibilidade } from '../api/agendamentoPublicoApi';
import type { DisponibilidadeDTO, ServicoDTO } from '../types/dto';

vi.mock('../api/agendamentoPublicoApi');

function renderComQuery(ui: ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>,
  );
}

const servico: ServicoDTO = { id: 1, nome: 'Corte', preco: 50, duracaoMinutos: 30 };

function disponibilidadeDe(data: string, horarios: string[]): DisponibilidadeDTO {
  return { data, horarios };
}

describe('EtapaHorario', () => {
  beforeEach(() => {
    vi.mocked(getDisponibilidade).mockReset();
  });

  it('renderiza os botões de horário retornados pela API', async () => {
    vi.mocked(getDisponibilidade).mockResolvedValue(
      disponibilidadeDe('2026-08-04', ['09:00', '10:00']),
    );

    renderComQuery(
      <EtapaHorario
        slug="joao"
        servico={servico}
        onSelecionar={vi.fn()}
        onVoltar={vi.fn()}
      />,
    );

    expect(await screen.findByText('09:00')).toBeInTheDocument();
    expect(screen.getByText('10:00')).toBeInTheDocument();
  });

  it('clique em um horário monta a data-hora ISO com a data selecionada e chama onSelecionar', async () => {
    vi.mocked(getDisponibilidade).mockImplementation((_slug, data) =>
      Promise.resolve(disponibilidadeDe(data, ['09:00', '10:00'])),
    );
    const onSelecionar = vi.fn();
    const user = userEvent.setup();

    renderComQuery(
      <EtapaHorario
        slug="joao"
        servico={servico}
        onSelecionar={onSelecionar}
        onVoltar={vi.fn()}
      />,
    );

    await screen.findByText('09:00');

    const inputData = screen.getByLabelText(/data/i);
    fireEvent.change(inputData, { target: { value: '2026-08-03' } });

    const botao10 = await screen.findByText('10:00');
    await user.click(botao10);

    expect(onSelecionar).toHaveBeenCalledWith('2026-08-03T10:00:00');
  });

  it('dia sem horários disponíveis mostra mensagem de vazio', async () => {
    vi.mocked(getDisponibilidade).mockResolvedValue(
      disponibilidadeDe('2026-08-04', []),
    );

    renderComQuery(
      <EtapaHorario
        slug="joao"
        servico={servico}
        onSelecionar={vi.fn()}
        onVoltar={vi.fn()}
      />,
    );

    expect(
      await screen.findByText('Nenhum horário disponível neste dia'),
    ).toBeInTheDocument();
  });

  it('trocar a data refaz a query da disponibilidade com a nova data', async () => {
    vi.mocked(getDisponibilidade).mockImplementation((_slug, data) =>
      Promise.resolve(disponibilidadeDe(data, ['09:00'])),
    );

    renderComQuery(
      <EtapaHorario
        slug="joao"
        servico={servico}
        onSelecionar={vi.fn()}
        onVoltar={vi.fn()}
      />,
    );

    await screen.findByText('09:00');

    const inputData = screen.getByLabelText(/data/i);
    fireEvent.change(inputData, { target: { value: '2026-08-05' } });

    await waitFor(() => {
      expect(getDisponibilidade).toHaveBeenCalledWith('joao', '2026-08-05');
    });
  });
});
