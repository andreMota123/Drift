# Áudio com IA, etapa 2: Aprimorar voz e Isolar voz (2026-10-20)

Segunda etapa do plano do `docs/21-comparativo-capcut-audio-video.md`, com a permissão do Andre para baixar os modelos. Commit `51f9d7e9` no ramo **`capcut-audio`**, logo depois da etapa 1 (`8f317ec0`, `docs/22-audio-capcut-etapa1.md`).

## O que aparece na tela

Em **Áudio › Básico**, logo depois de "Reduzir ruído", há duas caixas novas:

- **Aprimorar voz**: deixa a fala mais clara e encorpada, limpando ruído e eco do ambiente.
- **Isolar voz**: mantém só a voz, tirando música e som de fundo.

Como cada uma funciona:

- **Primeiro uso**: ligar a caixa baixa o modelo; o tamanho aparece na descrição da caixa. Depois o som do clipe é processado. Enquanto roda, a caixa mostra o andamento ("Baixando…", "Lendo o áudio…", "Isolando a voz…", "Gravando o áudio…"), uma barra e o botão Cancelar.
- **Resultado**: o clipe passa a tocar a versão processada. Em clipe de vídeo, o som é separado antes numa faixa de áudio própria, ligada ao vídeo, e a imagem não muda. Separação e troca contam como um passo só do desfazer.
- **Desligar a caixa**: volta o som original, no mesmo corte.
- **Uma por vez**: as duas caixas se excluem. Ligar uma com a outra ligada processa de novo a partir do som original; nunca empilha um modelo sobre o outro.
- **Disponibilidade**: só para clipes de vídeo ou áudio com som de arquivo; não vale para clipe composto.

## Os modelos

Os dois são locais e rodam no ONNX Runtime do Drift: na placa NVIDIA quando o complemento CUDA está instalado, senão no processador. Cada um é baixado no primeiro uso, de um endereço fixado num commit do repositório, e conferido pelo tamanho e pelo SHA-256 antes de ser usado. Ficam em `~/.var/app/org.cutwire.Drift/data/CutWire Drift/CutWire Drift/models/`.

| Caixa | Modelo | Licença | Arquivo | Tamanho |
|---|---|---|---|---|
| Aprimorar voz | MossFormer2_SE_48K (ClearerVoice-Studio, Alibaba), exportado por TigreGotico/audiosronnx-mossformer2 | Apache-2.0 | `voice-enhance/mossformer2_48k.onnx` | 229 MB |
| Isolar voz | HTDemucs v4 (Meta), exportado por HRSadeghi/demucs-onnx | MIT (código e pesos) | `voice-isolate/htdemucs.onnx` + `.json` | 169 MB |

Juntos dão cerca de 400 MB, um pouco mais que os 300 MB estimados antes. O HTDemucs ficou na versão de precisão completa: a de meia precisão (91 MB) é mais lenta no processador, segundo o próprio autor, e nem todo PC tem CUDA.

Sobre a licença do Demucs: a página do HRSadeghi diz que os pesos v3/v4 seriam "não comercial (CC BY-NC 4.0)". O arquivo de licença oficial do Demucs (repositórios `facebookresearch/demucs` e `adefossez/demucs`) diz MIT, e o README oficial não menciona restrição aos pesos. Vale o MIT oficial, mas a divergência fica registrada aqui.

## Como funciona por dentro

- **Motor** (`src/engine/VoiceAi.h/.cpp`):
  - **`VoiceEnhancer`**: o grafo do MossFormer2 só prevê uma máscara espectral. O resto foi portado do código numpy do audiosronnx (Apache-2.0), constante por constante:
    - o filtro de bancos de mel no padrão Kaldi (60 bandas, mais primeira e segunda derivadas);
    - o STFT de 1920 pontos (feito com o `av_tx` do FFmpeg);
    - a aplicação da máscara e o ISTFT;
    - a janela deslizante de 4 s para áudios acima de 20 s.

    A fala é processada em mono e vai para os dois lados.
  - **`VoiceIsolator`**: o grafo do HTDemucs fica entre o STFT e o ISTFT. As peças de DSP do demucs-onnx (STFT/ISTFT, FFT, sobreposição, MIT) estão copiadas sem mudança em `third_party/demucs-onnx`. O laço de pedaços com sobreposição de 25 % e a normalização pela faixa inteira seguem o `apply_model` do Demucs, sobre as sessões ONNX do próprio Drift. Fica só a faixa "vocals".
