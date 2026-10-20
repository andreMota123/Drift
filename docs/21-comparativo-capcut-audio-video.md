# CapCut x Drift: áudio, vídeo, retoque e ajuste (2026-10-20)

Pesquisa feita a partir de 8 capturas do CapCut que o Andre mandou (painéis Áudio › Básico e Modificador de voz, Vídeo › Básico, Remover plano de fundo e Retoque, Ajuste › Básico, e a biblioteca de músicas). Compara com o Drift instalado (ramo `capcut-080`, commit `169717a7`) e lista o que existe no GitHub para cobrir o que falta. **Nada implementado ainda.** Licenças conferidas na API do GitHub em 20/10.

O Drift é GPL-3.0: código GPL/MIT/Apache/BSD pode entrar; licenças "não comercial" (NC, S-Lab) ou sem licença **não** podem ser embutidas.

## 1. Áudio (prioridade do Andre)

### Áudio › Básico

| CapCut | Drift hoje | Caminho |
|---|---|---|
| Volume, fade-in, fade-out com quadro-chave | **Tem** (Volume, Pan; fades na aba Velocidade/Fade; quadros-chave de efeitos de áudio na 0.8.0) | Juntar fades na aba Áudio, como no CapCut (só interface) |
| Normalizar nível de volume (clipe ou selecionados) | **Tem** no motor (`normalizeClipsVolume`, EBU R128) e nas Sugestões inteligentes | Pôr a caixa "Normalizar" na aba Áudio (só interface) |
| Aprimorar voz (intensidade) | Não tem | **ClearerVoice-Studio** / MossFormer2 48 kHz (Apache-2.0, 4,5 mil ★; pesos 222 MB) é o candidato principal. Alternativas: resemble-enhance (MIT; pesos 713 MB, o denoiser sozinho tem porte ONNX MIT de 40 MB) e VoiceFixer (MIT, restauração de fala). Rodar no ONNX Runtime do Drift (CUDA já funciona) |
| Reduzir ruído | **Tem** (DeepFilterNet v3, add-on instalado; licença MIT/Apache-2.0) | Pôr como caixa na aba Áudio |
| Isolar voz | Não tem | **Demucs** v4 (MIT, 10 mil ★; pesos htdemucs 84 MB) com o porte em C++ para ONNX Runtime **sevagh/demucs.onnx** (MIT), que encaixa direto no motor do Drift. Alternativa: modelos MDX/UVR via python-audio-separator (MIT; licença dos modelos UVR é separada) |
| Tradutor de vídeos (dublagem) | Tem as peças: Whisper (legendas), tradução de legendas com IA local (gemma4), TTS local (aba Fala, Chatterbox) | Juntar num fluxo "Traduzir vídeo": transcrever → traduzir → sintetizar com a voz → alinhar. Referência: **pyvideotrans** (GPL-3.0, 19 mil ★) |
| Preencher canal (mono → estéreo) | Não tem como opção | Simples no mixer (duplicar canal) |

### Áudio › Modificador de voz

| CapCut | Drift hoje | Caminho |
|---|---|---|
| Filtros de voz (~40: Eco, Megafone, Robô, Hélio, Profundo, Locutora, Distorcido…) | **Tem ~30** efeitos (voice_chipmunk/deep/robot/vader/alien/wobble, megafone, telefone, walkie, rádio abafado, eco, chorus, reverb…) e grafos de áudio JUCE na 0.8.0 | Montar **presets com os nomes e a grade do CapCut** (cartões com favorito) usando os efeitos e grafos que já existem; faltam reverb "igreja/super reverberação" e "voz mais nítida" (EQ+compressor) |
| Autotune / Foco no cantor | Não tem | **Rubber Band** (GPL-2.0+, compatível) para pitch com preservação de formante; correção de afinação estilo autotune: Autotalent (GPL-2) como referência |
| Personagens de voz (troca de voz por IA) | Não tem | **RVC** (MIT, 38 mil ★) — conversão de voz com modelos; pesado, avaliar ONNX. Evitar so-vits-svc (AGPL-3.0, arquivado em 2023) e w-okada/voice-changer (licença não declarada) |
| Fala em música | Não tem | **DiffSinger** da OpenVPI (Apache-2.0, ativo em 2026) sintetiza canto, mas precisa de partitura (notas e tempos); transformar fala em música exige gerar essa partitura. Por último |

