# Áudio de Habitat Zero

A configuração fica em `resources/audio/soundtrack.tres`. As faixas e o efeito de porta ficam em `assets/audio/`. O jogo usa os canais **Music** e **Effects** na aba **Áudio** do Godot.

## Quando toca

| Momento | Campo no Inspector | Regra |
| --- | --- | --- |
| Menu principal | `Menu Tracks` | Começa ao abrir o menu. `title_1.mp3` e `title_2.mp3` têm 50% de chance cada de tocar primeiro. Depois as faixas alternam. |
| Início do Dia 1, em blecaute | `Blackout Tracks`, `Blackout Delay` | Após 20 s de jogo. Pode começar ao ar livre ou já dentro das instalações. `blackout_1.mp3` e `blackout_2.mp3` alternam a partir de um sorteio inicial. Se a energia voltar antes dos 20 s, o blecaute não toca. |
| Energia restaurada | `Powered Tracks`, `Powered Delay` | A fase anterior acaba quando o painel restaura a energia. Depois de 20 s, uma das duas faixas regulares começa com 50% de chance. As duas se alternam e seguem no Dia 2. |
| Início do sonho | `Dream First` | `dream_1.mp3` começa assim que o estado do sonho é ativado, durante a transição para o último dia. Toca uma vez. |
| Depois da primeira faixa do sonho | `Dream Second`, `Dream Gap` | `dream_2.mp3` começa 15 s após o fim natural da primeira faixa. Toca uma vez, caso o sonho ainda esteja em curso. |
| Tela final | `Ending Track` | `ending.mp3` começa quando termina o fade do ritual e aparece a tela de fim. Substitui a trilha do sonho mesmo se uma faixa ainda estiver tocando ou aguardando o intervalo. Toca uma vez. |
| Portas | `Door Opening` | `door_opening.wav` toca no início de uma travessia aceita do jogador. O efeito continua durante a troca de cena. |

As três listas são embaralhadas uma vez ao entrar na fase. Com mais de duas faixas, todas tocam nessa ordem e a lista volta à primeira quando chega ao fim. Trocar de área mantém a posição da trilha e o tempo de espera. O menu de pausa congela a reprodução e os atrasos. Ao usar **Continuar** ou morrer e voltar ao checkpoint, a música começa a fase correspondente ao estado salvo. A posição da faixa não faz parte do checkpoint.

A faixa enviada como `day 2 regular music.mp3` está disponível em `assets/audio/day2_optional.mp3`. Ela fica fora da rotação automática, pois o Dia 2 mantém a rotação regular.

## Trocar, acrescentar ou tirar áudio no Godot

1. Coloque o arquivo `.mp3`, `.ogg` ou `.wav` em `assets/audio/`. Aguarde o Godot importar.
2. No painel **Sistema de Arquivos**, abra `resources/audio/soundtrack.tres`. No **Inspector**, expanda a seção correspondente ao momento desejado.
3. Para **trocar** uma faixa, arraste o novo arquivo sobre a entrada correspondente. Para **acrescentar** outra a uma lista, aumente o tamanho e preencha a nova entrada. Para **remover**, limpe a entrada ou retire-a da lista antes de apagar o arquivo. Uma lista vazia deixa o momento sem música. Se limpar **Dream First**, **Dream Second** passa a tocar desde o início do sonho; se limpar **Dream Second**, a primeira toca sozinha.
4. Altere os campos **Delay** e **Gap** para mudar o tempo em segundos. Na aba **Importar**, deixe **Loop** desligado nas músicas; o fim de cada faixa aciona a próxima. Salve o recurso e rode o jogo novamente.
5. Para mudar a mixagem do projeto, ajuste **Music** e **Effects** na aba **Áudio** e salve o layout padrão. Os sons de porta e os bipes do painel usam **Effects**.

Para criar uma condição totalmente nova, como uma faixa exclusiva do Dia 2, adicione um campo em `scripts/audio/soundtrack_settings.gd` e trate a condição em `_sync()` de `scripts/audio/soundtrack.gd`. Nesse exemplo, verifique Dia 2 com energia antes do caso geral de energia restaurada e defina o que acontece ao entrar na fase. Mantenha sonho e final com prioridade. Os checkpoints em disco continuam independentes da trilha.
