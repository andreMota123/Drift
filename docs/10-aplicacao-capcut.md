# Aplicação do estilo CapCut no Drift

Registro do que foi aplicado a partir da especificação em `capcut-re/`. Ramo `capcut-style`, sem commit (as mensagens de commit e de PR são do Andre, conforme o CONTRIBUTING do Drift).

## Aplicado em 2026-10-10

| Item | Onde | Situação |
|---|---|---|
| Paleta escura do CapCut (fundo `#070709`, painel `#1B1B1C`, controles `#29292D`/`#343337`, texto `#D4D4D4`/`#999999`) | `src/qml/Theme.qml` | Feito |
| Densidade de desktop: controle 22 px, fonte 12/11/10 px, raio 4/8, cabeçalho 36 px, barra da timeline 32 px | `src/qml/Theme.qml` | Feito. No toque (Android) as medidas antigas continuam |
| Barra de título: botão Menu à esquerda, nome do projeto no centro, Exportar chapado à direita | `src/qml/EditorHeader.qml`, `resources/icons/menu.svg` | Feito. Configurações, Extras e Agente foram para dentro do Menu |
| Painel de propriedades: seções de texto no topo (Vídeo/Imagem/Texto, Áudio, Velocidade, Animação) e sub-abas segmentadas fixas | `src/qml/PropertiesPanel.qml` | Feito |
| Travar faixa: botão e item de menu no cabeçalho, clipes inertes e esmaecidos, proteção em qualquer edição | `AppController::setTrackLocked`, `restoreLockedTracks`, `TrackHeaderColumn.qml`, `TimelineClipItem.qml` | Feito, com teste `lockedTrackKeepsItsClips` |
| Faixa principal mais alta (76 px) que as sobrepostas (62 px) | `AppController::trackRowHeight` (métrica `videoMain`), `Theme.trackHeightVideoMain` | Feito |
| Cinco modos de mesclagem novos: luz forte, luz suave, superexposição linear, superexposição de cores, subexposição de cores | `BlendMode.h`, `Clip.cpp`, `GpuCompositor.cpp`, `SkiaShading.cpp`, `BlendingInspector.qml` | Feito. Conferido por render: os valores de cor batem com as fórmulas |
| Início automático do acesso de agente por variável (`DRIFT_MCP_AUTOSTART=1`) | `AppController.cpp` | Feito. Serve para testes automatizados da interface |
| Efeito "Color Adjust" (`adjust.basic`): brilho, contraste, saturação, realces, sombras, brancos, pretos, temperatura, matiz, exposição, fade e vinheta num passe só, em ordem fixa | `effects/adjust_basic/` | Feito. Shader próprio, escrito a partir das fórmulas do documento 07; aparece em Efeitos › Cor |
| Duplo clique no nome do parâmetro redefine o valor | `components/PropertyKeyframeRow.qml` | Feito |
| Slider no visual do CapCut: trilho de 2 px, puxador 8×12 claro, preenchimento a partir do zero e ímã no zero em faixas bidirecionais | `components/ThemedSlider.qml` | Feito. No toque o slider antigo continua |
| Selo "Adicionado" na mídia já usada e botão "+" no hover do cartão | `components/assets/MediaAssetsTab.qml` | Feito |
| Traduções pt-BR das frases novas | `i18n/drift_pt_BR.ts` | Feito (27 frases) |

Testes: `tst_editorstate` 139, `tst_core` 128, `tst_mcp` 111, `tst_uifont` 12, `tst_layoutstore` 9, `tst_projectbundle` 12, todos passando. A falha antiga de `tst_mcp` (descrição curta de `link_clips`) foi corrigida.

## Segunda leva (2026-10-10, tarde)

