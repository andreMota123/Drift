# Filtro de maquiagem ao estilo do Instagram

Pesquisa e plano, 2026-10-15. **Etapa 1 feita no mesmo dia** (commits `84e2ab0a` e `c073130f`, ramo `capcut-style`); veja "Etapa 1: como ficou" no fim.

## O que o Drift já tem

Mais do que parece. Na categoria **Beleza e maquiagem** dos efeitos (pacote `effects.core`), todos guiados pelo rastreamento de rosto que o Drift já faz (detector YuNet + malha de 468 pontos do MediaPipe, com contornos de lábios, olhos, pálpebras e sobrancelhas):

| Efeito | O que faz |
|---|---|
| **Face Retouch** | Pele lisa (filtro que preserva bordas), clarear, tom de pele, afinar rosto, aumentar olhos, batom e blush com cor livre. É uma tradução do GPUPixel (Apache-2.0) para os shaders do Drift. |
| Eyeliner | Cor, espessura, gatinho, opacidade. |
| Eyeshadow (sombra) | Cor, intensidade, espalhamento, suavidade. |
| Brow Tint (sobrancelha) | Cor, força, densidade, suavidade. |
| Eye Colour (cor dos olhos) | Cor, força, brilho, preserva a pupila. |
| Teeth Whiten (dentes) | Clarear e brilho. |
| Ajustes de cor e LUT | O "clima" de cor que todo filtro do Instagram tem. |

O efeito precisa de rosto detectado no clipe (o Drift avisa quando o clipe foi analisado antes da maquiagem existir e pede para detectar de novo).

## O que falta para ficar igual ao Instagram

1. **Looks prontos com um toque.** No Instagram a pessoa escolhe "Natural", "Glam", "Noite" e mexe num só controle de intensidade. No Drift hoje são seis efeitos separados, cada um com quatro ou cinco controles.
2. **Cílios / rímel.** Não existe.
3. **Contorno e iluminador.** Não existe.
4. **Acabamento do batom:** matte, gloss (brilho), cintilante. Hoje o batom é só cor.
5. **Sardas e brilho de pele** (efeitos "glow"), opcionais.
6. **Máscara exata de lábios e pele** (opcional): hoje o batom é um molde desenhado sobre a malha; com boca aberta ou ângulo forte pode borrar dentes ou pele.

## O que existe no GitHub

