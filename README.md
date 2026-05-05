# Goodness Roblox Client

Aplicativo desktop para macOS com uma tela central de Piano Sheets. Ele interpreta sheets textuais de piano e envia eventos reais de teclado usando APIs nativas do sistema.

O objetivo e uso pessoal, estudo musical, acessibilidade e automacao local. Mesmo com o visual de client, o app nao injeta codigo, nao le memoria, nao modifica Roblox e nao implementa bypass de anti-cheat.

## Como rodar

Requisitos:

- macOS 13 ou superior
- Xcode instalado, ou Command Line Tools com Swift

No terminal, dentro desta pasta:

```sh
swift run GoodnessRobloxClient
```

Tambem e possivel abrir a pasta no Xcode e rodar o produto `GoodnessRobloxClient`.

Para criar um `.app` em `dist/`:

```sh
scripts/package_app.sh
open "dist/Goodness Roblox Client.app"
```

Para validar apenas o parser:

```sh
swift run ParserSmokeTest
```

Para validar o projeto antes de mexer no app:

```sh
scripts/verify.sh
```

## Estrutura

```txt
Sources/GoodnessRobloxClient      UI SwiftUI e estado da tela
Sources/GoodnessRobloxClientCore  Parser, eventos e simulacao de teclado
SmokeTests                        Validacao leve do parser
Resources                         Info.plist do bundle macOS
scripts                           Scripts de verificacao e empacotamento
docs                              Documentacao de arquitetura
```

Regras de manutencao para agentes e colaboradores ficam em `AGENTS.md`.

## Permissao no macOS

Para simular teclas, o app precisa estar autorizado em:

`Ajustes do Sistema > Privacidade e Seguranca > Acessibilidade`

Na primeira execucao, clique em `Autorizar` dentro do app. Se estiver rodando por `swift run`, talvez o item autorizado apareca como Terminal, iTerm, Xcode ou o executavel compilado, dependendo de como o app foi iniciado.

## Formato aceito

Exemplos:

```txt
[6] [6] [6] [6]
[7] [6] [6] [18]
[6psu] 6 6 [6dy] [%aOuy] % % [%st]
[6eptu] 6 6 6 6 [6p]O[6p]a[6s]d
```

Regras:

- `[6psu]` toca um acorde: `6`, `p`, `s` e `u` juntos.
- Caracteres fora de colchetes tocam como notas individuais.
- Espacos, tabs e quebras de linha podem virar pausas quando a opcao correspondente esta ativada.
- Letras maiusculas e simbolos como `%` sao enviados com Shift.

## Fluxo recomendado

1. Cole a sheet.
2. Ajuste tempo, duracao da tecla e atraso inicial.
3. Clique em `Tocar`.
4. Durante o atraso inicial, foque a janela do Roblox Piano.

Use `Pausar` e `Parar` para controlar a reproducao.