| Item | Onde | Situação |
|---|---|---|
| Régua da timeline por níveis de zoom (23 níveis, rótulos espaçados e traços curtos entre eles; quadros nos níveis finos) | `src/qml/TimelinePanel.qml` | Feito |
| Exportação em duas colunas: quadro atual, nome, resolução, taxa de quadros, duração e tamanho estimado à esquerda; ajustes à direita | `components/ExportDialog.qml`, `PreviewPanel.grabFrame`, `Main.grabPreviewFrame` | Feito. O tamanho é exato com taxa de bits fixa e aproximado em qualidade constante |
| Aba "Ajuste" no painel de propriedades (vídeo e imagem): Cor, Claridade e Efeitos, com duplo clique no nome para zerar e botão Redefinir | `components/properties/ColorAdjustInspector.qml`, `AppController::clipColorAdjust` / `setClipColorAdjust` / `previewClipColorAdjust` / `resetClipColorAdjust` | Feito. Usa o efeito `adjust.basic`; o primeiro ajuste cria o efeito e a seleção continua no clipe |
| Catálogo pt-BR completo: as 1.000 frases que estavam sem tradução | `i18n/drift_pt_BR.ts` | Feito. Escolhas de termo duvidosas: Marketplace = "Loja", Ripple mantido, Pan mantido, Stroke = "Traçado" |

## Terceira leva (2026-10-10)

| Item | Onde | Situação |
|---|---|---|
| Corte roll: Ctrl + arrastar a borda de um clipe encostado em outro move a emenda; um cresce o que o outro perde | `AppController::rollTrim`, `TimelineClipItem.qml` | Feito, com teste `rollTrimMovesTheSharedCut`. O gesto com mouse não foi testado na tela |
| Desfazer e refazer logo depois da ferramenta de seleção na barra da timeline | `TimelineToolbar.qml` | Feito |
| Efeito "HSL by Color" (`adjust.hsl`): matiz, saturação e luminosidade de 8 faixas de cor | `effects/adjust_hsl/` | Feito. Conferido por render: só a faixa mexida muda |
| Efeito "Color Wheels" (`adjust.wheels`): lift, gamma, gain e offset, cada um com balanço RGB e nível, mais saturação | `effects/adjust_wheels/` | Feito. Conferido por render. São sliders; as rodas desenhadas ficam para depois |

Observação: com dois efeitos na mesma camada, a operação de agente `set_effect_param` só acha o parâmetro no primeiro efeito. Pela interface cada efeito tem seus próprios sliders e isso não acontece.

## Quarta leva (2026-10-10)

| Item | Onde | Situação |
|---|---|---|
| Motor: textura de efeito vinda de um arquivo escolhido pelo usuário (`"param"`) e tipo `"cube"` para LUT 3D, com o tamanho publicado no uniform `u_<id>Size` | `GpuEffectDefinition.h`, `GpuPackageParse.cpp`, `GlRuntime.cpp` (`loadCubeLut`, `lutTexture`) | Feito. Tabela em 16 bits por canal; recarrega se o arquivo mudar |
| Efeito "LUT" (`adjust.lut`): arquivo `.cube` e intensidade | `effects/adjust_lut/` | Feito. Conferido por render com três LUTs de teste (identidade, troca de canais, negativo): resultado exato |
| Efeito "Curves" (`adjust.curves`): curva de brilho e de vermelho, verde e azul, cinco pontos cada | `effects/adjust_curves/` | Feito. São sliders por ponto; o editor de curva desenhado fica para depois |

Limites: só `.cube` 3D (não lê `.3dl` nem LUT 1D). A curva de brilho pode escurecer um pouco os tons muito escuros quando se sobe os meios-tons, efeito normal da curva suave.

## Quinta leva (2026-10-10)

| Item | Onde | Situação |
|---|---|---|
| Linha de volume no clipe: régua horizontal sobre a forma de onda, arrastada para cima e para baixo (0 a 200%), com ímã em 100%, dica em dB e duplo clique para voltar a 100% | `TimelineClipItem.qml` (`volumeLine`), campo `volumeAnimated` no mapa do clipe | Feito. Posição conferida por pixel com volume em 50%. O arraste com mouse não foi testado. Some quando o volume tem quadros-chave |

## Sexta leva (2026-10-10)

| Item | Onde | Situação |
|---|---|---|
| Soltar arquivo de fora direto na trilha: arrastar um vídeo, áudio ou imagem do gerenciador de arquivos para a timeline importa e coloca o clipe no tempo e na faixa onde foi solto; durante o arraste, um marcador mostra o tempo | `TimelinePanel.qml` (`timelineAssetDrop.importAndPlace`, chave `text/uri-list`) | Feito. A importação com posicionamento foi conferida na tela (por chamada direta); o arraste real a partir do gerenciador de arquivos não foi testado, porque não há como simular mouse aqui |

