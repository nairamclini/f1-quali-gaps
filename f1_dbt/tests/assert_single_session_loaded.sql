-- Trava de escopo: o pipeline so suporta uma sessao carregada por vez.
--
-- Por que isto existe: `driver_bounds`, `pole_driver` e o ASOF JOIN em
-- int_interpolate__telemetry_grid e int_compute__delta_to_pole agrupam e
-- comparam so por `driver_code`, sem particionar por sessao.
--
-- Testado na pratica com 2025 R01 + R02 carregados juntos: o pole global
-- (NOR, que correu nas duas) faz `pole_reference` ganhar duas linhas por
-- `grid_index` -- uma por sessao -- e o join em int_compute__delta_to_pole
-- multiplica cada linha por 2. Isso estourou o teste `unique` de
-- grid_point_id (19.500 duplicatas) e a reconciliacao (18 falhas). Falha
-- alta e obvia -- mas so porque o pole correu nas duas sessoes.
--
-- Se o pole global tivesse corrido em uma so sessao (reserva, substituicao,
-- round pulado), nao haveria fan-out: cada `grid_index` casaria com uma unica
-- linha de pole, e pilotos da OUTRA sessao seriam comparados contra o eixo de
-- tempo de uma sessao diferente -- delta errado, sem erro nenhum. E a mesma
-- classe de falha que o ADR-0003/0004 ja mostrou: numero errado sem aviso e
-- pior que build quebrado. Aqui o build quebrado foi sorte de calendario, nao
-- garantia do codigo -- e por isso esta trava explicita existe.
--
-- Quando o suporte a multi-sessao for implementado (particionar os models por
-- season/round/session), este teste deve ser removido ou substituido por uma
-- verificacao de consistencia por sessao.

with sessions as (

    select distinct
        season,
        round_number,
        session_name
    from {{ ref('stg_fastf1__laps') }}

),

counted as (

    select count(*) as session_count
    from sessions

)

select *
from counted
where session_count > 1
