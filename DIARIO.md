# Diário do projeto

Registro do que foi feito em cada dia. O mais recente fica no topo.

## 2026-10-20

**Áudio com IA, etapa 2** (commit `51f9d7e9`, ramo `capcut-audio`). Com a permissão do Andre para baixar os modelos, entraram em Áudio › Básico duas caixas novas:

- **Aprimorar voz**: MossFormer2, Apache-2.0, 229 MB.
- **Isolar voz**: HTDemucs v4, MIT, 169 MB.

Cada modelo é baixado no primeiro uso e conferido por hash. O clipe passa a tocar a versão processada; desligar a caixa volta o som original. No vídeo, o som é separado antes.

Na gravação real de 1:48, o ruído de fundo caiu de −42 dB para −71 dB (isolar) e para silêncio nas pausas (aprimorar), com o volume igual. 60 s de áudio levam cerca de 1 s na NVIDIA e de 4 a 8 s no processador.

Conferido na tela. Suítes sem falhas novas. Ficou registrado que o runtime CUDA às vezes aborta ao fechar o processo, inclusive com o aprimorar qualidade que já existia.

Detalhes em `docs/23-audio-ia-etapa2.md`.

**Áudio no estilo CapCut, etapa 1** (commit `8f317ec0`, ramo novo `capcut-audio`). Com o OK do Andre, a seção Áudio ganhou duas abas.

- **Básico**: volume, fade-in e fade-out só do som (a imagem não escurece), e caixas liga/desliga para:
  - Normalizar nível de volume (−14, −16 ou −23 LUFS; desligar volta o volume de antes);
  - Reduzir ruído (o DeepFilterNet que já existia);
  - Preencher canal (esquerdo, direito ou mono, para microfone de lapela num lado só).
- **Modificador de voz**: grade com 34 cartões (filtros e personagens), busca, favoritos, "Aplicar a tudo" e o cartão Original. É uma voz por vez, e os outros efeitos do clipe ficam intactos. Nove sons que faltavam (voz nítida, locutor, estúdio, graves, igreja, super reverberação, eco divino, distorcido, fantasma) viraram pacotes de efeito novos, montados com pedais que já existem.

Conferido na tela. Testes novos nas quatro suítes, sem falhas novas. Instalado nos ramos master e stable.

O ramo ficou separado do `capcut-080` porque a pasta `Drift-link` tem trabalho não salvo da sessão das pendências; mesclar depois. Detalhes em `docs/22-audio-capcut-etapa1.md`.

**Comparativo com o CapCut (áudio primeiro).** O Andre mandou 8 capturas do CapCut (Áudio › Básico e Modificador de voz, Vídeo › Básico, Remover fundo, Retoque/Maquiagem, Ajuste, biblioteca de música). Levantado o que o Drift já tem e pesquisado no GitHub o que falta, com as licenças conferidas: `docs/21-comparativo-capcut-audio-video.md`. Nada implementado. O trabalho segue numa sessão nova (o contexto desta chegou no limite).

## 2026-10-19

**Botão Exportar não abria a janela** (commit `169717a7`). Depois da atualização para a 0.8.0, a janela de exportação pedia uma foto do preview pela função `grabFrame` do preview antigo, que o oficial substituiu; o erro `preview is not defined` interrompia a abertura. O preview novo (`PreviewViewport`) ganhou a função de volta, e a janela abre mesmo se a foto falhar. Conferido numa cópia de teste (janela de duas colunas com a miniatura) e instalado nos ramos master e stable (commit stable `87d463da`). A compilação foi feita a partir de uma cópia limpa do ramo, sem as mudanças não salvas da sessão das pendências, que continuam na pasta `Drift-link`.

## 2026-10-16

**Atualização para o Drift oficial 0.8.0** (ramo novo `capcut-080`, mesclagem `7f2b2a60`). O Andre perguntou o que mudaria e o que ganhávamos; depois de uma mesclagem de teste (44 arquivos em conflito) e de testar trazer as funções uma a uma (cada uma conflitava sozinha, por depender de outras e de 118 correções), escolheu a mesclagem completa mantendo o visual CapCut e as nossas funções. O oficial tinha reorganizado o controlador em ~15 partes, o painel de propriedades, o preview, a barra da timeline e o desenho dos clipes (agora em C++); tudo foi costurado mantendo a aparência CapCut. Funções repetidas ficaram com a versão do oficial (Link, soltar arquivos, guias, decodificador); nosso clipe composto ficou escondido em favor do oficial. Resultado na tela: o look Batom vermelho finalmente pinta os lábios. Suítes: núcleo 171, editor 235, agente 152/153 (a falha é do fluxo de complementos do oficial), motor 235. Detalhes, pendências e como voltar em `docs/20-atualizacao-080.md`.