## Sétima leva: primeiros itens da 9.5 (2026-10-10)

Itens 1 a 4 da lista de `capcut-re/v95/README.md`. Commits `7620597f`, `547660f9` e `d41fd3b9` no ramo `capcut-style`.

| Item | Onde | Situação |
|---|---|---|
| Paleta em cinzas neutros da 9.5: janela `#000000`, painel `#141414`, bordas e campos `#262626`, hover `#303030`, texto `#E0E0E0`, texto secundário `#949494` | `Theme.qml` | Feito. Conferido na tela |
| Fechar todos os espaços: junta os clipes da faixa, mantendo o primeiro no lugar; clipes vinculados acompanham; um passo de desfazer. Item no menu do vão (clique direito num espaço vazio entre clipes), ao lado de "Fechar espaço" | `AppController::closeAllGaps`, `compactTrackGaps` (a mesma rotina do ímã da faixa principal); comando `close_all_gaps` para o agente | Feito. Teste `closeAllGapsPacksTrack` |
| Realce dos vãos: enquanto o mouse está sobre "Fechar todos os espaços", todos os vãos da faixa ficam marcados (`#33FFFFFF`, raio 4); sobre "Fechar espaço", só aquele | `TimelinePanel.qml` (`gapPreviewTrack`), `Theme.gapHighlight` | Feito. O desenho foi conferido na tela forçando o estado; o hover real do mouse não foi testado |
| Altura da faixa por predefinição: Curto (0,6), Padrão (1) e Alto (1,6) no menu do cabeçalho da faixa, com marca na opção atual | `TrackHeaderColumn.qml` | Feito. Conferido na tela |
| Altura da faixa por arraste: 8 px sobre a borda inferior do cabeçalho, cursor de redimensionar; duplo clique volta ao padrão | `TrackHeaderColumn.qml` (`rowResizeArea`) | Feito. O arraste com mouse não foi testado |
| Tamanho da forma de onda: 30%, 60% ou 100% por faixa, gravado no projeto (`waveformScale`) | `Track.h`, `Project.cpp`, `AppController::setTrackWaveformScale`, `TimelineClipItem.qml`; argumento `waveform` no comando `set_track_height` | Feito. Conferido na tela em 30% |
| Curvas prontas no quadro-chave: clique direito no losango da linha abre Entrada suave, Saída suave, Suavização, Linear e Salto, com marca na atual | `Keyframe.h` (`Interpolation::EaseIn`, `EaseOut`), `PropertyKeyframeRow.qml` (`curveMenu`) | Feito. Menu e marcação conferidos na tela; teste em `tst_core` |

Notas:

- Entrada suave achata só a tangente de saída do quadro-chave (o movimento parte devagar); Saída suave achata só a de entrada (o movimento chega devagar). As duas marcam o ponto como canto, e é isso que as distingue de uma Suavização sem vizinho de um dos lados.
- Os valores em px de Curto/Padrão/Alto do CapCut não foram lidos (ficam no C++); 0,6 e 1,6 são escolha minha.
- As marcas de seleção dos menus novos usam a propriedade `iconSlot` do `ThemedMenuItem`, que reserva a coluna do ícone. Um ícone esvaziado mantinha a imagem anterior; o item agora o esconde.
- O acesso de agente passa os nomes de modo em minúsculas; `interpolationFromString` aceita `easein`/`easeout`.
- Visto e não corrigido: com a janela em 1387 px de largura, o botão "Nova pasta" do painel de mídia fica por cima do rótulo ao lado.

Suítes depois desta leva: editor 141 passaram (3 puladas), agente 111 (5 puladas), núcleo 128.

## Oitava leva: legendas e prévia de rede social (2026-10-10)

Itens 5 e 7 da lista da 9.5. Commits `8c8c0957` e `eea3cebb`. O item 6 (formas: linha, seta, tracejado, raio por canto) ficou para depois.