- **Controlador** (`src/models/VoiceAiController`, `EditorState.voiceAi` no QML): cuida do download (em partes, com hash), da decodificação do trecho original, do modelo e do arquivo FLAC em `generated-audio`. Os modelos ficam carregados depois do primeiro uso.
- **Projeto**: o clipe guarda `voiceAiKind`, `voiceAiSourcePath`, `voiceAiSourceAssetId` e `voiceAiSourceIn`, salvos no arquivo do projeto. A troca e a volta ficam no `AppController` (`voiceAiSource`, `applyVoiceAiResult`, `restoreVoiceAi`).
- **`CheckSection`**: depois de um clique, a caixa volta a seguir o estado do clipe. Assim um processamento que falha ou é cancelado não deixa a caixa marcada.

## Resultados medidos

**Teste do motor com a gravação real** `Deluxe/C6298.MP4`: fala com ruído branco somado, a cerca de 6 dB de relação sinal/ruído.

| Modelo | Melhora (relação sinal/ruído) | 60 s de áudio na NVIDIA | 30 s de áudio no processador |
|---|---|---|---|
| Aprimorar | de 6,0 para 18,1 dB | 1,1 s (carregar: 4 s, uma vez) | 3,8 s |
| Isolar | de 6,6 para 20,7 dB (fala sobre acordes) | 0,9 s (carregar: 0,6 s) | 8,3 s |

As quatro faixas do HTDemucs somadas refazem a mistura com erro de −39 dB, o que confere o STFT/ISTFT e a normalização.

**No Drift de teste, com o vídeo inteiro de 1:48:** o som foi separado numa faixa "Áudio 1", e a forma de onda mostra as pausas limpas.

| Versão | Ruído de fundo | Volume |
|---|---|---|
| Original | −42 dB | −16,3 LUFS |
| Isolar voz | −71 dB | igual |
| Aprimorar voz | silêncio total nas pausas | igual |

## Testes

Novos:

- **Motor**:
  - o filtro Kaldi num tom de 1 kHz (banda certa, derivadas zero, entrada curta);
  - `voiceAiModelsOnRealSpeech`, que roda os dois modelos de verdade e mede. Só roda com `DRIFT_VOICE_AI_MODELS` e `DRIFT_VOICE_AI_SPEECH` definidos; sem eles é pulado.
- **Editor**: troca e volta do som, com corte no meio, troca entre os dois modos e desfazer. Também um vídeo de verdade com som: separa, a caixa do vídeo responde pelo áudio dele, e desliga.
- **Núcleo**: salvar e abrir os campos novos.

Suítes na cópia de desenvolvimento:

| Suíte | Resultado |
|---|---|
| Núcleo | 173 de 173 |
| Editor | 239, sem falhas |
| Agente | 152 de 153 (`authoredEffectLifecycle`, do oficial) |
| Motor | 237, sem falhas |

Na build completa (`drift-20`), instalada nos ramos master e stable (commit stable `7c3640f2`), ficaram só as três falhas já conhecidas:

- editor: a gravação de microfone (`audioRecordingVoiceoverWorkflow`, depende do ambiente);
- agente: `authoredEffectLifecycle`;
- motor: `nvdecAv1StaysOnHardware`.

O teste com os modelos reais repetiu os mesmos números na NVIDIA. Vale a partir da próxima abertura do Drift.

Os modelos já estão baixados neste PC, então as caixas funcionam direto, sem baixar de novo.

## Pendências

- **Fechamento com CUDA**: num processo que usou um modelo no CUDA, o ONNX Runtime às vezes aborta ao fechar, com "corrupted double-linked list". Medido: o aprimorar qualidade (Real-ESRGAN) também aborta em 4 de 6 execuções; no processador nunca acontece, nem com a checagem de memória do glibc ligada. É do runtime CUDA, não dos modelos novos, mas vale investigar (por exemplo, encerrar o runtime antes de fechar o Drift).
- **Faixa de áudio dos vídeos com várias faixas de som**: o processamento lê a faixa de som padrão do arquivo.
- **Pacote do projeto**: ao empacotar um projeto, o arquivo original (que a caixa usa para voltar o som) não vai junto.
- **Ramo**: o `capcut-audio` continua separado do `capcut-080` (ver doc 22). Não há operações MCP para estas caixas.