| Projeto | Licença | Serve para | Veredito |
|---|---|---|---|
| [GPUPixel](https://github.com/pixpark/gpupixel) (pixpark, 2,4 mil estrelas, ativo) | Apache-2.0 | Pele, clarear, afinar, batom, blush em tempo real (C++/OpenGL) | **Já está no Drift** (o Face Retouch veio dele). Referência para qualquer ajuste. |
| [OpenMakeupSDK](https://github.com/ehsanwwe/OpenMakeupSDK) (2026, web) | MIT | Base, batom, blush, sombra, delineado, **rímel**, acabamentos **matte/gloss/cintilante/glitter**, 73 texturas de padrão | **Melhor fonte** para o que falta: cílios e acabamentos. Licença permite copiar e adaptar os shaders e texturas com o aviso de direitos. Projeto pequeno (18 estrelas): usar como referência, não como dependência. |
| [MediaPipe](https://github.com/google-ai-edge/mediapipe) | Apache-2.0 | Malha de 468 pontos | **Já está no Drift.** |
| [yakhyo/face-parsing](https://github.com/yakhyo/face-parsing) (BiSeNet, ONNX) | MIT (código) | Máscara por pixel de pele, lábios, olhos, cabelo, dentes (19 classes) | Bom para o item 6, roda no mesmo ONNX Runtime do Drift (agora com CUDA). Atenção: os pesos foram treinados no CelebAMask-HQ, base de dados de uso não comercial; para uso pessoal tudo bem, para distribuir conferir. |
| [face-parsing.PyTorch](https://github.com/zllrunning/face-parsing.PyTorch) | MIT | O mesmo, original | Parado desde 2023; o yakhyo já exporta para ONNX. |
| [PSGAN](https://github.com/wtjiang98/PSGAN) | MIT (código) | Copiar a maquiagem de uma foto de referência | Não recomendado: lento, pisca de quadro a quadro em vídeo, pesos treinados em base de pesquisa. |
| [EleGANt](https://github.com/Chenyu-Yang-2000/EleGANt) | CC BY-NC-SA 4.0 | O mesmo | **Não usar:** proíbe uso comercial e obriga a mesma licença. |
| [BeautyGAN](https://github.com/Honlan/BeautyGAN) | Sem licença | O mesmo | **Não usar:** sem licença, nada pode ser copiado. |

Fontes de apoio: [voxa_beauty](https://pub.dev/packages/voxa_beauty) e [utd_video_effects_kit](https://pub.dev/packages/utd_video_effects_kit) (Flutter, MediaPipe; o segundo tem contorno e iluminador, boa referência de onde aplicar), e o [artigo da Fora Soft](https://www.forasoft.com/learn/ai-for-video-engineering/articles-ai/beauty-filters-gaze-correction-ar-effects-mediapipe) sobre filtros de beleza com MediaPipe.

## Como implantar (em ordem)

### Etapa 1: Looks de maquiagem (1 dia, sem IA nova)

- Um seletor **Maquiagem** no painel de efeitos, com cartões de looks: Natural, Pele perfeita, Glam, Noite, Bronze, Rosado, Batom vermelho, Sem maquiagem.
- Cada look é um arquivo JSON que lista os efeitos que já existem e seus valores (Face Retouch, Eyeliner, Eyeshadow, Brow Tint, Teeth Whiten e uma LUT de cor).
- Um só controle **Intensidade** (0 a 100%) escala todos os valores juntos; "Personalizar" abre os efeitos individuais.
- Aplicar um look é um único passo de desfazer e substitui o look anterior no clipe.
- Comando para o agente (`apply_makeup_look`), para o Claude e o Assistente aplicarem pelo nome.
- Modelo de interface: o seletor de estilos de texto que já existe (`TextLookPicker.qml`).

### Etapa 2: o que falta, como efeitos novos (2 a 3 dias)

Pacotes de efeito novos na pasta `effects/` do nosso ramo, no mesmo formato dos que existem (`effect.json` + shaders), usando os contornos que o rastreamento já entrega:

- **Cílios / rímel:** faixa com textura de cílios ao longo do arco da pálpebra superior (`kEyeLeftUpper`/`kEyeRightUpper`), com volume e comprimento. Texturas e ideia do rímel do OpenMakeupSDK (MIT).
- **Acabamento do batom:** matte, gloss e cintilante, por brilho especular dentro do contorno dos lábios. Técnica do OpenMakeupSDK.
- **Contorno e iluminador:** manchas suaves posicionadas pela malha (maçãs do rosto, laterais do nariz, mandíbula, testa), escurecendo em "multiplicar" e clareando em "tela".
- **Sardas** (opcional): textura presa à malha.

Os looks da etapa 1 passam a usar esses efeitos também.

### Etapa 3: máscara exata com IA (2 dias, opcional)

- BiSeNet (yakhyo/face-parsing) em ONNX, analisado junto com a detecção de rosto e guardado com o rastreamento, como já é feito com os contornos.
- O batom passa a respeitar exatamente os lábios (sem pintar dentes com a boca aberta), e a pele lisa deixa de borrar cabelo, olhos e sobrancelhas.
- Só vale a pena se a etapa 1 mostrar o problema nos vídeos reais.

### O que fica de fora

Copiar a maquiagem de uma foto (PSGAN, EleGANt, BeautyGAN): licenças ruins ou ausentes, lento e instável em vídeo. Os looks prontos resolvem o mesmo desejo com resultado previsível.

## Como testar

- Um vídeo real de rosto (as gravações da Maianna servem), de frente e de lado, falando (boca abrindo).
- Conferir com captura de tela, como no aprimoramento: batom não sai dos lábios, cílios acompanham o piscar, intensidade 0% devolve o original.
- Suítes do núcleo e do editor; teste novo para o look (aplicar, trocar, desfazer).

## Etapa 1: como ficou (2026-10-15)

### Como usar

1. Selecione o clipe de vídeo (ou imagem) com o rosto.
2. Painel de propriedades › **Vídeo** › sub-aba **Maquiagem**.
3. Toque num look: Natural, Pele perfeita, Glam, Noite, Bronze, Rosado ou Batom vermelho. Na primeira vez o Drift detecta os rostos do clipe.
4. **Intensidade** (0 a 100%) aumenta ou diminui o look inteiro. **Remover maquiagem** tira tudo. Ctrl+Z desfaz cada troca de uma vez.
5. Para ajustar só a cor do batom ou a espessura do delineado, selecione a faixa de efeitos acima do clipe: o look é feito daqueles efeitos.

Pelo agente (Claude ou Assistente): `apply_makeup_look` com `look` e `intensity` (0 a 1); `look: "none"` remove.

### Como funciona

- **Os looks são dados:** `presets/makeup-looks/looks.json` diz, para cada look, os valores do Face Retouch, delineado, sombra, sobrancelha e dentes, e quais parâmetros são "quantidade" (`amountKeys`). A intensidade multiplica só esses; cores, formatos e suavizações ficam como o look define. Para criar um look novo basta acrescentar no arquivo (e o nome traduzido em `makeupLookLabel`, no `AppController.cpp`).
- **Aplicar** grava os efeitos na faixa de efeitos do clipe (a mesma do "Adicionar efeito"), marcados com `makeupLook` e `makeupIntensity`. Um look novo substitui os efeitos marcados e também qualquer efeito de beleza do mesmo tipo posto à mão, para não alisar a pele duas vezes. É um único passo de desfazer.
- Código: `src/core/MakeupLooks.*`, `AppController::applyMakeupLook` e `removeMakeupLook`, `MakeupInspector.qml`, aba "makeup" no `PropertiesPanel.qml`.
- Testes: `makeupLooksParseAndScale` (núcleo) e `makeupLookReplacesScalesAndUndoes` (editor). Suítes: núcleo 130, editor 148, agente 113, motor 138.

### Dois problemas encontrados no teste

1. **Detecção de rosto não funcionava neste PC** (commit `84e2ab0a`). No automático o detector rodava no WebGPU, que falha na placa NVIDIA ("Invalid ShaderModule Conv2dMM"), e o Drift dizia "Nenhum rosto encontrado". Isso valia para todos os efeitos de rosto, não só a maquiagem. Agora, com o motor da NVIDIA carregado, os modelos usam CUDA primeiro.
2. **Batom e blush não aparecem.** O Face Retouch instalado (pacote `effects.core`, baixado do Drift oficial) desenha batom e blush sobre uma malha de 111 pontos (`face111`), que o motor do nosso ramo ainda não tem: ela entrou no Drift oficial depois (commit `4e46243f`, versão 0.8.0). Pele lisa, clarear, sombra, delineado, sobrancelha e dentes funcionam; batom e blush ficam parados até trazermos a versão oficial nova para o nosso ramo (426 commits à frente, em 15/10).

### Teste visual

Vídeo de rosto real (C6298, recorte 1080×1920), captura do quadro pelo agente: pele mais lisa e clara em todos os looks, sombra e delineado no Glam, contornos acompanhando o rosto. O mapa de diferença confirmou os lábios sem mudança (problema 2). Imagem em `~/.cache/drift-build/dev/qualidade/` e no scratchpad da sessão.