| Item | Onde | Situação |
|---|---|---|
| Pesquisa nas legendas: campo no cabeçalho do editor, contador "atual/total", anterior e próximo (também Enter e Shift+Enter no campo), limpar (botão ou Esc); as ocorrências ficam em ciano e negrito na lista | `SubtitleEditor.qml` (`searchMatches`, `stepSearch`, `highlightedText`) | Feito. Conferido na tela, inclusive com `<`, `>` e `&` no texto |
| Dividir pelo teclado: Enter na caixa de texto corta a legenda no cursor; o tempo é repartido pela quantidade de caracteres de cada lado. Shift+Enter continua quebrando a linha. Sem texto de um dos lados, Enter só aplica o que foi digitado | `SubtitleEditor.qml` (`splitCueAt`) | Feito. A função foi conferida pelo arquivo `.srt` exportado; as teclas em si não foram testadas |
| Mesclar pelo teclado: Backspace no início junta com a legenda de cima, Delete no fim com a de baixo; o texto é unido com um espaço e o tempo cobre as duas | `SubtitleEditor.qml` (`mergeCue`) | Feito. Mesma ressalva |
| Prévia de mídia social: desenho esquemático da interface do TikTok, do YouTube Shorts e do Reels sobre o preview (botões da direita, legenda, barra inferior), numa caixa 9:16 centrada no quadro | `components/preview/SocialSafeOverlay.qml`, tipos de guia `tiktok`, `shorts`, `reels` | Feito. Conferido na tela |
| Seletor de guia na barra do preview: seta ao lado do botão de guias abre Regra dos terços, Cruz central, Margens seguras e as três prévias, com marca na atual | `PreviewToolbar.qml` (`guideTypeMenu`) | Feito. Conferido na tela |
| Margens seguras em 5% e 10%, como na 9.5 (antes 2,5% e 5%) | `PreviewPanel.qml` | Feito |

Notas:

- No CapCut a prévia só aparece em projeto 9:16 e usa artes SVG da própria rede. Aqui o desenho é próprio, feito em QML, e aparece em qualquer proporção: num projeto 16:9 a caixa 9:16 mostra também o que um corte vertical manteria.
- O menu de guias abre para cima. Um `Menu` do Qt só tem altura depois de aberto uma vez, então a primeira posição é calculada pelas linhas e as seguintes usam a altura real.
- O comando `set_guides` do agente listava tipos que não existem (`center`, `golden`, `grid`); o catálogo agora traz os reais.
- Diferença para o CapCut na divisão: lá não se sabe como o tempo é repartido; aqui é proporcional aos caracteres.
- Não há aviso de "não é possível mesclar aqui": sem vizinho, a tecla simplesmente age como sempre.

## Nona leva: formas e mídia perdida (2026-10-10)

Itens 6 e 12 da lista da 9.5. Commits `d1430c39` e `da79c49d`.

| Item | Onde | Situação |
|---|---|---|
| Forma "Linha": barra no meio da caixa com ponta escolhida em cada extremidade (Nenhum, Seta, Arredondado) e espessura ajustável. Duas entradas no catálogo: "Linha" (Básico) e "Seta em linha" (Setas) | `ShapeStyle.h` (`ShapeKind::Line`, `LineCap`, `startCap`, `endCap`), `ShapePath.cpp` (`linePath`), `ShapeInspector.qml` | Feito. Conferido na tela com ponta arredondada e seta; teste `lineShapeAndPerCornerRadius` |
| Raio por canto em retângulo, quadrado e retângulo arredondado: caixa "Definir cada canto" e quatro campos; desmarcada, todos seguem o raio único | `ShapeStyle::cornerRadii`, `ShapePath.cpp` (`perCornerRectPath`), `SkiaShapePainter.cpp`, `ShapeInspector.qml` | Feito. Conferido na tela (120/0/120/0) |
| Mídia perdida: ao abrir um projeto com arquivos que sumiram, o diálogo "Vincular mídia" se oferece, com Nome, Último caminho e Duração, ✓ nas já vinculadas e contador | `components/RelinkMediaDialog.qml`, `AppController::missingMedia`, `reportMissingMedia`, sinal `missingMediaFound` | Feito. Conferido na tela |
| Vincular: escolhe-se o arquivo novo; o item de mídia e todos os clipes cortados dele passam a apontar para lá, mantendo posição, corte e efeitos. Um passo de desfazer | `AppController::relinkMedia` (usa `remapProjectPaths`) | Feito. Teste `relinkMediaRepointsAssetsAndClips`; conferido de ponta a ponta pelo acesso de agente |
| Vincular as demais da mesma pasta (caixa marcada por padrão): procura cada outra mídia perdida no mesmo lugar relativo ao arquivo escolhido e, se não achar, pelo nome na pasta dele | idem | Feito. No teste na tela, `b.mp4` veio junto com `a.mp4`; `musica.mp3`, movida para uma subpasta diferente, corretamente não |
| Entrada "Vincular mídia perdida…" no menu de contexto do cartão de mídia | `MediaAssetsTab.qml` | Feito. Não testado com mouse |
| Comandos `list_missing_media` e `relink_media` para o agente | `McpDispatcherExtended.cpp`, `McpCatalogExtendedOps.inl` | Feito |

