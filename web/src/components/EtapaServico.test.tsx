import { beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactElement } from 'react';
import { EtapaServico } from './EtapaServico';
import { getServicos } from '../api/agendamentoPublicoApi';
import { ApiError } from '../api/httpClient';
import type { ServicoDTO } from '../types/dto';

vi.mock('../api/agendamentoPublicoApi');

function renderComQuery(ui: ReactElement) {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return render(
    <QueryClientProvider client={queryClient}>{ui}</QueryClientProvider>,
  );
}

describe('EtapaServico', () => {
  const servicosMock: ServicoDTO[] = [
    { id: 1, nome: 'Corte', preco: 50, duracaoMinutos: 30 },
    { id: 2, nome: 'Barba', preco: 30, duracaoMinutos: 20 },
  ];

  beforeEach(() => {
    vi.mocked(getServicos).mockReset();
  });

  it('renderiza os serviços com preço formatado em BRL', async () => {
    vi.mocked(getServicos).mockResolvedValueOnce(servicosMock);

    renderComQuery(<EtapaServico slug="joao" onSelecionar={vi.fn()} />);

    expect(await screen.findByText('Corte')).toBeInTheDocument();
    expect(screen.getByText('R$ 50,00')).toBeInTheDocument();
    expect(screen.getByText('Barba')).toBeInTheDocument();
    expect(screen.getByText('R$ 30,00')).toBeInTheDocument();
  });

  it('clique em um serviço dispara onSelecionar com o DTO correspondente', async () => {
    vi.mocked(getServicos).mockResolvedValueOnce(servicosMock);
    const onSelecionar = vi.fn();
    const user = userEvent.setup();

    renderComQuery(<EtapaServico slug="joao" onSelecionar={onSelecionar} />);

    const cardCorte = await screen.findByText('Corte');
    await user.click(cardCorte);

    expect(onSelecionar).toHaveBeenCalledTimes(1);
    expect(onSelecionar).toHaveBeenCalledWith(servicosMock[0]);
  });

  it('API rejeitando exibe MensagemErro', async () => {
    vi.mocked(getServicos).mockRejectedValueOnce(
      new ApiError(500, { erro: 'Falha ao buscar serviços' }),
    );

    renderComQuery(<EtapaServico slug="joao" onSelecionar={vi.fn()} />);

    expect(await screen.findByText('Falha ao buscar serviços')).toBeInTheDocument();
  });
});
