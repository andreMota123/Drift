# Comparativo Drift × CapCut

Levantamento de 2026-10-07. Objetivo: deixar o Drift o mais parecido possível com o CapCut em funções e aparência.

> Em 2026-10-10 foi feito um levantamento detalhado de **como** o CapCut implementa cada parte (telas, medidas, cores, fórmulas, formato de projeto). Está em `capcut-re/README.md`.

## De onde vêm os dados

- **CapCut 3.9.0.1459** (2024): instalado no Wine em `~/capcut/prefix39`. É a última versão que roda em Wine.
- **CapCut 9.5.0.4050** (atual): não roda em Wine. Foi instalado num prefixo temporário só para copiar o catálogo de textos.
- Os catálogos de textos da interface das duas versões estão em `~/capcut/catalogos/` (pt-BR e inglês). São material do CapCut: servem de referência e não entram no repositório do Drift.
- **Drift**: ramo `compound-clips`, conferido no código, função por função.

A versão 3.9 tem 8.648 textos de interface e a 9.5 tem 15.416. Quase tudo que entrou é IA generativa que roda nos servidores do CapCut (avatares, gerar imagem e vídeo, roteirista, montagem automática, B-roll automático). As novidades de edição propriamente dita são poucas e estão marcadas com "9.5" na tabela.

## Funções

Legenda: **Tem**, **Parcial**, **Falta**, **Só agente** (existe no motor e nas ferramentas do agente, mas sem botão na interface).

| Função do CapCut | Drift | Observação |
|---|---|---|
| Quadros-chave e gráfico | Tem | Posição, tamanho, rotação, opacidade, volume, máscara e qualquer parâmetro de efeito |
| Velocidade constante, curva, reverso, congelar quadro | Tem | |
| Câmera lenta por fluxo óptico (9.5) | Falta | |
| Máscaras | Tem | Retângulo, elipse, estrela, coração, barras, forma livre, mídia; suavização e inversão |
| Máscara de ajuste e de efeito (9.5) | Falta | |
| Modos de mesclagem | Parcial | 7 modos; o CapCut tem mais |
| Transições | Tem | 28 no pacote |
| Efeitos e filtros | Tem | 57 no pacote, numa biblioteca só |
| Modelos de efeito sincronizados com a batida | Tem | 23 no pacote |
| Texto, estilos, animações de texto | Tem | 47 animações |
| Modelos de texto (vários elementos) | Falta | |
| Adesivos e emoji | Parcial | Depende de pacote baixável |
| Formas | Tem | 28 tipos |
| Animação de clipe (entrada, saída) | Parcial | 11 tipos; sem combinada nem em laço |
| Chroma key | Tem | |
| Remover fundo (pessoas) | Tem | Local, Robust Video Matting |
| Recorte de objeto por clique | Tem | Local, SAM2 |
| Recorte com pincel | Falta | |
| Rastreamento de objeto, texto ou adesivo preso ao movimento | Parcial | Só rosto, e recorte propagado |
| Legendas automáticas | Tem | Local, Whisper |
| Importar e exportar SRT | Tem | |
| Legenda bilíngue e tradução (9.5) | Falta | |
| Modelos de legenda | Falta | Usa os estilos de texto |
| Texto para fala | Falta | |
| Redução de ruído | Tem | Local, DeepFilterNet3 |
| Trocar voz, tom | Tem | 6 vozes |
| Isolar voz, aprimorar voz | Falta | |
| Normalizar volume, remover silêncio, ducking | Só agente | Falta o botão |
| Equalizador, compressor, limitador | Tem | O CapCut 3.9 não tem |
| Fade de áudio, separar áudio, volume por quadro-chave | Tem | |
| Marcar batidas | Tem | No gráfico de quadros-chave; marcar na timeline é só agente |
| Marcadores na timeline | Tem | |
| Gravar narração | Falta | |
| Gravar tela (9.5) | Falta | |
| Cor: brilho, contraste, saturação, temperatura, matiz, gama | Tem | |
| Cor: LUT, curvas, rodas de cor, HSL, ajuste automático | Falta | |
| Camada de ajuste na timeline | Tem | |
| Beleza facial e de corpo | Falta | Só efeitos de brincadeira |
| Estabilização | Tem | |
| Proxy para vídeo pesado | Falta | Só qualidade de pré-visualização reduzida |
| Clipe composto | Tem | |
| Multicâmera | Tem | O CapCut 3.9 não tem |
| Vincular e desvincular clipes | Tem | |
| Agrupar clipes | Falta | |
| Faixa principal magnética | Falta | Há "fechar lacunas ao cortar" |
| Pré-visualização ao passar o mouse | Falta | |
| Travar faixa | Falta | O campo existe, falta o botão |
| Encaixe, silenciar e ocultar faixa, ajustar zoom | Tem | |
| Cortar, girar, espelhar, fundo desfocado ou cor | Parcial | Sem corte por clipe e sem imagem de fundo |
| Proporções prontas | Tem | 17 |
| Reenquadramento automático | Só agente | |
| Detecção de cenas | Tem | Dividir nas cenas é só agente |
| Vídeo longo em curtos | Falta | |
| Editor de capa | Falta | |
| Guias e réguas (9.5), capítulos (9.5), mosaico (9.5) | Falta | |
| Copiar e colar atributos | Tem | |
| Exportação | Tem | Mais codecs que o CapCut; GIF e só áudio |
| Exportar quadro como imagem | Só agente | |
| Exportar HDR | Falta | |
| Salvamento automático e recuperação | Tem | |
| Nuvem, espaços de equipe | Falta | |
| Modelos de projeto, acervo de músicas, efeitos e adesivos | Falta | Conteúdo licenciado dos servidores do CapCut |
| IA generativa (avatares, imagem, vídeo, roteiro) | Falta | Roda nos servidores do CapCut |

