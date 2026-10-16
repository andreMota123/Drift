# Projeto Drift

Melhorias no **CutWire Drift**, o editor de vídeo gratuito e de código aberto (GPL-3.0) feito em C++ com Qt 6 e FFmpeg. Este é o projeto que vamos melhorar a cada dia.

- Projeto oficial: https://github.com/CutWire-Studios/Drift
- Nosso fork: https://github.com/andreMota123/Drift
- Site: https://cutwire.org/drift/

## O que há nesta pasta

| Caminho | O que é |
|---|---|
| `Drift-link/` | Cópia do código fonte do Drift, com git. É aqui que as alterações são feitas e compiladas. |
| `Drift-link/flatpak/` | Manifesto do Flatpak, repositório local com os pacotes gerados e caches de compilação. |
| `docs/` | Documentação do que foi feito, como foi feito e como repetir. |
| `DIARIO.md` | Registro dia a dia do trabalho. |

A documentação também está no GitHub, na ramificação `notas-projeto` do fork.

## Estado atual (13 de setembro de 2026)

- **Função Link** implementada: vincula um vídeo a um áudio de outra origem, ou religa o áudio original que foi desvinculado. Atalho Ctrl+Shift+L.
- **Função Juntar em um só vídeo** implementada sobre o main do projeto: seleciona clipes de qualquer faixa e os renderiza num único clipe de vídeo. Atalho Ctrl+Shift+J. Compilada e testada, inclusive a renderização real. Veja `docs/06-funcao-juntar.md`.
- **Interface em português** corrigida no pacote Flatpak, e as 27 frases que faltavam foram traduzidas.
- A versão modificada está **instalada e em uso** na máquina, substituindo a cópia do Flathub.
- Um **pull request** foi aberto no projeto oficial: https://github.com/CutWire-Studios/Drift/pull/200. Ainda precisa de ajustes antes de ser aceito. Veja `docs/04-pull-request.md`.

- **Clipe composto** ao estilo do CapCut, no branch `compound-clips`: contêiner que guarda os clipes originais, abre com dois cliques para editar, re-renderiza ao voltar e pode ser dissolvido. Atalhos Alt+G e Ctrl+Shift+G. Compilado e testado. Veja `docs/07-clipe-composto.md`.

## Documentos

1. `docs/01-funcao-link.md`: o que a função faz, como foi desenhada, quais arquivos mudaram e como testar.
2. `docs/02-traducao.md`: por que a interface aparecia em inglês e como foi corrigido.
3. `docs/03-compilar-instalar.md`: como compilar, instalar, rodar os testes e voltar para a versão oficial.
4. `docs/04-pull-request.md`: estado do envio ao projeto oficial, regras do projeto e o que falta.
5. `docs/05-ambiente.md`: ajustes feitos no sistema para o Drift funcionar (permissões de disco, driver NVIDIA no Flatpak).
6. `docs/06-funcao-juntar.md`: a função que transforma a seleção em um só vídeo.
7. `docs/07-clipe-composto.md`: o clipe composto editável.
8. `docs/08-estado-e-envio.md`: o que está pronto, onde está no GitHub e como enviar ao projeto oficial.
9. `docs/09-comparativo-capcut.md`: funções e aparência do Drift comparadas com o CapCut, e a ordem de trabalho para aproximar os dois.
11. `docs/11-ia-local.md`: a IA que roda neste PC (Ollama e ComfyUI), o que dá para levar ao Drift e em que ordem.
12. `docs/12-assistente.md`: o assistente dentro do Drift, como funciona, segurança, testes e limites.
13. `docs/13-ponte-claude.md`: escolher entre a IA local e o Claude, na conversa e dentro do Drift.
14. `docs/14-legendas-ia.md`: corrigir e traduzir legendas com a IA local.
15. `docs/15-cortes-curtos.md`: transformar um vídeo longo em cortes verticais com a IA local.
16. `docs/16-enchimento-e-repeticoes.md`: tirar tomadas repetidas, falsos começos, enchimento e comentários.
17. `docs/17-aprimorar-qualidade.md`: aprimorar vídeo de baixa resolução com IA local.
18. `docs/18-estado-2026-10-15.md`: **estado geral e como retomar** (comece por aqui numa conversa nova).
19. `docs/19-maquiagem.md`: filtro de maquiagem ao estilo do Instagram: o que o Drift já tem, o que existe no GitHub e o plano.

## Como usar a função Link no Drift

1. Clique no primeiro clipe na timeline.
2. Segure **Shift** e clique no segundo clipe.
3. Pressione **Ctrl+Shift+L**, ou clique no ícone de corrente fechada na barra da timeline, ou use o botão direito e "Vincular".

Os dois passam a se mover, cortar, selecionar e apagar juntos. Cada um mantém a própria duração e cortes. Para separar de novo: Ctrl+Shift+U.