### Biblioteca de músicas e efeitos sonoros

| CapCut | Drift hoje | Caminho |
|---|---|---|
| Música por categoria (Vlog, Phonk, Aniversário…), favoritos, baixar | Tem Mercado com aba SFX (0.8.0); as fontes vêm do servidor do Drift em tempo de execução | **Jamendo API** (Creative Commons, 500 mil faixas; grátis para app não comercial; licença por faixa, exige atribuição) é a única API de música viável hoje. A API do Pixabay só tem imagens e vídeos (a música do site não tem API). O Free Music Archive fechou em 2018 e está sendo reconstruído em 2026, sem API confirmada |

## 2. Vídeo › Básico

| CapCut | Drift hoje | Caminho |
|---|---|---|
| Transformar (escala, posição, girar, alinhar) | **Tem** (+ 3D na 0.8.0) | — |
| Mistura | **Tem** (modos de mesclagem) | — |
| Estabilização | **Tem** | — |
| Aprimorar qualidade | **Tem** (Real-ESRGAN, CUDA) e o oficial tem o seu ("Restore", com escolha de modelo) | Unificar os dois numa caixa só |
| Reduzir ruído de imagem | Parcial (Restore tem modelo de descompressão) | ffmpeg `nlmeans`/`hqdn3d` (rápido) ou modelo de denoise de vídeo |
| Fluxo óptico (câmera lenta suave) | Não tem | **Practical-RIFE** (MIT, ativo em 2026) → ONNX |
| Remoção de IA (apagar objeto) | Não tem | **LaMa** (Apache-2.0, imagem/quadro) + máscara do SAM2 que o Drift já tem; vídeo: **DiffuEraser** (Apache-2.0). Evitar ProPainter (S-Lab, não comercial) e MiniMax-Remover (sem licença) |
| Expansão por IA (aumentar o quadro) | Não tem | Outpainting com modelo de difusão local (ComfyUI já instalado neste PC) |
| Remix de IA / Estilização de IA | Não tem | ComfyUI (img2img por quadro-chave) — pesado, por último |
| Contato visual | Não tem | **LivePortrait** (agora KlingAIResearch/LivePortrait; código MIT, 19 mil ★). Por padrão detecta rostos com o InsightFace, cujos modelos são não comerciais; trocar pelo MediaPipe que o Drift já usa (há nó do ComfyUI que faz isso) |
| Sincronização labial | Não tem | **LatentSync** (Apache-2.0, ByteDance) ou **MuseTalk** 1.5 (MIT; usa VAE do Stable Diffusion e whisper-tiny, conferir os termos desses pesos). Wav2Lip **não** (sem licença, só pesquisa) |
| Iluminação | Parcial (nova luz por profundidade, 0.8.0) | **IC-Light** (Apache-2.0) para reiluminar rosto |
| Reenquadramento automático | **Tem** (`auto_reframe`) | Pôr na aba |
| Remover cintilações | Não tem | ffmpeg `deflicker` (simples) |
| Movimento de IA (animar foto) | Não tem | LivePortrait / modelos imagem→vídeo do ComfyUI |
| Rastreio de câmera / de objeto | Não tem | OpenCV (rastreadores CSRT/KCF, Apache-2.0). **CoTracker** é CC BY-NC 4.0 (não comercial) — evitar |
| Borrão de movimento | Não tem | Com RIFE (quadros intermediários misturados) ou `tmix` do ffmpeg |
| Tela (fundo) | **Tem** (fundo cor/desfoque) | — |