## O que não dá para igualar

- **Acervo e nuvem**: modelos, músicas, efeitos e adesivos do CapCut são conteúdo licenciado, baixado dos servidores deles.
- **IA generativa do CapCut**: roda nos servidores deles. Equivalentes locais (texto para fala, isolar voz, tradução de legenda) são possíveis com a placa de vídeo, com resultado parecido e não idêntico.
- **Ícones, imagens e marca**: não podem ser copiados. O Drift é GPL e não pode embutir material do CapCut. O que se copia é a organização da tela, as cores e o fluxo de trabalho.

## Aparência

Cores medidas na janela do CapCut 3.9: destaque `#00C1CD`, painel `#1B1B1C`, cabeçalho de painel `#29292D`, fundo `#070709`.

| Parte da tela | CapCut | Drift antes | Situação |
|---|---|---|---|
| Cor de destaque | Ciano | Âmbar | Feito (ramo `capcut-style`) |
| Painel de recursos | Abas no topo, ícone e nome | Trilho vertical só de ícones | Feito (ramo `capcut-style`) |
| Painel de propriedades | Abas de texto no topo | Trilho vertical de ícones | A fazer |
| Cabeçalho | Menu à esquerda, nome no centro, Exportar à direita | Projetos, Salvar, Vídeo, Ajustes, Exportar | A fazer |
| Barra da timeline | Desfazer, dividir, apagar à esquerda; ímã, vínculo, zoom à direita | Parecida, com mais botões | A revisar |
| Ordem das abas | Mídia, Áudio, Texto, Adesivos, Efeitos, Transições, Legendas, Filtros, Ajuste, Modelos | Mídia, Market, Texto, Legendas, Adesivos, Formas, Máscaras, Cenas, Efeitos, Modelos, Transições, Áudio FX, Atalhos | A fazer |

## Ordem sugerida para as funções que faltam

Primeiro o que já existe no motor e só precisa de botão, depois o que precisa ser escrito.

1. Botões para o que é "só agente": normalizar volume, remover silêncio, ducking, dividir nas cenas, marcar batidas na timeline, exportar quadro, reenquadramento automático, travar faixa.
2. Gravar narração.
3. Cor: LUT e curvas.
4. Faixa principal magnética e pré-visualização ao passar o mouse.
5. Proxy.
6. Agrupar clipes, corte por clipe, imagem de fundo.
7. Texto para fala e isolar voz, locais.
8. Rastreamento de objeto.
9. Fluxo óptico, tradução de legenda, editor de capa.
