# Compilar, instalar, testar e reverter

Tudo é feito com o construtor de Flatpak, dentro do SDK do KDE. Nada precisa ser instalado no sistema além do próprio Flatpak.

## Ferramentas

Instaladas uma vez, para o usuário:

```bash
flatpak install --user -y flathub org.flatpak.Builder org.kde.Sdk//6.11
```

## Compilar e instalar

A partir da pasta `Drift-link/flatpak`:

```bash
cd "Projeto Drift/Drift-link/flatpak" && flatpak run org.flatpak.Builder --user --force-clean --ccache --keep-build-dirs --disable-rofiles-fuse --install build-dir org.cutwire.Drift.yml
```

- `--force-clean` é obrigatório quando `build-dir` já existe.
- `--ccache` reaproveita objetos compilados. A primeira compilação da 0.5.1 levou cerca de 15 minutos; as seguintes, 5.
- `--keep-build-dirs` mantém a árvore de compilação em `.flatpak-builder/build/drift/_flatpak_build`, onde ficam os executáveis de teste.
- `--install` instala o resultado como `org.cutwire.Drift//master`, origem `drift-origin`.

O manifesto compila a partir da pasta atual (`type: dir`, `path: ..`), então basta editar o código e recompilar.

Sobre o `main` do projeto oficial, a compilação é bem mais longa, porque ele passou a compilar a biblioteca gráfica Skia a partir do código fonte.

## Rodar os testes

Os testes ficam na árvore de compilação e precisam das bibliotecas do SDK e do pacote instalado:

```bash
B="Projeto Drift/Drift-link/flatpak/.flatpak-builder/build/drift/_flatpak_build"; flatpak run --devel --command=sh --filesystem=host --env=QT_QPA_PLATFORM=offscreen org.cutwire.Drift//master -c "cd '$B' && ./tests/tst_editorstate && ./tests/tst_core"
```

Para rodar só um teste, passe o nome como argumento, por exemplo `./tests/tst_editorstate linkUnrelatedClipsMoveTogetherKeepTiming`.

## Como ficou a instalação

| Ramo | Origem | Conteúdo |
|---|---|---|
| `master` | `drift-origin` (cache do construtor) | build local, versão 0.5.1 + Link + tradução |
| `stable` | `drift-local` (`Drift-link/flatpak/repo`) | a mesma build local |

O `stable` do Flathub foi substituído porque o GNOME continuava abrindo esse ramo mesmo com o atalho apontando para `master`. Com os dois ramos iguais, qualquer caminho de abertura chega na versão certa.

Para publicar uma build nova também no ramo `stable`, depois de compilar:

```bash
cd "Projeto Drift/Drift-link/flatpak" && flatpak build-export --disable-sandbox repo build-dir stable && flatpak install --user --reinstall -y drift-local org.cutwire.Drift//stable
```

O Drift precisa estar fechado para o `--reinstall`.

Atualizações do Flathub não sobrescrevem a versão local, porque a origem dos dois ramos não é mais o Flathub.

## Build sobre o main (Skia)

O `main` do projeto compila o Skia a partir do fonte. A compilação leva cerca de 20 a 30 minutos e precisa rodar desacoplada da sessão, com o estado fora do repositório e fora de `/tmp`, que o sandbox do construtor não enxerga:

```bash
C="$HOME/.cache/drift-build"; mkdir -p "$C"; cd "Projeto Drift/Drift-link/flatpak" && setsid nohup bash -c "flatpak run org.flatpak.Builder --user --force-clean --ccache --keep-build-dirs --disable-rofiles-fuse --state-dir='$C/state' '$C/build-main' org.cutwire.Drift.yml; echo BUILD_RC=\$?" > "$C/build.log" 2>&1 < /dev/null & disown
```

Os testes ficam em `$C/state/build/drift-N/build/tests/`, e o resultado pronto para exportar em `$C/build-main`.

Ramos no repositório local `repo/`: `master` e `stable` recebem a build mais nova; `v051` guarda a build da versão 0.5.1 com a função Link, como reserva:

```bash
flatpak install --user --reinstall -y drift-local org.cutwire.Drift//v051
```

## Voltar para a versão oficial

```bash
flatpak install --user --reinstall -y flathub org.cutwire.Drift//stable
```

E, se quiser tirar a build local do ramo master:

```bash
flatpak uninstall --user -y org.cutwire.Drift//master
```

## Permissões do sandbox

O Drift do Flathub não enxerga discos externos. Foi liberado com:

```bash
flatpak override --user --filesystem=home --filesystem=/run/media --filesystem=/media org.cutwire.Drift
```

Esses ajustes valem para os dois ramos e sobrevivem a reinstalações. Arrastar arquivos de outro app para dentro do Drift em Flatpak continua bloqueado pelo próprio Drift; use Importar.
