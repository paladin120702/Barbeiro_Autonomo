import { ApiError } from '../api/httpClient';

export function Carregando() {
  return (
    <div className="estado estado-carregando" role="status">
      <span className="spinner" aria-hidden="true" />
      <p>Carregando...</p>
    </div>
  );
}

export function MensagemErro({
  mensagem,
  onTentarNovamente,
}: {
  mensagem: string;
  onTentarNovamente?: () => void;
}) {
  return (
    <div className="estado estado-erro" role="alert">
      <p>{mensagem}</p>
      {onTentarNovamente && (
        <button type="button" onClick={onTentarNovamente}>
          Tentar novamente
        </button>
      )}
    </div>
  );
}

// Extrai a mensagem amigável de um erro capturado pelo useQuery.
// getServicos/getDisponibilidade lançam ApiError (Task 15) com body.erro
// já em português; qualquer outro erro cai num texto genérico.
export function mensagemErroDe(error: unknown): string {
  if (error instanceof ApiError) {
    return error.body.erro;
  }
  return 'Erro inesperado. Tente novamente.';
}
