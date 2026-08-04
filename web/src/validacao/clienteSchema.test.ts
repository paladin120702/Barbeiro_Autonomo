import { describe, expect, it } from 'vitest';
import { clienteSchema } from './clienteSchema';

describe('clienteSchema', () => {
  it('aceita telefone com máscara (parênteses e hífen) e normaliza para 11 dígitos', () => {
    const result = clienteSchema.safeParse({
      nome: 'João Silva',
      telefone: '(11) 98765-4321',
    });

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.telefone).toBe('11987654321');
    }
  });

  it('aceita telefone com espaço (10 dígitos)', () => {
    const result = clienteSchema.safeParse({
      nome: 'João Silva',
      telefone: '11 3456-7890',
    });

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.telefone).toBe('1134567890');
    }
  });

  it('rejeita telefone com 9 dígitos', () => {
    const result = clienteSchema.safeParse({
      nome: 'João Silva',
      telefone: '987654321',
    });

    expect(result.success).toBe(false);
  });

  it('rejeita telefone com +55 (13 dígitos)', () => {
    const result = clienteSchema.safeParse({
      nome: 'João Silva',
      telefone: '+5511987654321',
    });

    expect(result.success).toBe(false);
  });

  it('rejeita nome vazio com mensagem "Nome é obrigatório"', () => {
    const result = clienteSchema.safeParse({
      nome: '',
      telefone: '11987654321',
    });

    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0]?.message).toBe('Nome é obrigatório');
    }
  });
});