## 2026-10-15

**Concat.** O Andre mostrou o Concat (github.com/jub0t/Concat), editor gratuito "substituto do CapCut". É Rust com Slint, licença AGPL-3.0: o código não se aproveita no Drift, mas os modelos de IA locais que ele usa têm licenças livres e rodam no mesmo ONNX Runtime do Drift. Instalado para o Andre ver e depois removido a pedido dele.

**IA local.** Levantado o que roda neste PC (Ollama com qwen3, gemma4 e bge-m3; ComfyUI com Qwen-Image e Qwen-Image-Edit) e testado o qwen3:14b chamando ferramentas de edição em português: acertou a sequência em 8,6 s. Plano completo em `docs/11-ia-local.md`.

**Memória da placa de vídeo** (commit `b4d06396`). Cada vídeo abria seu próprio contexto na placa e o Drift nunca liberava decodificadores ociosos no PC; com muitos vídeos 4K do iPhone a memória acabava e tudo passava a decodificar no processador. Agora há um contexto compartilhado e só os seis decodificadores ociosos mais recentes ficam abertos. Medido com dez vídeos 4K HEVC: de 7,8 GB e subindo para 3,9 GB estáveis. Era também o pré-requisito para a IA local caber junto com o Drift nos 16 GB da placa.

**Assistente dentro do Drift** (commits `6ddcc700` e `26b97f73`). Nova aba "Assistente" que conversa em português com o qwen3:14b do Ollama e edita o projeto pelas ferramentas do acesso de agente, chamadas dentro do processo. Mostra cada ação com ✓/✗, avisa quando algo não funcionou mesmo que o modelo diga o contrário, desfaz um pedido inteiro num clique e pede confirmação antes de salvar, exportar ou mexer em arquivos. Os testes revelaram duas armadilhas: o modelo inventava sucesso (resolvido com a verificação feita pelo próprio programa) e o ímã da faixa principal o fazia apagar de novo o que já tinha apagado (resolvido avisando o modelo e orientando o uso de "cortar trecho"). Detalhes em `docs/12-assistente.md`.

**IA local ou Claude.** Dois caminhos (`docs/13-ponte-claude.md`): (1) o Drift registrado como MCP no Claude Code e o acesso de agente ligando sozinho, para o Claude editar o Drift a partir da conversa, conferido com `claude mcp list`; (2) a opção "Claude" na aba Assistente (commit `cac8ff72`), que manda o pedido a uma ponte local (`~/.local/bin/drift-claude-ponte`) que roda o Claude Code só com as ferramentas do Drift, com salvar e exportar bloqueados durante o pedido. O modo automático não deixou ativar a ponte como serviço; falta o Andre rodar `claude auth login` e ativar o serviço.

**Legendas com IA local** (commit `ac67ebc2`). No editor de legendas, "Corrigir com IA" (ortografia, acentos, palavras mal ouvidas, maiúsculas, nomes e pontuação, sem mexer nos tempos, com janela de revisão linha a linha) e "Traduzir" (cópia traduzida numa faixa nova acima da original, a legenda bilíngue). Comparados os modelos da máquina com legendas reais: o gemma4:12b corrigiu e traduziu melhor que o qwen3:14b e virou o padrão das legendas. Detalhes em `docs/14-legendas-ia.md`.

**Cortes curtos** (commit `85f1d228`). Menu › Cortes curtos deste vídeo: a IA local lê as legendas, propõe momentos que funcionam sozinhos (título, tempo, primeira frase, motivo) e cada um aprovado vira um projeto vertical 9:16 numa pasta ao lado, feito por um Drift sem janela sobre uma cópia do projeto, sem tocar no original. Testado com um vídeo de 8 min 40 s: três cortes criados e o primeiro conferido na tela (36 s, começando exatamente no ponto escolhido, legendas no lugar). Detalhes em `docs/15-cortes-curtos.md`.

