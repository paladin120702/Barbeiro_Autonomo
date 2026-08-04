import { z } from 'zod';

// Espelha TelefoneBR do backend (Task 10): mantém apenas dígitos.
export const normalizarTelefone = (t: string) => t.replace(/\D/g, '');

export const clienteSchema = z.object({
  nome: z.string().trim().min(1, 'Nome é obrigatório').max(120, 'Nome muito longo'),
  telefone: z
    .string()
    .transform(normalizarTelefone)
    .refine(
      (t) => t.length === 10 || t.length === 11,
      'Telefone inválido — use DDD + número',
    ),
});

export type ClienteFormData = z.infer<typeof clienteSchema>;
