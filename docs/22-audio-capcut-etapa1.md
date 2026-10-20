# Áudio no estilo CapCut, etapa 1 (2026-10-20)

Primeira etapa do plano do `docs/21-comparativo-capcut-audio-video.md` ("Áudio, só interface"), aprovada pelo Andre: aba Áudio com caixas, como no CapCut, e o Modificador de voz em grade de cartões com favoritos. Nada de IA nova nesta etapa.

Commit `8f317ec0` no ramo **`capcut-audio`** (a partir do `capcut-080`, `169717a7`).

## O que mudou na tela

A seção **Áudio** do painel de propriedades agora tem duas abas: **Básico** e **Modificador de voz**.

### Áudio › Básico

- **Básico** (sempre aberto): Volume (com quadros-chave, como antes), **Fade-in** e **Fade-out** (0 a 10 s, no máximo metade do clipe) e Pan.
  - O fade daqui é **só do som**: a imagem não escurece. Antes o único fade ficava na aba Velocidade/Fade e mexia na imagem também.
- **Normalizar nível de volume** (caixa liga/desliga): leva o clipe a um nível padrão. Opções:
  - Redes sociais (−14 LUFS)
  - Podcast (−16 LUFS)
  - TV (−23 LUFS)

  Ao **desligar**, volta o volume que o clipe tinha antes, com a curva inteira de quadros-chave. Trocar de nível com a caixa ligada continua lembrando o volume de antes da primeira normalização. Clipe sem som (ou arquivo que sumiu) não é normalizado: aparece o aviso "Este clipe não tem som para medir".
- **Reduzir ruído** (caixa): é o redutor de ruído que já existia (DeepFilterNet), agora no formato de caixa. Ligar abre a janela de sempre, que gera uma cópia limpa do som numa faixa acima. A caixa fica marcada quando o clipe já é uma dessas cópias. Os botões de baixar o modelo continuam dentro da caixa.
- **Preencher canal** (caixa): para gravação com som só de um lado, como um microfone de lapela na entrada esquerda. Opções:
  - Canal esquerdo nos dois lados
  - Canal direito nos dois lados
  - Misturar os dois em mono

  É aplicado no mixer antes dos efeitos, então vale para a prévia e para a exportação.
- **Legendas automáticas**: igual a antes, no fim da aba.

### Áudio › Modificador de voz

- Grade de **34 cartões** em dois grupos, como no CapCut:
  - **Filtros de voz**: Voz nítida, Locutor, Microfone de estúdio, Microfone de graves, Igreja, Super reverberação, Eco divino, Eco, Eco curto, Megafone, Telefone, Rádio comunicador, Abafada, Debaixo d'água, Fonógrafo, Fita antiga, Distorcido, Lo-fi, 8 bits, Cristal, Coral, Jato, Espacial, Trêmulo, Estéreo amplo.
  - **Personagens de voz**: Esquilo, Hélio, Voz grave, Gigante, Robô, Alienígena, Lorde sombrio, Vibrato, Fantasma.
- O primeiro cartão é **Original**, que tira a voz aplicada.
- **Uma voz por vez**: escolher outro cartão troca a voz anterior. Os outros efeitos de áudio que o clipe tiver ficam intactos.
- **Pesquisar vozes**: o campo de busca procura nos dois grupos.
- **Favoritos**: a estrela no canto do cartão (aparece ao passar o mouse). Os favoritos ficam numa lista própria, no alto, e valem para todos os projetos deste computador.
- **Aplicar a tudo**: com essa caixa marcada, a próxima voz escolhida vai para todos os clipes com som do projeto.
- Cada escolha é um passo do desfazer.

Capturas conferidas na versão de teste (projeto `qualidade/teste-x11.drift`): as duas abas em português, o Robô aplicado (cartão destacado, faixa de efeito "Robot" acima do clipe) e o favorito aparecendo na lista.

## Como funciona por dentro

- **Fades do som**: `setClipAudioFade` grava `audioFadeInUs`/`audioFadeOutUs` do clipe, que o mixer já aplicava (`Clip::audioEdgeMultiplier`). O fade da aba Velocidade (`fadeInUs`, que também mexe na imagem) não foi tocado.
- **Normalizar**: `setClipLoudnessNormalized` mede o clipe (EBU R128, `analyzeLoudness`), calcula o ganho a partir do volume atual e grava o volume num único passo do desfazer. Guarda no clipe o nível escolhido (`loudnessTargetLufs`) e a curva de volume de antes (`volumeBeforeLoudness`). Os dois vão para o arquivo do projeto só quando a caixa está ligada. Medição abaixo de −60 LUFS conta como "sem som". Sem essa proteção, um arquivo ausente era medido como quase silêncio e recebia um ganho de milhares de vezes.
- **Preencher canal**: campo `channelFill` do clipe (`left`, `right`, `mono`), salvo no projeto quando ligado e aplicado em `AudioMixer.cpp` (`applyChannelFill`) antes do rack de efeitos.
- **Modificador de voz**:
  - Os cartões ficam em `presets/voice-modifier/voices.json`, embutidos no programa. Cada um traz id, grupo, efeito de áudio, valores e ícone; os nomes vêm de `AppController` e são traduzidos.
  - Cada cartão aplica um efeito de áudio do catálogo marcado com o parâmetro `voiceModifier = <id do cartão>`. É essa marca que permite trocar ou tirar só a voz.
  - Os efeitos ficam na faixa de efeitos de áudio do clipe, como qualquer efeito de áudio.
  - Favoritos: configuração `audio/voiceModifierFavorites`.