**Enchimento e repetições** (commit `4a6efd25`). Menu › Remover enchimento e repetições: tomadas repetidas e falsos começos achados por regra (comparação de palavras entre frases; os modelos locais marcavam tudo como repetição), enchimento e comentários pela IA local, cortes com as pontas na pausa mais próxima e as legendas juntadas de volta num clipe. Numa gravação bruta real de 1:48 achou as 9 tomadas repetidas mantendo a última de cada, 31 de 34 pontas de corte caíram em silêncio, e o resultado ficou com 1:22. Detalhes em `docs/16-enchimento-e-repeticoes.md`.

**Aprimorar qualidade** (commit `48b61e51`). Na aba Estabilização do clipe de vídeo: o trecho usado passa pelo Real-ESRGAN (baixado na primeira vez e conferido por hash) até a altura do projeto e vira um arquivo que substitui só a imagem do clipe; o som continua do original. Testado: 360p → 1080p, nitidez bem maior. Lento ainda (cerca de 0,5 s por quadro); conferir o uso do CUDA. Detalhes em `docs/17-aprimorar-qualidade.md`. Estado geral e como retomar: `docs/18-estado-2026-10-15.md`.

**Instalação final do dia.** A build do aprimorar qualidade terminou às 18:40. Suítes conferidas nela (editor 147, agente 113, motor 138, núcleo 129; motor, agente e núcleo só passam dentro do sandbox de compilação, que monta o fonte em `/run/build/drift`). Exportada para os ramos master e stable do repositório local e instalada com `flatpak update`, sem precisar fechar o Drift: a versão nova vale a partir da próxima abertura. Ramo `capcut-style` enviado ao fork (`4a6efd25..48b61e51`).

**Aprimorar qualidade na NVIDIA** (commit `a7b13fde`). O Andre não achou o botão e pediu para eu ver. O botão está em Vídeo › Estabilização, no fim do painel (conferido por captura, com um timer temporário, porque o Wayland bloqueia cliques sintéticos). Ao rodar, o aprimoramento ia para o processador: o Drift carregava o motor de IA do processador mesmo com o da NVIDIA instalado, e, com o da NVIDIA, o CUDA falhava por o registro do motor ainda não existir. Corrigidos os dois; o clipe de teste caiu de 100 s para cerca de 6 s, com a mesma imagem. Suítes conferidas, build instalada nos ramos master e stable e enviada ao fork. Detalhes em `docs/17-aprimorar-qualidade.md`.

**Maquiagem ao estilo do Instagram, etapa 1** (commits `84e2ab0a` e `c073130f`). Pesquisa em `docs/19-maquiagem.md`: o Drift já tinha os efeitos de beleza; faltavam os looks de um toque. Feita a aba Vídeo › Maquiagem com sete looks e um controle de intensidade, comando `apply_makeup_look` para o agente, tradução e dois testes. No teste visual apareceram dois problemas: a detecção de rosto falhava neste PC por causa do WebGPU (corrigido: com o motor da NVIDIA os modelos usam CUDA) e batom e blush não aparecem porque dependem da malha `face111`, que só existe no Drift oficial 0.8.0 (426 commits à frente do nosso ramo).

## 2026-10-10

**Engenharia reversa do CapCut.** Instalado o REA (github.com/morluto/rea) com Ghidra 12.1.4 e ferramentas de apoio em `~/.local/opt/rea-tools`. A interface do CapCut 3.9 é Qt 6/QML e estava embutida em texto puro nas DLLs: foram extraídos 1.554 arquivos QML e os ícones para `~/capcut/analise/qrc/`. As cores do tema foram lidas dos binários.

**Documentação.** Nova pasta `docs/capcut-re/` com nove documentos (cores, janela e design, timeline, player e exportação, painel de materiais, propriedades, texto, motor de cor, formato de projeto) e um índice com a ordem de trabalho. Cada um termina com o mapa para o Drift. Nenhum código do Drift foi alterado.

**Aplicação no Drift (ramo `capcut-style`, sem commit).** Paleta e densidade do CapCut no tema; barra de título com Menu, nome no centro e Exportar chapado; painel de propriedades com seções de texto e sub-abas; travar faixa; faixa principal mais alta; cinco modos de mesclagem novos. Detalhes, testes e o novo ciclo rápido de compilação em `docs/10-aplicacao-capcut.md`.

**Ambiente.** Instalada a extensão NVIDIA 615 do Flatpak, que faltava depois da atualização do driver do sistema.

