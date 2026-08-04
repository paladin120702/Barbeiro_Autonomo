import { useState } from 'react';
import { keepPreviousData, useQuery } from '@tanstack/react-query';
import { getDisponibilidade } from '../api/agendamentoPublicoApi';
import type { ServicoDTO } from '../types/dto';
import { Carregando, MensagemErro, mensagemErroDe } from './Estados';

function formatarDataISO(dataObj: Date): string {
  const ano = dataObj.getFullYear();
  const mes = String(dataObj.getMonth() + 1).padStart(2, '0');
  const dia = String(dataObj.getDate()).padStart(2, '0');
  return `${ano}-${mes}-${dia}`;
}

function somarDias(dataISO: string, dias: number): string {
  const [ano, mes, dia] = dataISO.split('-').map(Number);
  const dataObj = new Date(ano, mes - 1, dia);
  dataObj.setDate(dataObj.getDate() + dias);
  return formatarDataISO(dataObj);
}

const HOJE = formatarDataISO(new Date());
const DATA_MAXIMA = somarDias(HOJE, 30);

export function EtapaHorario({
  slug,
  servico,
  onSelecionar,
  onVoltar,
}: {
  slug: string;
  servico: ServicoDTO;
  onSelecionar: (dataHoraISO: string) => void;
  onVoltar: () => void;
}) {
  const [data, setData] = useState(HOJE);

  const {
    data: disponibilidade,
    isLoading,
    isError,
    error,
    refetch,
  } = useQuery({
    queryKey: ['disponibilidade', slug, data],
    queryFn: () => getDisponibilidade(slug, data),
    placeholderData: keepPreviousData,
  });

  return (
    <div className="etapa-horario">
      <button type="button" className="botao-voltar" onClick={onVoltar}>
        ← Voltar
      </button>
      <h2>{servico.nome}</h2>
      <label htmlFor="data-agendamento">Data</label>
      <input
        id="data-agendamento"
        type="date"
        value={data}
        min={HOJE}
        max={DATA_MAXIMA}
        onChange={(e) => setData(e.target.value)}
      />

      {isLoading && <Carregando />}

      {isError && (
        <MensagemErro
          mensagem={mensagemErroDe(error)}
          onTentarNovamente={() => refetch()}
        />
      )}

      {!isLoading && !isError && (
        <>
          {(disponibilidade?.horarios.length ?? 0) === 0 ? (
            <p className="sem-horarios">Nenhum horário disponível neste dia</p>
          ) : (
            <div className="grid-horarios">
              {disponibilidade?.horarios.map((horario) => (
                <button
                  key={horario}
                  type="button"
                  className="botao-horario"
                  onClick={() => onSelecionar(`${data}T${horario}:00`)}
                >
                  {horario}
                </button>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}