Notas:

- O tracejado e o pontilhado do traço já existiam no Drift (campo "Dash" de cada camada de traço), então não entraram nesta leva.
- A linha é um contorno fechado (barra mais pontas), preenchido como as outras formas. O tracejado da camada de traço contorna a linha; não a transforma numa linha tracejada, como no CapCut.
- As pontas da linha têm a altura da caixa e o mesmo comprimento, limitadas a 45% da largura. Os valores do CapCut não foram lidos.
- O raio por canto não tem quadro-chave; o raio único continua tendo.
- Defeito antigo corrigido de passagem: quando a miniatura de uma mídia ficava pronta depois de os clipes estarem na timeline (mídia revinculada, cache apagado), só o painel de mídia a recebia e os clipes ficavam em branco até reabrir o projeto. Agora os clipes que estão esperando recebem.
- Diferenças para o CapCut na revinculação: as colunas não são ordenáveis; o diálogo não se oferece ao exportar; o cartão de mídia não ganhou o selo vermelho de "mídia perdida"; não há os quatro estados (perdida, sem acesso, danificada, formato incompatível), só "arquivo não existe".
- O seletor de arquivo e o clique em "Vincular mídia…" não foram testados com mouse; a função por trás foi.

Suítes: núcleo 129, editor 142 (3 puladas), agente 111 (5 puladas), motor 137 (71 puladas, por falta de GPU no modo de teste).

## Décima leva: os itens médios (2026-10-10)

Itens 8, 9, 11, 13 e 14 da lista da 9.5. Commits `b142960f`, `9eafc006`, `18dd1786`, `71b5cbc6` e `ca51ebc8`.

