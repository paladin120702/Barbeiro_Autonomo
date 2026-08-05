import { useState } from 'react';
import { clienteSchema, type ClienteFormData } from '../validacao/clienteSchema';

export function EtapaIdentificacao({
  onConfirmar,
  onVoltar,
  erroEnvio,
  enviando,
}: {
  onConfirmar: (dados: ClienteFormData) => void;
  onVoltar: () => void;
  erroEnvio?: string;
  enviando: boolean;
}) {
  const [nome, setNome] = useState('');
  const [telefone, setTelefone] = useState('');
  const [erros, setErros] = useState<{ nome?: string; telefone?: string }>({});

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    const resultado = clienteSchema.safeParse({ nome, telefone });

    if (!resultado.success) {
      const novosErros: { nome?: string; telefone?: string } = {};
      for (const issue of resultado.error.issues) {
        const campo = issue.path[0];
        if (campo === 'nome' && !novosErros.nome) novosErros.nome = issue.message;
        if (campo === 'telefone' && !novosErros.telefone)
          novosErros.telefone = issue.message;
      }
      setErros(novosErros);
      return;
    }

    setErros({});
    onConfirmar(resultado.data);
  };

  return (
    <form className="etapa-identificacao" onSubmit={handleSubmit}>
      <button type="button" className="botao-voltar" onClick={onVoltar}>
        ← Voltar
      </button>

      <label htmlFor="nome-cliente">Nome</label>
      <input
        id="nome-cliente"
        type="text"
        value={nome}
        onChange={(e) => setNome(e.target.value)}
      />
      {erros.nome && (
        <p className="erro-campo" role="alert">
          {erros.nome}
        </p>
      )}

      <label htmlFor="telefone-cliente">Telefone</label>
      <input
        id="telefone-cliente"
        type="tel"
        value={telefone}
        onChange={(e) => setTelefone(e.target.value)}
      />
      {erros.telefone && (
        <p className="erro-campo" role="alert">
          {erros.telefone}
        </p>
      )}

      {erroEnvio && (
        <p className="erro-envio" role="alert">
          {erroEnvio}
        </p>
      )}

      <button type="submit" disabled={enviando}>
        Confirmar agendamento
      </button>
    </form>
  );
}
