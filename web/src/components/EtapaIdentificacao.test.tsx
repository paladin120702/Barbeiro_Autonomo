import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { EtapaIdentificacao } from './EtapaIdentificacao';

describe('EtapaIdentificacao', () => {
  it('telefone inválido mostra mensagem de erro e não chama onConfirmar', async () => {
    const onConfirmar = vi.fn();
    const user = userEvent.setup();

    render(
      <EtapaIdentificacao
        onConfirmar={onConfirmar}
        onVoltar={vi.fn()}
        enviando={false}
      />,
    );

    await user.type(screen.getByLabelText(/nome/i), 'João Silva');
    await user.type(screen.getByLabelText(/telefone/i), '123');
    await user.click(screen.getByRole('button', { name: /confirmar/i }));

    expect(
      await screen.findByText('Telefone inválido — use DDD + número'),
    ).toBeInTheDocument();
    expect(onConfirmar).not.toHaveBeenCalled();
  });

  it('nome e telefone válidos (com máscara) chamam onConfirmar com telefone normalizado', async () => {
    const onConfirmar = vi.fn();
    const user = userEvent.setup();

    render(
      <EtapaIdentificacao
        onConfirmar={onConfirmar}
        onVoltar={vi.fn()}
        enviando={false}
      />,
    );

    await user.type(screen.getByLabelText(/nome/i), 'João Silva');
    await user.type(screen.getByLabelText(/telefone/i), '(11) 98888-7777');
    await user.click(screen.getByRole('button', { name: /confirmar/i }));

    expect(onConfirmar).toHaveBeenCalledTimes(1);
    expect(onConfirmar).toHaveBeenCalledWith({
      nome: 'João Silva',
      telefone: '11988887777',
    });
  });

  it('enviando=true desabilita o botão de confirmar', () => {
    render(
      <EtapaIdentificacao
        onConfirmar={vi.fn()}
        onVoltar={vi.fn()}
        enviando={true}
      />,
    );

    expect(screen.getByRole('button', { name: /confirmar/i })).toBeDisabled();
  });

  it('erroEnvio fornecido é exibido na tela', () => {
    render(
      <EtapaIdentificacao
        onConfirmar={vi.fn()}
        onVoltar={vi.fn()}
        enviando={false}
        erroEnvio="Muitas tentativas. Aguarde um instante."
      />,
    );

    expect(
      screen.getByText('Muitas tentativas. Aguarde um instante.'),
    ).toBeInTheDocument();
  });

  it('botão de voltar chama onVoltar', async () => {
    const onVoltar = vi.fn();
    const user = userEvent.setup();

    render(
      <EtapaIdentificacao
        onConfirmar={vi.fn()}
        onVoltar={onVoltar}
        enviando={false}
      />,
    );

    await user.click(screen.getByRole('button', { name: /voltar/i }));

    expect(onVoltar).toHaveBeenCalledTimes(1);
  });
});