## 3. Vídeo › Remover plano de fundo

| CapCut | Drift hoje | Caminho |
|---|---|---|
| Remoção automática | **Tem** (RVM mobilenet/resnet, SAM2) | — |
| Traço (contorno) com estilos | **Tem** o efeito Contorno (0.8.0) | Expor os estilos como cartões nessa aba |
| Remoção personalizada (pincel) | **Tem** SAM2 com pontos | Pincel de adicionar/apagar na máscara |
| Chroma key (intensidade, sombra, suavizar, limpar borda) | **Tem** chroma_key | Conferir os 4 controles |

## 4. Vídeo › Retoque e Maquiagem

O CapCut tem: rosto (forma, distância, posição, inclinação), **Maquiagem** com abas Aparência (≈40 looks com foto), Cílios, Sombra, Delineado, Sobrancelha, Batom, Blush, Retoque, Destaques, Cor dos olhos, Sardas, e "Manual".

O Drift tem: Face Retouch (pele, clarear, afinar, olhos, batom, blush — agora funcionando na 0.8.0), delineado, sombra, sobrancelha, cor dos olhos, dentes, e os **7 looks** com intensidade (aba Maquiagem). Falta, pela ordem do `docs/19-maquiagem.md` (etapa 2): cílios, iluminador/destaques, sardas, acabamento do batom; e transformar a aba Maquiagem em **abas por categoria** como o CapCut, com miniaturas reais. Referência MIT: **OpenMakeupSDK** (rímel, acabamentos).

## 5. Ajuste

| CapCut | Drift hoje | Caminho |
|---|---|---|
| Ajuste automático (intensidade) | Não tem | Auto níveis/balanço de branco por estatística do quadro (sem IA) |
| Combinação de cores (igualar a outro clipe) | Não tem | Transferência de cor (Reinhard/MKL); referência **color-matcher** (GPL-3.0) |
| Correção de cor | Parcial | — |
| LUT + Proteger o tom da pele | **Tem** LUT; não protege pele | Máscara de pele (Face Retouch já calcula) aplicada à LUT |
| Cor (temp, matiz, saturação), Claridade (exposição, contraste, realces, sombras, brancos) | **Tem** (aba Ajuste) | — |
| HSL, Curvas, Roda de cores | **Tem** | — |
| Salvar como predefinição | **Tem** presets de efeito | Conferir na aba Ajuste |

## 6. Visual

- A barra superior do CapCut tem: layout, atalhos, Pro, Compartilhar, Exportar. O Drift tem Menu, nome, Vídeo, Exportar.
- Painel de propriedades: o CapCut usa **caixas de seleção por recurso com setinha para abrir** (liga/desliga + seção recolhível) e botões de quadro-chave à direita de cada linha. O Drift usa seções sempre abertas. Isso vale para refazer as abas Áudio e Vídeo › Básico nesse estilo.
- Biblioteca de música: lista com categorias à esquerda, favoritos e baixar.

## Ordem sugerida

1. **Feito em 20/10** (`docs/22-audio-capcut-etapa1.md`). **Áudio, só interface** (rápido, sem IA nova): aba Áudio no estilo CapCut com caixas (Volume/Fades, Normalizar, Reduzir ruído, Preencher canal) e o **Modificador de voz** em grade de cartões com os efeitos que já existem.
2. **Feito em 20/10** (`docs/23-audio-ia-etapa2.md`, com MossFormer2 e HTDemucs). **Áudio com IA**: Aprimorar voz (resemble-enhance ou ClearerVoice) e Isolar voz (Demucs), em ONNX/CUDA.
3. **Vídeo rápido sem IA**: remover cintilações, reduzir ruído (ffmpeg), ajuste automático, combinação de cores, proteger pele na LUT.
4. **Vídeo com IA**: fluxo óptico (RIFE), remoção de objeto (LaMa + SAM2), sincronização labial (LatentSync), reiluminação (IC-Light).
5. **Maquiagem etapa 2** (cílios, destaques, sardas) e abas por categoria.
6. Biblioteca de músicas (Jamendo) e tradutor de vídeos.

