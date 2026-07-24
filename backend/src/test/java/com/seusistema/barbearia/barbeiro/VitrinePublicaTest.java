package com.seusistema.barbearia.barbeiro;

import static org.assertj.core.api.Assertions.assertThat;

import com.seusistema.barbearia.IntegrationTestBase;
import com.seusistema.barbearia.barbeiro.dto.CriarBarbeiroRequest;
import com.seusistema.barbearia.servico.Servico;
import com.seusistema.barbearia.servico.ServicoRepository;
import com.seusistema.barbearia.servico.dto.ServicoDTO;
import java.math.BigDecimal;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

class VitrinePublicaTest extends IntegrationTestBase {

    @Autowired TestRestTemplate rest;
    @Autowired BarbeiroService barbeiroService;
    @Autowired BarbeiroRepository barbeiroRepository;
    @Autowired ServicoRepository servicoRepository;

    Barbeiro ativo;
    Barbeiro inativo;

    @BeforeEach
    void setUp() {
        ativo = barbeiroService.criar(new CriarBarbeiroRequest("João Barbeiro", "joao@b.com", "senha123", "joao"));

        inativo = barbeiroService.criar(new CriarBarbeiroRequest("Pedro Barbeiro", "pedro@b.com", "senha123", "pedro"));
        inativo.setStatusConta(StatusConta.INATIVO);
        barbeiroRepository.save(inativo);

        Servico corte = new Servico();
        corte.setBarbeiroId(ativo.getId());
        corte.setNome("Corte");
        corte.setPreco(new BigDecimal("50.00"));
        corte.setDuracaoMinutos(30);
        servicoRepository.save(corte);

        Servico barba = new Servico();
        barba.setBarbeiroId(ativo.getId());
        barba.setNome("Barba");
        barba.setPreco(new BigDecimal("30.00"));
        barba.setDuracaoMinutos(20);
        servicoRepository.save(barba);
    }

    @Test
    void buscarBarbeiroAtivoRetorna200SemDadosSensiveis() {
        ResponseEntity<String> resp = rest.getForEntity("/api/v1/public/joao", String.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(resp.getBody()).contains("João Barbeiro");
        assertThat(resp.getBody()).doesNotContain("senha");
        assertThat(resp.getBody()).doesNotContain("email");
    }

    @Test
    void buscarBarbeiroInexistenteRetorna404() {
        ResponseEntity<Map> resp = rest.getForEntity("/api/v1/public/nao-existe", Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(resp.getBody()).containsEntry("erro", "Barbeiro não encontrado");
    }

    @Test
    void buscarBarbeiroInativoRetorna404() {
        ResponseEntity<Map> resp = rest.getForEntity("/api/v1/public/pedro", Map.class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
    }

    @Test
    void listarServicosDoBarbeiroAtivoRetornaOrdenadoPorNome() {
        ResponseEntity<ServicoDTO[]> resp = rest.getForEntity("/api/v1/public/joao/servicos", ServicoDTO[].class);
        assertThat(resp.getStatusCode()).isEqualTo(HttpStatus.OK);
        ServicoDTO[] servicos = resp.getBody();
        assertThat(servicos).hasSize(2);
        assertThat(servicos[0].nome()).isEqualTo("Barba");
        assertThat(servicos[1].nome()).isEqualTo("Corte");
    }
}
