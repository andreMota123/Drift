# Aprimorar qualidade (IA local)

Feito em 2026-10-15, ramo `capcut-style`, commit `48b61e51`.

## Como usar

1. Selecione um clipe de vídeo.
2. No painel de propriedades, aba **Estabilização**, logo abaixo da estabilização: **Aprimorar qualidade**.
3. Acompanhe a barra de progresso; dá para cancelar.
4. Ao terminar, o clipe passa a mostrar a versão aprimorada. **Remover aprimoramento** volta ao original; Ctrl+Z também.

O vídeo só é aprimorado se for menor que a altura do projeto (por exemplo, 360p ou 720p num projeto 1080p). Se já tiver essa resolução ou mais, o Drift avisa e não faz nada.

## Como funciona

- **Modelo:** Real-ESRGAN general x4v3 (licença BSD-3-Clause, 4,6 MB em ONNX). Recupera e amplia 4 vezes.
- **Download:** feito na primeira vez, de um endereço fixo (a mesma exportação ONNX que o Concat usa), conferido pelo SHA-256 `1940a93e…a115755d`, e guardado em `~/.var/app/org.cutwire.Drift/data/CutWire Drift/CutWire Drift/models/`.
- **Aceleração:** roda no motor de IA do Drift (ONNX Runtime). Para este modelo o Drift prefere a NVIDIA (CUDA) quando o pacote de IA da NVIDIA está instalado, mesmo com o WebGPU registrado: pelo WebGPU ele rodava a cerca de um quadro por segundo. Se a NVIDIA falhar, cai no padrão do Drift e, em último caso, no processador.
- **Processamento:**
  - decodifica só o trecho que o clipe usa, com 1 s de margem de cada lado;
  - roda o modelo em blocos de 512 px com 16 px de sobreposição, para caber na memória sem emendas visíveis;
  - reduz o resultado até a altura do projeto e grava em H.264, com quadro-chave a cada 12 quadros, sem áudio;
  - guarda o arquivo em `…/CutWire Drift/enhanced/`, mantendo a marca de rotação do original.
- **No projeto:** três campos novos no clipe (`enhancePath`, `enhanceInUs`, `enhanceOutUs`) dizem qual arquivo aprimorado usar e qual trecho da fonte ele cobre.
- **Na hora de mostrar:** a pré-visualização e a exportação leem a imagem desse arquivo onde ele cobre a fonte (`resolveVideoRead`). O som continua vindo do original. Se o clipe for aparado para além do trecho aprimorado, a parte de fora mostra o original. Clipe invertido ou com estabilização assada usa o caminho de sempre.

## Teste

- **Clipe:** trecho de 6 s do C6298.MP4 reduzido para 202×360, num projeto 1080p.
- **Resultado:** 606×1080, 144 quadros, ligado ao clipe.
- **Tempo:** cerca de 1 min 30 s, contando a abertura do Drift e a preparação do modelo na primeira execução.
- **Comparação de um quadro:** bem mais nítido que o mesmo 360p ampliado do jeito comum, no cabelo, no rosto e nos contornos. A imagem está em `~/.cache/drift-build/dev/qualidade/comparacao.png`.
- **Suítes:** editor 147 e núcleo 129, passando.

## Limites e pendências

- **Velocidade:** cerca de 0,5 s por quadro no teste. A placa ficou a 1% de uso no fim, então não está confirmado que o CUDA esteja de fato em uso dentro do ambiente de teste. Investigar com o registro `[upscale]` e o `nvidia-smi` durante um aprimoramento longo no Drift instalado.
- **Só vídeo.** Fotos (clipes de imagem) ainda não.
- **Arquivos aprimorados** ficam na pasta de dados do Drift e não vão junto ao salvar uma cópia compartilhável do projeto; noutro computador o clipe volta a mostrar o original.
- **Não há limpeza automática** dos arquivos aprimorados que deixaram de ser usados.
- **O botão ainda não foi usado com mouse:** o teste chamou a função por um gatilho temporário.
