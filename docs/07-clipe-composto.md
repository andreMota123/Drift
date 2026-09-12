# Clipe composto: contêiner editável ao estilo do CapCut

## O pedido

No CapCut, "Criar clipe composto (subprojeto)" transforma a seleção num único clipe que guarda os originais. Dois cliques abrem o composto para editar o conteúdo, com um "Voltar" no topo. É diferente da função Juntar, que gera um arquivo e descarta os originais.

## Como funciona no Drift

O motor do Drift não compõe um projeto dentro de outro ao vivo. A solução guarda os clipes originais como uma **timeline aninhada** dentro do arquivo do projeto e usa um **arquivo renderizado** como substituto para reproduzir e exportar.

1. **Criar** (Alt+G, ou botão direito, "Criar clipe composto"). Igual à função Juntar, mas os clipes selecionados são guardados como timeline aninhada, rebaseada para começar em 0, com faixas, efeitos e transições entre eles. O clipe que entra na timeline principal leva o nome "Clipe composto N" e usa o vídeo renderizado.
2. **Abrir** (dois cliques no clipe, ou botão direito, "Abrir clipe composto"). A timeline passa a mostrar o conteúdo interno. Uma barra acima da timeline mostra "Voltar" e o nome do composto. Biblioteca de mídia, pastas e a tabela de compostos continuam as mesmas; só as faixas trocam de nível. Dá para abrir um composto dentro de outro.
3. **Voltar** (botão na barra). A timeline externa volta. Se o conteúdo mudou, o Drift regrava a timeline aninhada e renderiza de novo o substituto em segundo plano; quando termina, o clipe passa a usar o arquivo novo e assume a duração nova do conteúdo. Se nada mudou, nada é renderizado.
4. **Dissolver** (Ctrl+Shift+G, ou botão direito). Devolve os clipes internos à timeline principal, deslocados para a posição do composto, e apaga o composto. Cada faixa interna volta para a faixa externa de mesmo número quando ela aceita aqueles clipes; senão, o Drift escolhe uma faixa compatível.

## Detalhes que importam

- **Desfazer.** Cada nível tem o próprio histórico. Ao entrar ou sair de um composto, o histórico é zerado, porque um "desfazer" gravado fora restauraria a timeline externa enquanto a barra ainda diz que você está dentro. A saída com mudanças entra no histórico externo como uma edição, e a atualização do arquivo renderizado como outra.
- **Salvar de dentro.** Salvar o projeto enquanto um composto está aberto grava o projeto externo com o conteúdo interno já dobrado de volta. Você nunca salva "meia timeline".
- **Carregar outro projeto** fecha qualquer nível aberto.
- **Renderização em andamento** bloqueia abrir e sair de compostos, porque a saída dispararia outra renderização sobre a mesma fila.
- **Exportar de dentro** exporta o que está na tela, ou seja, o conteúdo interno. Volte para a timeline principal antes de exportar o vídeo final.

## Formato no arquivo do projeto

- O clipe substituto tem o campo `compoundId`.
- O projeto tem o objeto `compounds`, com um item por composto: a timeline aninhada em JSON, só as faixas, sem mídias nem metadados, escrita pelo mesmo serializador das faixas normais.

Projetos antigos abrem normalmente; o campo e o objeto são opcionais.

## Arquivos alterados

| Arquivo | Mudança |
|---|---|
| `src/core/Clip.h`, `src/core/Project.h/.cpp` | campo `compoundId`; tabela `compounds()`; gravação e leitura; cópia destacada |
| `src/core/TimelineOps.h/.cpp` | `compoundTracksToJson`, `compoundTracksFromJson`, `shiftTracks`, `tracksEndUs` |
| `src/models/AppController.h/.cpp` | pilha de níveis; `createCompoundFromSelection`, `enterCompound`, `exitCompound`, `dissolveSelectedCompound`, `canDissolveSelection`; renderizador comum `renderProjectRangeToFile` compartilhado com Juntar; `projectForPersistence` usado ao salvar; ações `compound` e `dissolveCompound` com atalhos |
| `src/qml/TimelinePanel.qml` | barra "Voltar" com o nome do composto |
| `src/qml/components/timeline/TimelineClipItem.qml` | dois cliques abrem; itens de menu criar, abrir e dissolver |
| `src/qml/components/timeline/TimelineToolbar.qml` | itens no menu de mais ações |
| `src/mcp/*` | comandos `create_compound`, `dissolve_compound`, `exit_compound` |
| `tests/tst_core.cpp` | ida e volta do JSON da timeline aninhada, deslocamento com limite em 0, sobrevivência ao salvar e carregar |
| `tests/tst_editorstate.cpp` | abrir, salvar de dentro, sair sem mudanças e dissolver, com um composto montado à mão |
| `i18n/*.ts` | catorze frases novas em todos os catálogos, traduzidas em pt_BR |

## Verificação

Compilado sobre o `main` do projeto oficial dentro do SDK do KDE 6.11.

| Teste | Resultado |
|---|---|
| Núcleo, `compoundTracksRoundTripAndShift` | passou |
| Editor, `compoundClipEnterEditExitAndDissolve` | passou, depois de uma correção: a saída sem mudanças disparava renderização porque comparava o JSON original com o JSON reserializado, que ganha campos padrão na ida e volta |
| Suíte do editor completa, 137 testes | todos passaram, 3 pulados por falta de GPU no sandbox |
| Suíte do núcleo, 128 testes | 127 passaram; a única falha é o teste antigo que depende de um caminho interno do sandbox |

## Limites desta versão

- Depois de editar por dentro, há a espera da renderização ao voltar. Composição ao vivo fica para uma etapa futura.
- O clipe composto ainda não tem um ícone próprio na timeline; o nome "Clipe composto N" o identifica.
- Ao dissolver, os clipes podem sobrepor outros que estejam no mesmo lugar; o Drift não empurra os vizinhos.
