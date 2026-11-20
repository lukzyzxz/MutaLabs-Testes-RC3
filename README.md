# Testes da demo MutaLabs RC3
O pacote reúne o código das seis suítes automatizadas da demo, os registros da execução de 20/11/2026 no Linux com Godot 4.7.2 e um executor para repetir a verificação em Windows ou Linux.

| Suíte | O que mostrar à banca | Verificações aprovadas em 20/11 |
|---|---|---:|
| campaign_rc2 | Requisitos para avançar na campanha e sequência de encerramento | 104 |
| bosses_rc3 | Fases, ataques e efeitos dos chefes | 78 |
| regression_rc2 | Comportamentos preservados, incluindo salvamento | 37 |
| miniboss_rc2 | Encontros com os guardiões | 21 |
| traversal_rc2 | Travessia e pouso em plataformas | 21 |
| dodge_rc3 | Possibilidade de evitar ataques com os controles do jogo | 7 |

Os nomes RC2 foram preservados porque esses scripts também integram o pacote da RC3. Abra os seis arquivos em evidencias-linux para consultar as 268 linhas PASS. Os arquivos em tests/resultados_rc3 guardam os resultados anteriores.

## Repetir todos os testes
1. Extraia este repositório e o projeto MutaLabs_1.0_RC3_Chefes_e_Combate.zip em pastas separadas. O ZIP do projeto acompanha a entrega do TCC. Escolha a pasta que contém project.godot. Use uma cópia destinada aos testes.
2. No Windows, abra o PowerShell na pasta deste README. Com Python 3 instalado, ajuste os dois caminhos abaixo. Use o executável de console do Godot.
```powershell
py -3 rodar.py --godot "C:\Godot\Godot_console.exe" --projeto "C:\MutaLabs\RC3"
```
No Linux, com godot no PATH:
```sh
python3 rodar.py --projeto /caminho/para/RC3
```
Para escolher uma suíte, acrescente, por exemplo, `--suite bosses_rc3`. O executor importa o projeto, usa dados temporários de jogador e cria uma pasta em execucoes com data, versão, um relatório por suíte e resumo.txt. Se aparecer REVISAR, abra o relatório correspondente. A contagem esperada vale para a RC3.

## Demonstrar
Execute o conjunto completo e projete o resumo. Escolha uma linha PASS do relatório e abra o arquivo de mesmo nome em tests. Por exemplo, em dodge_rc3, o teste da garra simula movimento e confere a vida e a posição do personagem após o ataque. O conjunto verifica condições do software. Resultados sobre suspense percebido exigem sessões com jogadores.

## Capturas e histórico
Os scripts visual_rc2.gd e visual_rc3.gd geram imagens com janela gráfica. Na raiz do projeto extraído, execute Godot com --path . --script res://tests/visual_rc2.gd ou res://tests/visual_rc3.gd, sem --headless. As imagens ficam em previews_rc2 e previews_rc3. O visual_rc3 também aceita uma pasta para os quadros após --. Os quatro scripts em tests/historico_rc1 documentam a revisão anterior. Capturas e histórico ficam fora da contagem de 268.
