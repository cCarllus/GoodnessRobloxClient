# Goodness Roblox Client

Aplicativo desktop para macOS com duas áreas independentes na sidebar:

- **Piano Sheets**: interpreta sheets textuais e envia acordes/teclas em tempo programado.
- **Rhythm Auto Player**: captura a imagem de uma janela do Roblox ou de uma tela, identifica círculos coloridos em movimento e envia as teclas quando as notas alcançam os receptores. Possui modos para bateria, baixo, guitarra e teclado.

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

O **Rhythm Auto Player** tambem precisa de permissao em:

`Ajustes do Sistema > Privacidade e Seguranca > Gravacao da Tela`

Depois de autorizar a captura, pode ser necessario reiniciar o app.

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

## Rhythm Auto Player

O modo novo fica na **sidebar**, separado de **Piano Sheets**, sem alterar o parser de sheets.

1. Abra um instrumento musical no Roblox e deixe visiveis os receptores das notas.
2. Clique em **Rhythm Auto Player**, selecione bateria, baixo, guitarra ou teclado.
3. Escolha **Roblox** no campo de fonte. Se nao estiver disponivel, selecione a tela inteira.
4. Clique em **Iniciar** e aguarde a imagem aparecer na previa.
5. Clique em **Calibrar centros das teclas**, e marque na imagem, um por um, os circulos que recebem as notas. A calibracao e salva por instrumento.
6. Clique no Roblox para deixa-lo em primeiro plano. O app so envia teclas com a janela Roblox em foco.
7. Ajuste a **matiz** e a **tolerancia** para as cores reais das notas, bem como a **antecipacao** para compensar a latencia. Use **Parar** antes de sair do modo.

### Limitacoes

- O rastreador usa correspondencia de cor e movimento descendente. Nao e reconhecimento universal de todas as skins ou jogos musicais; requer calibracao e ajustes.
- O sistema assume notas redondas e faixas verticais. Notas longas, arrasto, mudancas bruscas de camera e cores fora da faixa selecionada ainda nao sao suportados.
- A janela ou tela selecionada precisa permanecer visivel e a captura autorizada.
- Sem injecao, leitura de memoria, alteracao dos arquivos do Roblox, ou bypass de protecoes. Sao usados ScreenCaptureKit e eventos locais de teclado permitidos pelo macOS.
- Alguns jogos podem proibir automacao nas suas regras. Use somente onde houver permissao para isso.

### Testes

Execute scripts/verify.sh para compilar o app e testar parser, instrumentos e deteccao sintetica. A sincronizacao real depende de testes no Roblox em execucao no macOS.
