# Ajustes no sistema

Máquina: Ubuntu 26.04.1, GNOME em Wayland, GeForce RTX 5070 Ti com driver NVIDIA 610.57.04, além da placa integrada Intel. Apps de vídeo instalados como Flatpak: VLC, mpv e Drift.

## Driver NVIDIA dentro do Flatpak

Em 10/09/2026 o driver NVIDIA do sistema foi atualizado para a 610.57.04. O Flatpak só tinha a extensão de driver da 595.84, e como a versão dentro do sandbox precisa ser idêntica à do kernel, toda renderização OpenGL/EGL dos apps Flatpak quebrou. Sintoma: VLC e mpv abriam, tocavam o áudio, mas não mostravam imagem.

Corrigido com a instalação da extensão certa, que veio junto ao instalar o Drift:

```bash
flatpak install --user -y flathub org.freedesktop.Platform.GL.nvidia-610-57-04
```

Isso volta a acontecer a cada atualização do driver NVIDIA pelo apt. Rodar `flatpak update -y` logo depois resolve.

## Acesso a discos externos

Os Flatpaks não enxergam `/run/media` por padrão. Foi liberado para o Drift, o VLC e o mpv:

```bash
flatpak override --user --filesystem=/run/media --filesystem=/media org.cutwire.Drift
```

## Chrome e vídeo protegido

Fora do escopo do Drift, mas registrado aqui porque foi investigado no mesmo dia: o Chrome mostrava tela preta na Netflix com áudio e legendas normais. O processo gráfico do Chrome reportava que o motor Vulkan não é compatível com a sessão Wayland. Solução testada: abrir o Chrome com `--disable-features=Vulkan` ou com `--ozone-platform=x11`. O Firefox, por sua vez, estava com o DRM desligado; ativar no aviso da página resolve.