- **9 pacotes de efeito novos** (`audio-effects/`), para os sons que os efeitos clássicos não cobriam. São todos grafos JUCE que encadeiam pedais que já existem:

  | Pacote | Pedais |
  |---|---|
  | `voice_clear` | passa-alta, EQ, de-esser, compressor |
  | `voice_radio` | EQ, compressor, limitador |
  | `space_studio` | EQ, compressor, reverb curto |
  | `voice_bass` | EQ de graves, compressor |
  | `space_church` | passa-alta, reverb grande |
  | `space_hall` | reverb máximo |
  | `space_divine` | EQ, eco, reverb |
  | `texture_distort` | drive |
  | `voice_ghost` | pitch, chorus, reverb |

  O catálogo valida o grafo ao carregar: os 34 cartões aparecem como disponíveis.
- **Caixa do inspetor**: componente novo `CheckSection.qml` (caixa liga/desliga, título, seta que abre e fecha), pronto para as próximas abas no estilo CapCut.

## Testes

Novos:

- **Núcleo**: leitura do `voices.json` (34 cartões) e salvar/abrir com o canal preenchido e a normalização.
- **Editor**: fades do som (sem tocar no fade da imagem) e preencher canal com desfazer. Normalizar e desligar volta o volume, o clipe sem som é recusado, e há um passo do desfazer por troca. Modificador de voz: troca, Original, desfazer, Aplicar a tudo e favoritos.
- **Motor**: mixer com uma gravação só no canal esquerdo, nas quatro opções.

O teste `pedalCatalogCoversBundledManifests` supunha que todo efeito embutido é um pedal clássico. Agora os pacotes em grafo só precisam carregar um grafo válido, porque o próprio catálogo já confere os pedais deles ao carregar.

Suítes na cópia de desenvolvimento:

| Suíte | Resultado |
|---|---|
| Núcleo | 173 de 173 |
| Editor | 238, sem falhas |
| Agente | 152 de 153 (a falha é a de sempre do oficial, `authoredEffectLifecycle`) |
| Motor | 236, sem falhas |

Na build completa (`drift-19`), instalada: núcleo 173 de 173; editor 237 de 238; agente 152 de 153 (`authoredEffectLifecycle`, do oficial); motor 237 de 238 (`nvdecAv1StaysOnHardware`, do oficial).

A falha do editor é `audioRecordingVoiceoverWorkflow`, que grava do microfone de verdade. Repetido duas vezes: numa foi pulado (sem dispositivo), na outra o tempo esgotou. Depende do ambiente e não do que mudou aqui.

## Compilar e instalar

A build completa vem da cópia limpa `~/.cache/drift-build/wt-audio` (ramo `capcut-audio`). O comando sai da pasta `flatpak` dela:

```
flatpak run org.flatpak.Builder --force-clean --disable-updates --disable-rofiles-fuse --ccache --keep-build-dirs --state-dir=$HOME/.cache/drift-build/state $HOME/.cache/drift-build/build-main org.cutwire.Drift.yml
```

Sobre as opções:

- `--ccache` deixa a recompilação inteira em cerca de 3 minutos.
- `--keep-build-dirs` mantém a pasta `drift-N` para rodar as suítes depois.
- Sem `--disable-rofiles-fuse`, o build falha neste PC.

Depois do build, exporta-se para o repositório local (`Drift-link/flatpak/repo`) nos ramos master e stable e instala-se com `flatpak update --user`. O commit stable instalado é `2285423b`. Vale a partir da próxima abertura do Drift.

Ciclo rápido de desenvolvimento deste ramo: `~/.cache/drift-build/dev/drift-audio build|test|run`.

## Ficou de fora / pendências

- **Ramo separado**: o `capcut-audio` não foi mesclado no `capcut-080`, porque a pasta `Drift-link` tem trabalho não salvo da sessão das pendências da 0.8.0 nesse ramo. Mesclar depois que aquele trabalho for salvo: `git merge capcut-audio`, com conflito provável só em `PropertiesPanel.qml` e `AppController.*`.
- **Sem operações para o agente (MCP)**: o agente já tem `normalize_volume` e os efeitos de áudio, mas não tem "preencher canal", "fade do som" nem "modificador de voz". Ficou de fora para não crescer o catálogo de ferramentas, que tem limite de tamanho.
- **Nome do efeito na faixa em inglês** ("Robot"): é o nome do pacote de efeito. O Drift oficial não traduz nome de efeito de áudio em lugar nenhum (o Autopan também aparece em inglês). Os cartões estão em português.
- **Etapa 2 (IA de áudio)**: Aprimorar voz (MossFormer2) e Isolar voz (Demucs). Precisa da permissão do Andre para baixar cerca de 300 MB de modelos e medir a velocidade na placa.
