# ADR-0003 — Grade comum de distancia e metodo de interpolacao

**Data:** 10/09/2026
**Status:** SUBSTITUIDO pelo ADR-0004 no mesmo dia. A decisao de usar metros
absolutos foi reprovada pelo teste de reconciliacao. O registro fica: o erro e
a evidencia que o derrubou valem mais que a conclusao.

## Contexto

Comparar duas voltas exige compara-las no mesmo ponto da pista. O dado nao
permite isso diretamente:

- Cada piloto tem cerca de 576 amostras por volta, tiradas em instantes
  distintos. A n-esima amostra de um piloto nao e o mesmo lugar da pista que a
  n-esima de outro.
- A distancia percorrida e derivada integrando a velocidade, entao acumula
  erro. Medido na sessao 2025 R01: a distancia maxima por piloto varia de
  **5.219,6 m a 5.252,0 m** — 32 m de diferenca na mesma volta.
- O espacamento nativo entre amostras e de cerca de **9 m**.

## Decisao

Reamostrar todas as voltas numa grade comum de **10 m**, por **interpolacao
linear** entre as duas amostras que cercam cada ponto da grade.

A grade termina na **menor** distancia maxima entre os pilotos. Pontos sem par
de amostras que os cercem sao descartados.

O pole sitter e determinado pelo dado — menor tempo de volta nao deletado — e
nao por constante no codigo.

## Alternativas consideradas

- **ASOF JOIN puro (amostra anterior mais proxima).** E uma linha de SQL a
  menos e o DuckDB faz nativamente. Rejeitado por precisao: com espacamento de
  ~9 m, o erro de posicao chega a 9 m, que a 200 km/h equivale a **~0,16 s** —
  maior que a maioria dos gaps que o projeto quer medir. Mediria ruido.
- **Interpolacao em Python (pandas/numpy).** Mais familiar, porem violaria
  "SQL para transformar, Python para mover" justamente no caso dificil, que e
  onde a regra vale alguma coisa. O DuckDB resolve com ASOF JOIN + `lead()`.
- **Grade de 1 m.** Dez vezes mais linhas para interpolar entre as mesmas
  amostras de 9 m. Precisao aparente, nao real.
- **Grade de 50 m.** Rapida, mas engole curva inteira. A pergunta e "qual
  curva" — 50 m nao responde.
- **Normalizar por `RelativeDistance` (0 a 1).** Resolveria a divergencia de
  25 m por construcao, mas o eixo deixaria de estar em metros e ficaria mais
  dificil de casar com referencia de pista. Fica registrado como saida caso a
  divergencia se mostre pior em circuito mais longo.

## Consequencias

- A grade de 10 m e resolucao suficiente para localizar curva, que e o nivel
  da pergunta de negocio.
- Os primeiros e ultimos metros da volta ficam de fora quando falta par para
  interpolar. Perda aceitavel e explicita.
- A extracao pega a volta mais rapida **sem** verificar se foi deletada. O
  modelo carrega `is_deleted` adiante em vez de decidir sozinho, mas se a
  volta mais rapida de um piloto tiver sido anulada, a telemetria dele sera de
  uma volta que oficialmente nao existe. Limitacao conhecida. Verificado em
  2025 R01: nenhuma das voltas extraidas foi deletada, entao a limitacao nao
  afeta esta sessao — mas continua valendo para as proximas.
- Valor fixo em 10 m no SQL, sem parametrizacao. Mudar exige editar o modelo —
  aceito, porque nao ha segundo consumidor pedindo outra resolucao.
