import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { getServicos } from './agendamentoPublicoApi';
import { ApiError } from './httpClient';
import type { ServicoDTO } from '../types/dto';

describe('agendamentoPublicoApi', () => {
  const fetchMock = vi.fn();

  beforeEach(() => {
    vi.stubGlobal('fetch', fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    fetchMock.mockReset();
  });

  it('getServicos monta a URL correta e retorna JSON tipado', async () => {
    const servicos: ServicoDTO[] = [
      { id: 1, nome: 'Corte', preco: 50, duracaoMinutos: 30 },
    ];
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(servicos), { status: 200 }),
    );

    const result = await getServicos('joao');

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url] = fetchMock.mock.calls[0];
    expect(String(url)).toContain('/api/v1/public/joao/servicos');
    expect(result).toEqual(servicos);
  });

  it('lança ApiError com status 409 e body.erro preservado', async () => {
    const errorBody = { erro: 'Horário indisponível' };
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(errorBody), { status: 409 }),
    );

    const promise = getServicos('joao');

    await expect(promise).rejects.toBeInstanceOf(ApiError);
    await expect(promise).rejects.toMatchObject({
      status: 409,
      body: errorBody,
    });
  });

  it('lança ApiError com status 429 e body.erro preservado', async () => {
    const errorBody = { erro: 'Muitas requisições, tente novamente mais tarde' };
    fetchMock.mockResolvedValueOnce(
      new Response(JSON.stringify(errorBody), { status: 429 }),
    );

    const promise = getServicos('joao');

    await expect(promise).rejects.toBeInstanceOf(ApiError);
    await expect(promise).rejects.toMatchObject({
      status: 429,
      body: errorBody,
    });
  });
});
