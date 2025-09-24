# Resultados do Teste de Escalonamento - Cluster Autoscaler

## Tabela de Dados Agregados

| Métrica                     | 5 Réplicas | 10 Réplicas | 30 Réplicas | Scale-down |
| --------------------------- | ---------- | ----------- | ----------- | ---------- |
| Nós provisionados           | 0          | 2           | 6           | -8         |
| Total de nós                | 2          | 4           | 10          | 2          |
| Tempo primeira resposta (s) | N/A        | 75          | 75          | 704        |
| Densidade (pods/nó)         | 2.5        | 2.5         | 3.0         | 0.5        |
| Pods em estado pendente     | 2→0        | 4→0         | 18→0        | 0          |
| Duração da fase (s)         | ~300       | ~300        | ~600        | 1056       |

## Resumo do Teste

O teste foi realizado em três fases de escalonamento (5, 10 e 30 réplicas) seguidas por uma fase de redução (scale-down). O Cluster Autoscaler demonstrou os seguintes comportamentos:

1. **Fase de 5 réplicas**:

   - Não houve necessidade de adicionar novos nós
   - Todos os pods foram executados nos 2 nós existentes
   - Inicialmente 2 pods pendentes que foram rapidamente alocados

2. **Fase de 10 réplicas**:

   - Adicionou 2 novos nós (total de 4)
   - Primeiro nó adicionado após 75 segundos
   - Inicialmente 4 pods pendentes até provisionamento de novos nós

3. **Fase de 30 réplicas**:

   - Adicionou 6 novos nós (total de 10)
   - Tempo para provisionar novos nós: 75 segundos
   - 18 pods permaneceram pendentes durante o provisionamento inicial

4. **Fase de redução (scale-down)**:
   - Reduziu de 10 para 2 nós
   - Primeira remoção ocorreu após 704 segundos
   - Duração total de 1056 segundos para estabilizar em 2 nós

## Métricas Detalhadas

### Tempos de Resposta

- Tempo para provisionar primeiro nó após escalar para 10 réplicas: 75 segundos
- Tempo para provisionar primeiros nós após escalar para 30 réplicas: 75 segundos
- Tempo para primeira remoção de nó: 704 segundos
- Duração total do scale-up: 1240 segundos
- Duração total do scale-down: 1056 segundos
- Duração total do teste: 2312 segundos

### Comportamento de Escala

- Estado inicial: 2 nós
- 5 réplicas: manteve 2 nós
- 10 réplicas: expandiu para 4 nós
- 30 réplicas: expandiu para 10 nós
- Após scale-down: retornou para 2 nós

### Eficiência de Recursos

- Densidade com 5 réplicas: 2.5 pods/nó
- Densidade com 10 réplicas: 2.5 pods/nó
- Densidade com 30 réplicas: 3.0 pods/nó
- Densidade após scale-down: 0.5 pods/nó

### Observações

- Os tipos de instância não foram corretamente identificados (marcados como "unknown")
- O Cluster Autoscaler manteve a densidade de pods entre 2.5 e 3.0 por nó
- O tempo de resposta para o scale-up foi consistente (75s) independente da carga
- O tempo de scale-down continua significativo (704s para a primeira remoção)

## Conclusão

O Cluster Autoscaler demonstrou melhoria significativa em seu desempenho de escalonamento após os ajustes. Pontos notáveis:

1. **Tempo de resposta melhorado**: Ambas as fases de escalonamento (10 e 30 réplicas) agora apresentam um tempo de resposta consistente de 75 segundos para o provisionamento de novos nós, independentemente da carga.

2. **Maior eficiência na densidade de pods**: Aumentou a densidade média para 3.0 pods/nó na carga máxima (30 réplicas), sugerindo melhor utilização dos recursos.

3. **Menor necessidade de nós**: O teste anterior necessitou de 11 nós para 30 réplicas, enquanto o atual utilizou apenas 10 nós para a mesma carga.

4. **Scale-down mais rápido**: O tempo para a primeira remoção de nó reduziu de 709s para 704s, e a duração total do scale-down diminuiu de 1415s para 1056s, representando uma melhoria de 25%.

5. **Estabilidade melhorada**: Os nós foram provisionados de forma mais consistente e previsível, indicando uma configuração mais estável.

Essas melhorias sugerem que as otimizações aplicadas ao Cluster Autoscaler foram eficazes em aumentar sua eficiência e responsividade. O tempo consistente de 75 segundos para o provisionamento de novos nós, independentemente da carga, é particularmente notável e beneficial para cargas de trabalho com rápidas variações de demanda.

Para trabalhos futuros, ainda seria interessante investigar maneiras de reduzir ainda mais o tempo de scale-down, que continua sendo a fase mais demorada do processo de escalonamento.