**Mais levas no mesmo dia.** Aba Ajuste, régua por níveis, exportação em duas colunas, catálogo pt-BR completo, corte roll, efeitos HSL, rodas, curvas e LUT (com o motor aceitando textura de arquivo escolhido pelo usuário), linha de volume no clipe e soltar arquivo de fora direto na trilha. Tudo commitado no ramo `capcut-style` (de `da1eb6ea` a `82371b16`) e instalado.

**CapCut 9.5.** Baixado o instalador oficial, aberto sem executar, extraída a interface e analisada em oito frentes. Documentos em `docs/capcut-re/v95/` (índice e prioridades em `v95/README.md`). O instalador e o programa extraído foram apagados depois; ficou só o QML de referência em `~/capcut/v95/`.

**Primeiros itens da 9.5 no Drift.** Paleta em cinzas neutros, "Fechar todos os espaços" com realce dos vãos, altura de faixa por predefinição e por arraste, tamanho da forma de onda (30/60/100%) e menu de curvas no quadro-chave (entrada suave, saída suave, suavização, linear, salto). Três commits no ramo `capcut-style` (`7620597f`, `547660f9`, `d41fd3b9`). Detalhes na "Sétima leva" de `docs/10-aplicacao-capcut.md`. 

**Mais dois itens da 9.5.** Pesquisa nas legendas com contador e anterior/próximo, dividir (Enter) e mesclar (Backspace no início, Delete no fim) pelo teclado, prévia de mídia social no preview (TikTok, Shorts, Reels) com seletor de guia na barra, e margens seguras em 5% e 10%. Commits `8c8c0957` e `eea3cebb`; "Oitava leva" do doc 10. Próximos: formas (linha e seta, tracejado, raio por canto), depois os médios (guias arrastáveis, exportação em lote).

**Formas e mídia perdida.** Forma "Linha" com pontas configuráveis e raio por canto nos retângulos (`d1430c39`). Diálogo "Vincular mídia" que se oferece ao abrir projeto com arquivos sumidos, vincula os clipes ao arquivo novo e traz junto as outras mídias da mesma pasta (`da79c49d`). Corrigido de passagem: clipes ficavam sem miniatura quando ela era gerada depois. "Nona leva" do doc 10. Oito dos vinte itens da 9.5 feitos (1 a 7 e 12).

**Itens médios.** Réguas e guias arrastáveis no preview com encaixe, exportar clipes selecionados em lote, vinculação à faixa principal configurável, remover pausas com revisão, e canto arredondado e expansão nas máscaras. "Décima leva" do doc 10. Feitos 13 dos 20 (faltam o painel de sugestões e os seis grandes). Atenção à mudança de comportamento do ímã da faixa principal, descrita lá.

**Sugestões e itens grandes.** Sugestões inteligentes (volume e pausas, com correção em lote), timelines em abas, cortar trecho de tempo em todas as faixas (com a tesoura no editor de legendas) e gravação de microfone, tela e câmera. "Décima primeira leva" do doc 10, que também lista o que ficou de fora: proxy, painel de chat do agente, ferramenta caneta. A gravação de tela não funcionou no ambiente de teste e precisa ser conferida na sessão real.

**Ramo `capcut-style` ao fim do dia:** 16 commits novos, de `7620597f` a `347fc797`, só locais.

**Pendências.** Muitas faixas de slider, a ordem das abas e as listas da exportação ficam no C++ do CapCut e precisam ser conferidas com o aplicativo aberto. O formato de projeto só foi conferido para clipe de vídeo.

## 2026-10-07

**Pedido.** Deixar o Drift o mais parecido possível com o CapCut, em funções e aparência, olhando também a versão atual do CapCut.

**CapCut no Linux.** A versão atual (9.5) não roda em Wine; a 3.9.0.1459 roda e ficou instalada em `~/capcut/prefix39` (atalho "CapCut (Linux)"), com a atualização automática bloqueada. Serve de referência ao vivo.

**Comparativo.** Levantadas as funções das duas versões do CapCut pelos catálogos de textos da interface e conferidas uma a uma no código do Drift. Resultado e ordem sugerida de trabalho em `docs/09-comparativo-capcut.md`.