| Item | Onde | Situação |
|---|---|---|
| Réguas no preview (topo e esquerda, 16 px, em pixels do projeto, acompanham zoom e deslocamento) | `components/preview/ReferenceLinesOverlay.qml`, preferência `rulersVisible` | Feito. Conferido na tela |
| Guias: arrastar a partir de uma régua cria; arrastar a guia move; soltar fora do quadro apaga; clique direito tem Excluir, Bloquear e Limpar; dica com a posição em px. Gravadas no projeto, até 50 por direção | idem; `AppController` (`referenceLinesV/H`, `addReferenceLine`, `moveReferenceLine`…), chave `referenceLines` no arquivo | Feito. Desenho conferido na tela; teste `referenceLinesPersistWithProject`. **Arrastar com mouse não testado** |
| Encaixe dos objetos nas guias ao mover e redimensionar no preview | `TransformOverlay.qml` (`snapTargetsX/Y`) | Feito. Não testado com mouse |
| Opções "Réguas", "Minhas guias", "Bloquear guias" e "Limpar guias" no menu de guias da barra do preview | `PreviewToolbar.qml` | Feito |
| Exportar clipes selecionados: um arquivo por clipe, na ordem da timeline, "título 01", "título 02"…; vídeo e áudio vinculados contam como um; opção "Só o clipe, sem as outras faixas" (marcada por padrão) | `AppController::exportSelectedClips`, `components/BatchExportDialog.qml`; menu do clipe e menu "mais" da barra | Feito. Conferido de ponta a ponta: dois clipes, dois arquivos (12 s e 8 s), cada um só com o seu clipe |
| Vinculação à faixa principal configurável: seta ao lado do ímã da faixa principal abre a lista de tipos (camada de vídeo, texto, legendas, formas e adesivos, efeitos e ajustes, áudio). Quando o ímã move um clipe da faixa principal, o que começa sobre ele nos tipos marcados vai junto | `AppController::compactTrackGaps` (`carryLinked`), `mainTrackLinkage`, `TimelineToolbar.qml` | Feito. Teste dentro de `mainTrackMagnetClosesGaps` |
| Remover pausas com revisão: escolhe-se a duração mínima (0,1 a 100 s), "Localizar pausas" lista cada trecho com início, fim e duração (clicar leva a agulha até lá) e o total a cortar; "Remover" corta e fecha os espaços num passo de desfazer | `components/RemovePausesDialog.qml`, `AppController::findPauses`, `removePauses` (sobre as rotinas de silêncio que o agente já usava) | Feito. Conferido com um áudio de teste: 2 pausas listadas (1,3 s e 0,8 s) e cortadas |
| Máscara: raio dos cantos no retângulo e Expandir (−20% a 20% do lado menor do quadro) em retângulo, elipse, estrela, coração e forma livre | `Mask.h` (`cornerRadius`, `expand`), `MaskApplier.cpp`, `MasksInspector.qml` | Feito. Conferido na tela; teste `maskCornerRadiusAndExpand` |
| Comandos novos do agente: `set_reference_lines`, `export_selected_clips`; `cornerRadius` e `expand` em `set_mask` | catálogo e despachante | Feito |

Notas:

- **Mudança de comportamento:** com o ímã da faixa principal ligado, títulos, legendas, formas, efeitos e vídeos sobrepostos que começam sobre um clipe da faixa principal agora andam com ele. O áudio fica de fora por padrão. Dá para desmarcar tudo na seta ao lado do ímã. O que **não** foi feito: apagar o item junto quando o clipe da faixa principal é apagado.
- Exportação em lote usa as configurações da última exportação normal; a janela não repete resolução e codec. Não grava nada nas "últimas configurações".
- "Exportação em segundo plano" o Drift já tinha em parte: a exportação roda fora da interface e o diálogo de progresso pode ser dispensado, ficando um selo ao lado de Exportar. Não há fila nem central de tarefas.
- Remover pausas: só pausas. Palavras de preenchimento e repetições dependem da transcrição por palavra e ficaram com a edição por transcrição (item 17). Não dá para desmarcar uma pausa da lista; ajusta-se a duração mínima.
- Máscaras: a pilha de várias máscaras por clipe já existia. Raio e expansão não têm quadro-chave. Máscara de ajuste e de efeito (a mesma tela em três lugares) e rastrear máscara não foram feitas.
- Guias: o diálogo "Editar guia" (posição digitada, pixels ou porcentagem) não foi feito; a posição aparece na dica enquanto se arrasta.

Suítes: núcleo 129, motor 138 (71 puladas), editor 143 (3 puladas), agente 111 (5 puladas).

## Décima primeira leva: sugestões e os itens grandes (2026-10-10)

Itens 10, 15, 16 e 17 da lista da 9.5. Commits `2cd78641`, `0b662ef0`, `1ec56421` e `347fc797`.

