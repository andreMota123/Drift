# Função Link: vincular clipes de origens diferentes

## O problema

O Drift 0.5.1 tinha duas ações relacionadas a vínculo:

- **Separate audio** (Ctrl+Shift+S): tira o áudio embutido de um clipe de vídeo e o coloca numa faixa própria, já vinculado ao vídeo.
- **Unlink** (Ctrl+Shift+U): desfaz o vínculo.

Não existia a ação inversa. Depois de desvincular, não dava para religar. E não dava para vincular um vídeo a um áudio gravado à parte.

## Como o vínculo funciona por dentro

Cada clipe tem um campo de texto chamado `linkId`. Clipes com o mesmo `linkId` são parceiros. Ao clicar num deles, o Drift seleciona todos; ao cortar, corta todos no mesmo ponto; ao mover, move todos.

Havia um detalhe decisivo: a função `syncLinkedTiming` copia do clipe editado para os parceiros o início, a **duração**, os pontos de corte na origem, a velocidade e os fades. Isso é correto quando os dois clipes vêm do mesmo arquivo, que é o único caso que o Drift previa. Para um vídeo de 10 segundos vinculado a um áudio de 3 minutos, o áudio seria encurtado para 10 segundos na primeira edição.

## A solução: vínculo solto

Foi criado um segundo tipo de vínculo, marcado pelo campo `linkLoose` no clipe:

| Comportamento | Vínculo original | Vínculo solto (Link) |
|---|---|---|
| Selecionar juntos | sim | sim |
| Mover juntos, mantendo a distância entre eles | sim | sim |
| Cortar juntos no mesmo ponto | sim | sim |
| Apagar juntos | sim | sim |
| Copiar duração e cortes de um para o outro | sim | **não** |
| Copiar velocidade e fades de um para o outro | sim | **não** |

A ação **Link** cria sempre um vínculo solto. A ação Unlink limpa os dois campos.

## Regras da ação

- Fica disponível quando há dois ou mais clipes selecionados e nenhum deles já tem vínculo.
- Seleção múltipla: clique no primeiro, Shift+clique nos demais.
- Atalho: **Ctrl+Shift+L**. Estava livre; Ctrl+L é o loop da área de trabalho.
- Aparece em três lugares: botão de corrente fechada na barra da timeline (ao lado do Unlink), item "Vincular clipes selecionados" no menu de mais ações da barra, e item "Vincular" no botão direito do clipe.
- Desfazer (Ctrl+Z) funciona, porque a ação passa pelo histórico do projeto como qualquer edição.
- O agente interno do Drift ganhou o comando `link_clips`, no mesmo molde de `unlink_audio`.

## Arquivos alterados

| Arquivo | Mudança |
|---|---|
| `src/core/Clip.h` | campo `bool linkLoose = false` |
| `src/core/Project.cpp` | grava e lê `linkLoose` no arquivo de projeto |
| `src/models/AppController.h` | propriedade `linkAvailable`, funções `canLinkSelection` e `linkSelectedClips` |
| `src/models/AppController.cpp` | as duas funções; `syncLinkedPartnersFrom` ignora vínculos soltos; `moveClip` inclui os parceiros no movimento; atalho, registro e despacho da ação; Unlink limpa `linkLoose` |
| `src/qml/components/timeline/TimelineToolbar.qml` | botão e item de menu |
| `src/qml/components/timeline/TimelineClipItem.qml` | item no menu do clipe |
| `src/qml/Theme.qml` | ícone `link` |
| `resources/icons/link.svg` | ícone Lucide (licença ISC, como os demais) |
| `src/mcp/McpCatalog.cpp`, `McpCatalogExtendedOps.inl`, `McpDispatcherExtended.cpp` | comando `link_clips` |
| `tests/tst_editorstate.cpp` | teste `linkUnrelatedClipsMoveTogetherKeepTiming` |
| `i18n/*.ts` | as quatro frases novas em todos os catálogos, traduzidas em pt_BR |

## O teste

O teste cria um vídeo de 4 s e um áudio de 2 s começando em 1 s, ambos sem vínculo, e verifica:

1. Com um só clipe selecionado, Link fica indisponível. Com os dois, fica disponível.
2. Depois de vincular, os dois têm o mesmo `linkId`, e Unlink fica disponível.
3. Mover o vídeo para 3 s leva o áudio para 4 s, mantendo a distância de 1 s.
4. Cortar o final do vídeo em 5 s não altera a duração, o início nem o corte de origem do áudio.
5. Depois de desvincular, mover o vídeo não move mais o áudio.

Resultado na build sobre a versão 0.5.1: passou, junto com os 80 testes da suíte do editor e os 85 do núcleo.

## Duas versões do branch

- `link-clips`: a implementação sobre a versão 0.5.1. É a que está instalada na máquina.
- `link-clips-v2`: a mesma implementação reaplicada sobre o `main` do projeto oficial, que avançou 137 commits desde a 0.5.1. É a que vai para o pull request. Diferença: no main, `moveClipToTrack` já move a seleção inteira com o mesmo deslocamento, então a alteração extra que existia nessa função na primeira versão não é mais necessária.