**Aparência, primeira etapa** (ramo `capcut-style`, sobre `compound-clips`, sem commit):
- Cor de destaque passou de âmbar para o ciano do CapCut (`#00C1CD`), com painéis `#1B1B1C` e bordas `#29292D`. Tudo em `src/qml/Theme.qml`.
- Painel de recursos: o trilho vertical só de ícones virou barra de abas no topo, com ícone e nome, rolável na horizontal. Em `src/qml/AssetsPanel.qml`.
- Ordem das abas igual à do CapCut: Mídia, Áudio, Texto, Adesivos, Efeitos, Transições, Legendas, Modelos; depois Formas, Máscaras, Cenas, Market e Atalhos.

**Ímã da faixa principal.** Pedido do Andre depois de ver a primeira etapa: no CapCut, um vídeo solto na faixa principal fica rente ao anterior. Implementado como opção `magneticMainTrack` no `AppController` (preferência `timeline/magneticMainTrack`, desligada por padrão no código e ligada na configuração do Andre). A rotina `applyMainTrackMagnet` roda dentro de `pushProjectEdit`, então vale para soltar, mover, aparar e apagar, num único passo de desfazer: ordena os clipes da última faixa de vídeo e fecha os espaços, levando junto os clipes vinculados. Sobreposições ficam como estão, porque é assim que as transições são representadas. Botão "Ímã da faixa principal" na barra da timeline. Teste `mainTrackMagnetClosesGaps`; suíte do editor com 138 testes passando. Diferença para o CapCut: soltar um clipe em cima de outro ainda não o insere no meio.

**Botão do ímã não aparecia.** Depois de instalar, a barra da timeline seguia sem o botão. Causa: o Qt guarda as telas QML já compiladas em `~/.var/app/org.cutwire.Drift/cache/CutWire Drift/CutWire Drift/qmlcache` e valida esse cache pela data do executável. No Flatpak o executável tem sempre a mesma data, então o cache nunca era renovado e o Drift mostrava a interface de uma build anterior. Corrigido apagando a pasta e desativando o cache para o app: `flatpak override --user --env=QML_DISABLE_DISK_CACHE=1 org.cutwire.Drift`. O botão ganhou ícones próprios (`main-track-magnet.svg` e `main-track-magnet-off.svg`), um para cada estado.

**Como ver a tela do Drift sem print.** Abrir em modo X11 (`flatpak run --socket=x11 --share=ipc --nosocket=wayland --env=QT_QPA_PLATFORM=xcb org.cutwire.Drift//stable`) e capturar a janela pelo GDK. Em Wayland não há como capturar.

**Disco.** A exportação para o repositório local do Flatpak falha com menos de 3% de disco livre. Cada compilação deixa cerca de 3,9 GB em `~/.cache/drift-build/state/build/drift-N`.

**A fazer na aparência.** Abas de texto no painel de propriedades, cabeçalho com Menu à esquerda e nome do projeto no centro, revisão da barra da timeline e dos cabeçalhos de faixa.

## 2026-09-23

**Travamentos na timeline.** O Drift travava a cada clique com a gravação `video1962351589.mp4` (2h12min, 1920×1040, 25 fps, 0,56 Mbps) aberta. Em 13h30 aberto, o Drift gastou 14 horas de CPU, 12,6 delas em 32 threads de decodificação H.264 por software. Causa: o vídeo tem um quadro-chave a cada 36 segundos (900 quadros), e cada busca na timeline decodifica desde o quadro-chave anterior. O modo "Auto" mandava esse vídeo para a CPU porque ele é leve pelos critérios antigos (só 4K, pixels por segundo ou bitrate por quadro). A RTX 5070 Ti e o NVDEC estavam carregados e sem uso.

**Correção no código.** `ClipReader::hardwareDecodeIsWorthIt` agora também mede o espaçamento médio entre quadros-chave pelo índice do contêiner (tabela stss do MP4/MOV, até 20 000 entradas) e manda para a GPU qualquer vídeo com quadro-chave a cada 5 segundos ou mais. Branch `compound-clips`, sem commit ainda. Compilada e instalada nos ramos master e stable no mesmo dia. Ainda não verificado no uso real.

**Cópia para edição.** Gerada `video1962351589_edicao.mp4` na mesma pasta do SSD, recodificada pela NVENC com um quadro-chave por segundo (cq 23, áudio copiado). O original não foi alterado.

**Contorno imediato.** No seletor de decodificação da barra do preview, escolher "Hardware (NVDEC)".

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