| Item | Onde | Situação |
|---|---|---|
| Sugestões inteligentes (Menu › Sugestões inteligentes…): "Analisar projeto" mede cada clipe com som e mostra dois cartões. "Uniformizar o volume": clipes a mais de 2 LU de −16 LUFS, com o valor de cada um; Aplicar leva todos a −16. "Remover as pausas": pausas de 0,5 s ou mais por clipe; Aplicar corta todas. Cada Aplicar é um único desfazer | `components/SuggestionsDialog.qml`, `AppController` (`soundClips`, `clipLoudness`, `normalizeClipsVolume`, `removePausesFromClips`) | Feito. Conferido na tela com quatro clipes; os botões Aplicar não foram clicados (as rotinas por trás são as do agente, já testadas) |
| Timelines em abas: acima da barra da timeline, "Timeline principal" e uma aba por clipe composto; clicar abre aquela timeline (ou volta à principal). Só aparece quando existe algum composto | `AppController::timelineTabs`, `openTimelineTab`, `TimelinePanel.qml` | Feito. Conferido na tela; teste dentro de `compoundClipEnterEditExitAndDissolve` |
| Cortar um trecho de tempo: divide todas as faixas nas duas pontas, remove o que fica no meio e fecha tudo o que vem depois pelo mesmo tanto; imagem, som e legendas continuam em sincronia. Um desfazer | `AppController::cutTimeRange`, `splitAllTracksAt`; comando `cut_time_range` | Feito. Teste `cutTimeRangeClosesEveryTrack`; conferido na tela |
| Edição pelo texto: no editor de legendas, a tesoura ao lado da lixeira corta do vídeo o trecho daquela legenda. Com legendas geradas palavra por palavra, apagar uma palavra corta o vídeo | `SubtitleEditor.qml` (`cutCueFromVideo`) | Feito sobre a rotina acima. O clique no botão não foi testado |
| Gravar (Menu › Gravar…): microfone, tela ou câmera; o arquivo vai para Vídeos/Drift, é importado e entra numa faixa nova na posição da agulha | `components/RecordDialog.qml` (QtMultimedia), `AppController::newRecordingUrl`, `discardEmptyRecording` | **Microfone: feito e conferido** (3 s gravados e postos na timeline). **Tela: não funcionou no meu ambiente de teste** (sessão X11 dentro do sandbox: nenhum quadro chegou; o programa avisa e não guarda arquivo). Na sessão Wayland real a captura passa pelo portal do sistema e pode funcionar; não verifiquei. **Câmera: não testada**, e o Flatpak hoje não libera o dispositivo |

Notas:

- Sugestões: só volume e pausas são medidos. As sugestões visuais do CapCut (nitidez, cor, estabilizar, rosto) dependem de medidas que o Drift não tem e não foram feitas. Não há o botão "Remover" por sugestão; o desfazer normal cobre.
- Um clipe muito baixo era lido inteiro como "pausa" pelo limiar fixo de silêncio. Agora, se mais de 60% do clipe é silêncio, ele não entra na sugestão, e o diálogo "Remover pausas" avisa e não corta.
- A leitura do áudio roda o laço de eventos enquanto espera; um temporizador repetitivo reentrava na mesma medição até estourar a pilha. O painel usa temporizador de disparo único, rearmado ao fim de cada clipe.
- Abas: listam só os compostos da timeline principal (não os aninhados). Trocar de aba com mudanças pendentes re-renderiza o composto que se deixa; se a renderização estiver em andamento, é preciso clicar de novo depois. Não há "nova timeline vazia": cria-se pelo "Criar clipe composto".
- Cortar trecho recusa quando há faixa travada (ela ficaria fora de sincronia) e quando algum clipe sob o trecho não pode ser dividido, em vez de apagar o clipe inteiro.
- Para liberar a câmera no Flatpak: `flatpak override --user --device=all org.cutwire.Drift`.

## O que ficou de fora da lista da 9.5

| Item | Motivo |
|---|---|
| 18. Proxy e otimização automática | Não feito. O Drift já tem a qualidade de preview (Total, Metade, Um quarto, Auto) e a decodificação por GPU, que cobrem boa parte do uso. Gerar arquivos proxy é um trabalho próprio no motor |
| 19. Painel de chat do agente | Não feito. O Drift expõe as ferramentas para um agente externo, mas não tem um modelo de linguagem embutido nem credenciais para um; um painel de chat precisa primeiro dessa decisão (qual modelo, com que chave) |
| 20. Ferramenta caneta e editor de gráficos | Não feito. É desenho vetorial no preview (pontos, curvas, edição posterior), sem base pronta além da máscara de forma livre |
| Do 14: máscara de ajuste e de efeito, rastrear máscara | Não feitos (ver décima leva) |
| Do 17: painel de transcrição com texto corrido, palavras de preenchimento e repetições | Não feitos; ficou o corte por legenda |
| Do 9: fila de exportações e central de tarefas | Não feitos |

