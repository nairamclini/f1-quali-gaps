-- Reconciliacao: a soma dos tres setores tem que dar o tempo da volta.
--
-- Este teste nao valida transformacao minha -- valida a premissa de que
-- `LapTime` e `SectorNTime` da FastF1 descrevem a mesma volta. Se ele falhar,
-- o problema esta no entendimento do dado de origem, e todo delta calculado
-- em cima disso fica suspeito. E o teste mais barato que existe contra
-- "o numero saiu, entao deve estar certo".
--
-- Tolerancia de 0,05 s: os quatro campos sao gravados com arredondamento
-- independente, entao exigir igualdade exata acusaria ruido de arredondamento
-- como erro. Acima disso nao e arredondamento, e premissa errada.

with laps as (

    select * from {{ ref('stg_fastf1__laps') }}

),

reconciled as (

    select
        lap_id,
        driver_code,
        lap_number,
        lap_time_seconds,
        sector1_seconds + sector2_seconds + sector3_seconds as sum_of_sectors_seconds,
        abs(
            (sector1_seconds + sector2_seconds + sector3_seconds) - lap_time_seconds
        ) as difference_seconds
    from laps
    -- Volta sem tempo ou sem algum setor nao e violacao: e volta incompleta
    -- (saida de box, volta abortada). Nao ha o que reconciliar.
    where lap_time_seconds is not null
      and sector1_seconds is not null
      and sector2_seconds is not null
      and sector3_seconds is not null

)

select *
from reconciled
where difference_seconds > 0.05
