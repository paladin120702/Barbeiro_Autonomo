import type { ErroAPI } from '../types/dto';

export class ApiError extends Error {
  status: number;
  body: ErroAPI;

  // Sem parameter properties (`constructor(public status: number, ...)`):
  // o tsconfig gerado pelo scaffold (Vite 8 / TS 6) tem `erasableSyntaxOnly`,
  // que rejeita essa sintaxe por exigir emissão de código além da simples
  // remoção de tipos. Campos declarados + atribuição no corpo têm o mesmo
  // efeito e são compatíveis.
  constructor(status: number, body: ErroAPI) {
    super(body.erro);
    this.status = status;
    this.body = body;
  }
}

const BASE_URL = import.meta.env.VITE_API_URL ?? '';

export async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${BASE_URL}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...init,
  });
  if (!response.ok) {
    // Checar a CHAVE `erro`, não a parseabilidade: o corpo de erro padrão do Boot
    // ({"timestamp","status","error","path"}) é JSON válido e sobrescreveria o
    // fallback, deixando body.erro undefined. O backend tem catch-all garantindo
    // `erro` em toda resposta tratada, mas o guard não depende disso.
    let body: ErroAPI = { erro: 'Erro inesperado. Tente novamente.' };
    try {
      const json = await response.json();
      if (json && typeof json.erro === 'string') body = json;
    } catch {
      /* corpo não-JSON */
    }
    throw new ApiError(response.status, body);
  }
  return response.json() as Promise<T>;
}