Suítes ao fim: núcleo 129, motor 138 (71 puladas), editor 144 (3 puladas), agente 111 (5 puladas).

## Correção depois da primeira instalação

As listas suspensas abriam com os itens em branco. Causa: o item de lista (`ItemDelegate`) tem 12 px de preenchimento vertical próprio do estilo; com a altura reduzida para 24 px o texto ficava com altura zero. Corrigido em `ThemedComboBox.qml` (linha de 28 px, preenchimento vertical zero) e, por precaução, em `ThemedMenuItem.qml`. Os botões Reta/Suave/Salto ganharam largura pelo texto. Conferido na tela com a lista de velocidade e o menu principal abertos.

Lição: depois de mexer em densidade, abrir pelo menos uma lista suspensa e um menu antes de instalar. Para capturá-los sem mouse, pôr um `Timer` temporário que chama `popup.open()` e remover em seguida.

## Ciclo rápido de desenvolvimento

A compilação completa pelo flatpak-builder leva de 10 a 25 minutos. Para iterar há três scripts em `~/.cache/drift-build/dev/`:

- `drift-dev build [alvo]`: copia o fonte para a árvore `state/build/drift-10` e roda o `ninja` dentro do sandbox do Flatpak. Segundos por mudança de QML.
- `drift-dev test <suíte> [casos]`: roda uma suíte de teste.
- `drift-shot saida.png [espera]`: abre o Drift de desenvolvimento em X11, captura a janela e fecha. Variáveis: `DRIFT_ARGS` (projeto a abrir) e `DRIFT_MCP_SCRIPT` (script que comanda a janela pelo acesso de agente antes da captura, por exemplo para selecionar um clipe).

Projeto e mídias de teste ficam em `~/.cache/drift-build/dev/proj/`.

Cuidados descobertos:

- A base de compilação é `dev/appdir`, extraída do cache do flatpak-builder (estágio `build-drift`), porque o `build-main` final não tem mais os cabeçalhos.
- A árvore de build é fixa (`drift-10`). Escolher "a mais recente" por data pega a árvore errada depois de uma sincronização.
- A sincronização não pode apagar a pasta `juce`, que o flatpak-builder baixa para dentro da árvore.
- A captura de tela sai em RGB; não trocar canais.
- Clique sintético (XTEST) não funciona nesta sessão gráfica; usar o acesso de agente.
- Nunca rodar `flatpak kill org.cutwire.Drift` com uma compilação completa em andamento: o sandbox do flatpak-builder usa o mesmo id e a compilação morre com código 137. O `drift-shot` fecha só as instâncias que ele mesmo abriu.

## Problema de ambiente encontrado

O driver NVIDIA do sistema estava na versão 615.71.09 e o Flatpak só tinha as extensões 595 e 610. Sem a extensão certa, os apps Flatpak (o Drift inclusive) abrem sem aceleração em X11. Foi instalada `org.freedesktop.Platform.GL.nvidia-615-71-09`. A cada atualização do driver do sistema, rodar `flatpak update`.

## Pendente, pela ordem do índice de `capcut-re/README.md`

1. Linha de parâmetro: grupos recolhíveis com caixa de ativação; os botões de interpolação (Reta/Suave/Salto) ficaram apertados com a fonte nova e precisam de ajuste de largura.
2. Timeline: clipe de vídeo em três camadas (rótulos, miniaturas, onda) como no CapCut; hoje a linha de volume aparece em clipes de áudio e em vídeo no modo forma de onda.
3. Painel de materiais: lateral de categorias em árvore, cartão de 86 px com "+" e estrela no hover, selo "Adicionado", mídia perdida com revinculação.
4. Exportação: campos de nome e pasta na própria janela (hoje a pasta é escolhida no diálogo de arquivo depois de clicar em Exportar).
5. Cor: editor de curva e rodas desenhados, e HSL/LUT dentro da aba Ajuste (hoje são efeitos em Efeitos › Cor).
6. Corte por clipe, fundo por clipe, medidor de áudio, janela única de ajustes do projeto.
7. Painéis destacáveis e menu Layout.
8. Importar projeto do CapCut.
