# ADR-0003 — Grade comum de distância e método de interpolação

**Data:** 10/09/2026
**Status:** SUBSTITUÍDO pelo ADR-0004 no mesmo dia. A decisão de usar metros
absolutos foi reprovada pelo teste de reconciliação. O registro fica: o erro e
a evidência que o derrubou valem mais que a conclusão.

## Contexto

Comparar duas voltas exige compará-las no mesmo ponto da pista. O dado não
permite isso diretamente:

- Cada piloto tem cerca de 576 amostras por volta, tiradas em instantes
  distintos. A n-ésima amostra de um piloto não é o mesmo lugar da pista que a
  n-ésima de outro.
- A distância percorrida é derivada integrando a velocidade, então acumula
  erro. Medido na sessão 2025 R01: a distância máxima por piloto varia de
  **5.219,6 m a 5.252,0 m** — 32 m de diferença na mesma volta.
- O espaçamento nativo entre amostras é de cerca de **9 m**.

## Decisão

Reamostrar todas as voltas numa grade comum de **10 m**, por **interpolação
linear** entre as duas amostras que cercam cada ponto da grade.

A grade termina na **menor** distância máxima entre os pilotos. Pontos sem par
de amostras que os cercem são descartados.

O pole sitter é determinado pelo dado — menor tempo de volta não deletado — e
não por constante no código.

## Alternativas consideradas

- **ASOF JOIN puro (amostra anterior mais próxima).** É uma linha de SQL a
  menos e o DuckDB faz nativamente. Rejeitado por precisão: com espaçamento de
  ~9 m, o erro de posição chega a 9 m, que a 200 km/h equivale a **~0,16 s** —
  maior que a maioria dos gaps que o projeto quer medir. Mediria ruído.
- **Interpolação em Python (pandas/numpy).** Mais familiar, porém violaria
  "SQL para transformar, Python para mover" justamente no caso difícil, que é
  onde a regra vale alguma coisa. O DuckDB resolve com ASOF JOIN + `lead()`.
- **Grade de 1 m.** Dez vezes mais linhas para interpolar entre as mesmas
  amostras de 9 m. Precisão aparente, não real.
- **Grade de 50 m.** Rápida, mas engole curva inteira. A pergunta é "qual
  curva" — 50 m não responde.
- **Normalizar por `RelativeDistance` (0 a 1).** Resolveria a divergência de
  ~32 m por construção, mas o eixo deixaria de estar em metros e ficaria mais
  difícil de casar com referência de pista. Fica registrado como saída caso a
  divergência se mostre pior em circuito mais longo.

## Consequências

- A grade de 10 m é resolução suficiente para localizar curva, que é o nível
  da pergunta de negócio.
- Os primeiros e últimos metros da volta ficam de fora quando falta par para
  interpolar. Perda aceitável e explícita.
- A extração pega a volta mais rápida **sem** verificar se foi deletada. O
  modelo carrega `is_deleted` adiante em vez de decidir sozinho, mas se a
  volta mais rápida de um piloto tiver sido anulada, a telemetria dele será de
  uma volta que oficialmente não existe. Limitação conhecida. Verificado em
  2025 R01: nenhuma das voltas extraídas foi deletada, então a limitação não
  afeta esta sessão — mas continua valendo para as próximas.
- Valor fixo em 10 m no SQL, sem parametrização. Mudar exige editar o modelo —
  aceito, porque não há segundo consumidor pedindo outra resolução.
