import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import './App.css';
import { getBarbeiro, criarAgendamento } from './api/agendamentoPublicoApi';
import { ApiError } from './api/httpClient';
import { useAgendamentoFlow } from './hooks/useAgendamentoFlow';
import { EtapaServico } from './components/EtapaServico';
import { EtapaHorario } from './components/EtapaHorario';
import { EtapaIdentificacao } from './components/EtapaIdentificacao';
import { TelaSucesso } from './components/TelaSucesso';
import { Carregando, MensagemErro, mensagemErroDe } from './components/Estados';
import type { AgendamentoCriadoDTO, CriarAgendamentoRequest, ServicoDTO } from './types/dto';
import type { ClienteFormData } from './validacao/clienteSchema';

function TelaNaoEncontrada() {
  return (
    <div className="estado estado-nao-encontrada">
      <h1>Barbearia não encontrada</h1>
    </div>
  );
}

function App() {
  const slug = window.location.pathname.replaceAll('/', '');
  const queryClient = useQueryClient();

  const {
    state,
    selecionarServico,
    selecionarHorario,
    identificar,
    concluir,
    voltarParaHorario,
    voltarParaServico,
  } = useAgendamentoFlow();

  const [agendamentoCriado, setAgendamentoCriado] = useState<
    AgendamentoCriadoDTO | undefined
  >(undefined);
  const [erroConflito, setErroConflito] = useState(false);
  const [erroEnvio, setErroEnvio] = useState<string | undefined>(undefined);

  const barbeiroQuery = useQuery({
    queryKey: ['barbeiro', slug],
    queryFn: () => getBarbeiro(slug),
    enabled: Boolean(slug),
  });

  const mutation = useMutation({
    mutationFn: (req: CriarAgendamentoRequest) => criarAgendamento(slug, req),
    onSuccess: (dto) => {
      setAgendamentoCriado(dto);
      concluir();
    },
    onError: (error) => {
      const horarioIndisponivel =
        error instanceof ApiError &&
        (error.status === 409 ||
          (error.status === 400 && error.body.erro === 'Horário indisponível'));
      if (horarioIndisponivel) {
        voltarParaHorario();
        queryClient.invalidateQueries({ queryKey: ['disponibilidade'] });
        setErroConflito(true);
        return;
      }
      if (error instanceof ApiError && error.status === 429) {
        setErroEnvio(error.body.erro);
        return;
      }
      setErroEnvio('Erro inesperado. Tente novamente.');
    },
  });

  const handleSelecionarServico = (servico: ServicoDTO) => {
    setErroConflito(false);
    selecionarServico(servico);
  };

  const handleSelecionarHorario = (dataHoraISO: string) => {
    setErroConflito(false);
    setErroEnvio(undefined);
    selecionarHorario(dataHoraISO);
  };

  const handleConfirmar = (dados: ClienteFormData) => {
    setErroEnvio(undefined);
    identificar(dados.nome, dados.telefone);
    mutation.mutate({
      servicoId: state.servicoSelecionado!.id,
      dataHora: state.dataHorarioSelecionado!,
      nomeCliente: dados.nome,
      telefoneCliente: dados.telefone,
    });
  };

  if (!slug) {
    return <TelaNaoEncontrada />;
  }

  if (barbeiroQuery.isLoading) {
    return <Carregando />;
  }

  if (barbeiroQuery.isError) {
    if (barbeiroQuery.error instanceof ApiError && barbeiroQuery.error.status === 404) {
      return <TelaNaoEncontrada />;
    }
    return (
      <MensagemErro
        mensagem={mensagemErroDe(barbeiroQuery.error)}
        onTentarNovamente={() => barbeiroQuery.refetch()}
      />
    );
  }

  return (
    <div className="app">
      <header className="app-header">
        <h1>{barbeiroQuery.data?.nome}</h1>
      </header>
      <main>
        {state.etapa === 'servico' && (
          <EtapaServico slug={slug} onSelecionar={handleSelecionarServico} />
        )}

        {state.etapa === 'horario' && (
          <>
            {erroConflito && (
              <div className="banner-conflito" role="alert">
                Esse horário acabou de ser reservado. Escolha outro.
              </div>
            )}
            <EtapaHorario
              slug={slug}
              servico={state.servicoSelecionado!}
              onSelecionar={handleSelecionarHorario}
              onVoltar={voltarParaServico}
            />
          </>
        )}

        {state.etapa === 'identificacao' && (
          <EtapaIdentificacao
            onConfirmar={handleConfirmar}
            onVoltar={voltarParaHorario}
            erroEnvio={erroEnvio}
            enviando={mutation.isPending}
          />
        )}

        {state.etapa === 'sucesso' && agendamentoCriado && (
          <TelaSucesso agendamento={agendamentoCriado} />
        )}
      </main>
    </div>
  );
}

export default App;