## Pesquisa complementar (20/10, sessão seguinte)

- **Licenças conferidas nos arquivos LICENSE:** DeepFilterNet MIT/Apache-2.0; MuseTalk MIT; LivePortrait MIT (repositório renomeado para KlingAIResearch); CoTracker CC BY-NC 4.0 (fora).
- **Voz mais nítida:** VoiceFixer (MIT, restauração de fala) e AudioSR (MIT, super-resolução de áudio por difusão, pesado). FlashSR é leve (2 MB, ONNX), mas não tem licença: fora.
- **Síntese de canto:** DiffSinger OpenVPI (Apache-2.0) e o original (MIT). so-vits-svc é AGPL-3.0 e está arquivado.
- **Tamanhos dos pesos** (lidos dos metadados, sem baixar): MossFormer2 48 kHz 222 MB; FRCRN 16 kHz 161 MB; resemble-enhance 713 MB; Demucs htdemucs 84 MB.
- **Velocidade na RTX 5070 Ti:** ainda não medida. Exige baixar os pesos acima (cerca de 300 MB para MossFormer2 + Demucs) e converter para ONNX; fica para a etapa 2 (áudio com IA), com o OK do Andre para o download.

## Fontes

- [resemble-enhance](https://github.com/resemble-ai/resemble-enhance), [ClearerVoice-Studio](https://github.com/modelscope/ClearerVoice-Studio), [Demucs](https://github.com/facebookresearch/demucs), [python-audio-separator](https://github.com/nomadkaraoke/python-audio-separator), [Rubber Band](https://github.com/breakfastquay/rubberband), [Autotalent](https://forum.audacityteam.org/t/autotalent-open-source-pitch-correction/9241), [RVC](https://github.com/RVC-Project/Retrieval-based-Voice-Conversion-WebUI), [pyvideotrans](https://github.com/jianchang512/pyvideotrans)
- [LatentSync](https://github.com/bytedance/LatentSync), [MuseTalk](https://github.com/TMElyralab/MuseTalk), [Wav2Lip](https://github.com/Rudrabha/Wav2Lip), [licenças de sincronização labial](https://www.creativeainews.com/articles/open-source-lip-sync-licenses-commercial-use-2026/)
- [LaMa](https://github.com/advimman/lama), [DiffuEraser](https://github.com/lixiaowen-xw/DiffuEraser), [ProPainter](https://github.com/sczhou/ProPainter), [MiniMax-Remover](https://github.com/zibojia/MiniMax-Remover), [Practical-RIFE](https://github.com/hzwer/Practical-RIFE), [IC-Light](https://github.com/lllyasviel/IC-Light), [color-matcher](https://github.com/hahnec/color-matcher), [OpenMakeupSDK](https://github.com/ehsanwwe/OpenMakeupSDK)
- [Jamendo API](https://developer.jamendo.com/v3.0/docs), [API do Pixabay](https://pixabay.com/api/docs/), [Free Music Archive](https://creativecommons.org/about/program-areas/arts-culture/free-music-archive/)
- [demucs.onnx](https://github.com/sevagh/demucs.onnx), [VoiceFixer](https://github.com/haoheliu/voicefixer), [AudioSR](https://github.com/haoheliu/versatile_audio_super_resolution), [DiffSinger OpenVPI](https://github.com/openvpi/DiffSinger), [so-vits-svc](https://github.com/svc-develop-team/so-vits-svc), [LivePortrait](https://github.com/KlingAIResearch/LivePortrait), [CoTracker](https://github.com/facebookresearch/co-tracker), [MossFormer2 48 kHz](https://huggingface.co/alibabasglab/MossFormer2_SE_48K)
