import { useQuery } from '@tanstack/react-query';
import { getServicos } from '../api/agendamentoPublicoApi';
import type { ServicoDTO } from '../types/dto';
import { Carregando, MensagemErro, mensagemErroDe } from './Estados';

const formatadorPreco = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
});

export function EtapaServico({
  slug,
  onSelecionar,
}: {
  slug: string;
  onSelecionar: (servico: ServicoDTO) => void;
}) {
  const { data: servicos, isLoading, isError, error, refetch } = useQuery({
    queryKey: ['servicos', slug],
    queryFn: () => getServicos(slug),
  });

  if (isLoading) {
    return <Carregando />;
  }

  if (isError) {
    return (
      <MensagemErro
        mensagem={mensagemErroDe(error)}
        onTentarNovamente={() => refetch()}
      />
    );
  }

  return (
    <div className="lista-servicos">
      {(servicos ?? []).map((servico) => (
        <button
          key={servico.id}
          type="button"
          className="card-servico"
          onClick={() => onSelecionar(servico)}
        >
          <span className="card-servico-nome">{servico.nome}</span>
          <span className="card-servico-preco">
            {formatadorPreco.format(servico.preco)}
          </span>
          <span className="card-servico-duracao">
            {servico.duracaoMinutos} min
          </span>
        </button>
      ))}
    </div>
  );
}
