# Função Juntar: transformar a seleção em um só vídeo

## O pedido

Selecionar clipes em faixas de vídeo ou áudio e transformá-los num único vídeo na timeline.

## Como funciona

O Drift tem um exportador interno que renderiza um projeto, ou um trecho dele, exatamente como a prévia mostra. A função reaproveita esse exportador:

1. Com dois ou mais clipes selecionados, em qualquer faixa, o Drift monta uma cópia do projeto contendo só esses clipes. Faixas, ordem de empilhamento, efeitos e transições entre eles ficam iguais; tudo o mais é removido.
2. Essa cópia é renderizada em segundo plano, só no intervalo que os clipes ocupam, num arquivo MP4 (H.264 e AAC) guardado na pasta de mídia do projeto, ao lado dos quadros congelados.
3. Quando termina, os clipes originais saem da timeline e entram como um único clipe de vídeo, com o áudio embutido, no mesmo ponto e com a mesma duração. Ele vai para a faixa de vídeo mais à frente de onde a seleção estava.
4. Desfazer (Ctrl+Z) devolve os clipes originais. O arquivo renderizado permanece na biblioteca de mídia.

## Como usar

1. Clique no primeiro clipe. Segure Shift e clique nos demais. Pode misturar faixas de vídeo, áudio, texto e formas.
2. Pressione **Ctrl+Shift+J**, ou clique no ícone de camadas na barra da timeline, ou use o botão direito e "Juntar em um só vídeo".
3. Uma mensagem "Juntando os clipes…" aparece. A renderização leva alguns segundos por minuto de vídeo, dependendo da resolução do projeto.

Enquanto a renderização roda, a edição continua livre. A ação fica desativada até terminar, e também durante uma exportação, porque as duas usam o mesmo motor.

## Diferença para "Merge adjacent clips"

A função Merge do Drift só une dois clipes vizinhos, da mesma faixa e do mesmo arquivo de origem, sem renderizar nada. A função Juntar aceita qualquer combinação e gera um arquivo novo.

## Arquivos alterados

| Arquivo | Mudança |
|---|---|
| `src/core/TimelineOps.h/.cpp` | `restrictProjectToClips`: a cópia do projeto só com os clipes escolhidos, mais o intervalo que cobrem |
| `src/models/AppController.h/.cpp` | `canCombineSelection`, `combineSelectionToClip`, `cancelCombine`; propriedades `combineAvailable`, `combineInProgress`, `combineProgress`; ação `combine` com atalho; caminho do arquivo gerado |
| `src/qml/components/timeline/TimelineToolbar.qml` | botão de camadas e item no menu de mais ações |
| `src/qml/components/timeline/TimelineClipItem.qml` | item no menu do clipe |
| `src/mcp/*` | comando `combine_clips` para o agente interno |
| `tests/tst_core.cpp` | teste da cópia restrita: clipes de fora somem, transição só sobrevive com as duas pontas, intervalo correto |
| `tests/tst_editorstate.cpp` | teste que renderiza duas formas em duas faixas e confere que sobra um clipe de vídeo de 3 s. Pula quando não há GPU ou codificador |
| `i18n/*.ts` | sete frases novas em todos os catálogos, traduzidas em pt_BR |

## Verificação

Compilado sobre o `main` do projeto oficial dentro do SDK do KDE 6.11, com o Skia.

| Teste | Resultado |
|---|---|
| Núcleo, `restrictProjectToClipsKeepsOnlySelection` | passou |
| Editor, `combineSelectionRendersOneClip`, com GPU pela Wayland | passou: gerou MP4 H.264/AAC de 3 s e deixou um único clipe de vídeo |
| Suíte do editor completa, 136 testes | todos passaram, 3 pulados por falta de GPU no sandbox |
| Suíte do núcleo, 127 testes | 126 passaram; a única falha é um teste antigo que procura um arquivo de dados num caminho que só existe dentro do sandbox de compilação |

Para rodar o teste de renderização com GPU, o sandbox precisa do socket Wayland:

```bash
B="$HOME/.cache/drift-build/state/build/drift-5/build"; flatpak run --devel --command=sh --filesystem=host --socket=wayland --device=dri --env=QT_QPA_PLATFORM=wayland org.cutwire.Drift//master -c "cd '$B' && ./tests/tst_editorstate combineSelectionRendersOneClip"
```

## Limites conhecidos desta versão

- Não há barra de progresso própria ainda. O progresso existe internamente (`combineProgress`) e pode ganhar uma interface depois.
- A renderização usa as configurações padrão de exportação: resolução do projeto, H.264 com qualidade CRF 18, AAC 192 kbps.
- Se um clipe de áudio selecionado estiver em faixa silenciada, o silêncio é respeitado, igual à prévia.
