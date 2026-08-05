import type { AgendamentoCriadoDTO } from '../types/dto';

export function TelaSucesso({ agendamento }: { agendamento: AgendamentoCriadoDTO }) {
  const dataHora = new Date(agendamento.dataHoraInicio);
  const dataFormatada = dataHora.toLocaleDateString('pt-BR');
  const horaFormatada = dataHora.toLocaleTimeString('pt-BR', {
    hour: '2-digit',
    minute: '2-digit',
  });

  return (
    <div className="tela-sucesso">
      <h2>Agendamento confirmado!</h2>
      <p className="tela-sucesso-servico">{agendamento.servicoNome}</p>
      <p className="tela-sucesso-data-hora">
        {dataFormatada} às {horaFormatada}
      </p>
      <p className="tela-sucesso-cliente">{agendamento.nomeCliente}</p>
    </div>
  );
}
