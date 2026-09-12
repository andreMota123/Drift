# Diário do projeto

Registro do que foi feito em cada dia. O mais recente fica no topo.

## 2026-09-13

**Pull request #200.** Verificado: está com conflito, porque o main do projeto avançou 137 commits desde a 0.5.1. O main já traz a correção do manifesto de tradução, então ela sai do PR. A função Link foi reaplicada limpa sobre o main no branch `link-clips-v2`, com as frases novas nos 10 catálogos de tradução na ordem que o `lupdate` gera. Lidas as regras de contribuição: uma mudança por PR, Conventional Commits, catálogos atualizados, e mensagem de commit e descrição do PR escritas por pessoa, sem rodapé de coautoria de IA. Pendente: Andre escrever a mensagem do commit.

**Nova função: Juntar em um só vídeo** (Ctrl+Shift+J). Seleciona clipes em qualquer faixa e os transforma num único clipe de vídeo, renderizando com o exportador interno do Drift num arquivo MP4 na pasta de mídia do projeto. Implementada sobre o main, no mesmo branch, com helper puro no núcleo, ação no controlador, botão na barra, itens de menu, comando `combine_clips` para o agente, sete frases traduzidas e dois testes. Detalhes em `docs/06-funcao-juntar.md`.

**Compilação sobre o main.** O main compila a biblioteca Skia a partir do fonte, o que leva bem mais tempo. Duas tentativas foram derrubadas: uma pelo encerramento da sessão, outra por usar uma pasta temporária que o sandbox do construtor não enxerga. A compilação passou a rodar desacoplada da sessão, com estado em `~/.cache/drift-build/`, fora do repositório. Terceira tentativa compilou. Testes: núcleo e editor passaram; o teste de renderização passou com GPU pela Wayland. A build nova (main + Link + Juntar) foi exportada para o repositório local nos ramos `master` e `stable`, e a build 0.5.1 ficou guardada como ramo `v051`. A instalação acontece assim que o Drift for fechado.

**Clipe composto.** O Andre mostrou como o CapCut faz: "Criar clipe composto (subprojeto)" cria um contêiner que guarda os clipes originais, e dois cliques abrem o conteúdo para editar. A função Juntar de hoje é diferente: renderiza um arquivo e remove os originais. Proposto o caminho para o composto no Drift: contêiner que guarda os clipes dentro do projeto e usa o arquivo renderizado para reproduzir; dois cliques abrem o conteúdo com um "Voltar"; ao sair, renderiza de novo se mudou; ação "Dissolver". Estimativa de dois a três dias. Aprovado pelo Andre no mesmo dia.

**Clipe composto, implementação.** Feita no branch `compound-clips`: timeline aninhada guardada no projeto (`compounds`), clipe substituto com `compoundId`, criar (Alt+G), abrir com dois cliques, barra "Voltar", sair com re-renderização automática só quando houve mudança, dissolver (Ctrl+Shift+G), salvar de dentro grava o projeto externo, comandos para o agente, catorze frases traduzidas, dois testes. Detalhes em `docs/07-clipe-composto.md`. Compilou na primeira tentativa; um teste revelou um falso positivo no detector de mudanças, corrigido e recompilado. Suítes do núcleo e do editor passam. Commit provisório no branch `compound-clips`, enviado ao fork. Build exportada para o repositório local nos ramos master e stable.

**Instalação.** A build com Link e Juntar foi instalada nos ramos master e stable às 18:28, depois de fechar o Drift. Trabalho gravado num commit provisório em `link-clips-v2` e enviado ao fork como cópia de segurança.

**Organização.** Criada a pasta "Projeto Drift" com o código e esta documentação.

**Fechamento.** Três ramificações no fork: `link-clips` (antiga, base 0.5.1), `link-clips-v2` (Link + Juntar) e `compound-clips` (as três funções, base main, compilada e testada). Documentação enviada ao fork na ramificação `notas-projeto`. O pull request oficial continua parado: falta o Andre escrever as mensagens de commit e a descrição, porque o projeto proíbe que a IA as escreva ou abra o pull request. Passo a passo em `docs/08-estado-e-envio.md`.

## 2026-09-12

**Problema inicial.** O Drift instalado pelo Flathub não abria os vídeos MOV do iPhone que estavam no SSD externo. A mensagem "This package cannot read files dropped from other apps" era o sandbox do Flatpak sem acesso a `/run/media`. Corrigido com `flatpak override` liberando `/run/media` e `/media`. Os arquivos estavam íntegros (HEVC 4K, áudio AAC).

**Pedido.** Vincular um vídeo a um áudio de outra origem. O Drift 0.5.1 só tinha "Unlink" e "Separate audio". Não existia o inverso.

**Implementação da função Link.**
- Baixado o fonte da versão 0.5.1, branch `link-clips`.
- Criado o campo `linkLoose` no clipe: vínculo solto que move, corta, seleciona e apaga junto, mas não copia duração, corte, velocidade ou fades entre os clipes. Necessário porque o vínculo original do Drift copia os tempos do vídeo para o áudio, o que estragaria um áudio de tamanho diferente.
- Nova ação `link` com atalho Ctrl+Shift+L, botão na barra da timeline, item no menu de mais ações e no botão direito do clipe, comando `link_clips` para o agente interno, ícone Lucide `link`.
- Teste unitário `linkUnrelatedClipsMoveTogetherKeepTiming`.
- Compilado como Flatpak com o SDK do KDE 6.11. Suíte do editor: 80 testes passaram. Suíte do núcleo: 85 passaram.

**Interface em inglês.** Descoberto que a compilação do Flatpak regenera os catálogos de tradução vendo só os arquivos C++ e, com `-no-obsolete`, apaga todas as frases da interface QML. Sobravam 593 de 2043 frases. Corrigido passando `-DDRIFT_AUTO_UPDATE_TRANSLATIONS=OFF` no manifesto. Traduzidas as 27 frases pt_BR que faltavam. Depois descobri que o main do projeto já tinha essa mesma correção no manifesto.

**Instalação.** A build local foi instalada como ramo `master`. Como o GNOME continuava abrindo o ramo `stable` do Flathub, a mesma build foi publicada também como `stable` a partir de um repositório local (`drift-local`). Hoje os dois ramos são a versão modificada.

**GitHub.** Fork criado em andreMota123/Drift, branch `link-clips` enviado, pull request #200 aberto pelo Andre no projeto oficial. O PR está com conflito porque o main avançou 137 commits desde a 0.5.1. A função foi reaplicada limpa sobre o main no branch `link-clips-v2`, com as entradas nos 10 catálogos de tradução. Pendente: verificação da compilação sobre o main, mensagem de commit escrita pelo Andre (regra do projeto), e atualizar o PR.

