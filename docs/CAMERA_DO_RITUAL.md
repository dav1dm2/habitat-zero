# Ajustar a câmera do ritual

A câmera continua em primeira pessoa, presa ao jogador. A navegação define por onde ele caminha; dois marcadores independentes definem para onde olha. Não há uma câmera externa ou trilho separado.

## Ajustes no editor

1. Parar o jogo com F8 e abrir `scenes/levels/attis_forest.tscn`.
2. Selecionar a raiz e usar **Prévia do desfecho com luz de edição** para enxergar os cervos e o terreno.
3. Expandir **DreamEvent → RitualCamera**.
4. Mover **WalkLookTarget** para o ponto que o jogador deve olhar enquanto caminha. Mover **FinalLookTarget** para o ponto que deve olhar ao parar e durante a aproximação dos cervos. São pontos de atenção no mundo, não posições onde a câmera será colocada. Selecionar e pressionar F enquadra o marcador no viewport.
5. Salvar com Ctrl+S e testar novamente. Executar `tests/preview_dream.tscn` com F6 inicia direto no sonho; sair das instalações e seguir a trilha. F10 suspende o gatilho para examinar livremente, e outro F10 o reativa.

Os dois alvos começam no mesmo ponto, aproximadamente no centro visual dos cervos, à altura do olhar e à frente do local onde o jogador para. Isso evita uma virada desnecessária ao chegar. Para experimentar outra composição, alterar primeiro o alvo final e testar. Subir um alvo inclina o olhar para cima; baixá-lo inclina para baixo. Mover lateralmente muda o enquadramento. Não colocar o alvo exatamente sobre a câmera/local de parada: uma direção muito curta fica instável.

Selecionando **RitualCamera**, o Inspector também oferece:

| Propriedade | Padrão | Efeito |
|---|---:|---|
| Walk Speed | 2,1 m/s | Velocidade da caminhada automática. |
| Turn Speed Degrees | 80°/s | Limite de rotação por eixo. Menor deixa a virada mais lenta; maior acompanha mais rápido. |
| Centered Duration | 0,9 s | Pausa ao chegar ao centro, antes de os cervos avançarem. Também dá tempo para acomodar o olhar no alvo final. |
| Deer Approach Duration | 3,2 s | Tempo da aproximação dos cervos antes do fade final. |

Para mudar **onde o jogador para**, mover `DreamEvent/RitualCenter`. Para mudar **onde começa a cutscene**, mover seu filho `RitualTrigger` ou ajustar o raio da esfera no `CollisionShape3D`. Os alvos de câmera são independentes desses nós: após mudar o centro, reconferir os dois enquadramentos. Alterações de relevo/obstáculos exigem recalcular os caminhos no nó raiz e testar a passagem física.
