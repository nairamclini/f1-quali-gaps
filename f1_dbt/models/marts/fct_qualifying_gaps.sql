-- O modelo de consumo. Uma linha por piloto por trecho de 100 m de pista.
--
-- Por que agregar aqui e nao antes: a grade de 501 pontos e a resolucao
-- necessaria para o *calculo* nao perder precisao; 100 m e a resolucao util
-- para a *decisao*. Um engenheiro de performance nao prioriza setup por fatia
-- de 10 m -- ele quer saber em qual curva o carro perde. Agregar so no fim
-- mantem o calculo preciso e a entrega legivel.
--
-- `nominal_distance_m` e escala de leitura, derivada da posicao relativa
-- (ADR-0004). A comparacao entre pilotos acontece em posicao relativa; os
-- metros existem para o trecho ter nome que um humano reconhece na pista.
--
-- A coluna que responde a pergunta de negocio e `delta_change_seconds`:
-- quanto tempo o piloto perdeu NESTE trecho. A acumulada mostra o placar;
-- esta mostra onde agir.

with delta as (

    select * from {{ ref('int_compute__delta_to_pole') }}

),

laps as (

    select * from {{ ref('stg_fastf1__laps') }}

),

drivers as (

    select * from {{ ref('dim_driver') }}

),

fastest_laps as (

    select
        driver_code,
        min(lap_time_seconds) as lap_time_seconds
    from laps
    where lap_time_seconds is not null
    group by driver_code

),

pole as (

    select min(lap_time_seconds) as pole_lap_time_seconds
    from fastest_laps

),

segmented as (

    select
        *,
        cast(floor(nominal_distance_m / 100) * 100 as integer) as segment_start_m
    from delta

),

aggregated as (

    select
        season,
        round_number,
        session_name,
        driver_code,
        segment_start_m,
        segment_start_m + 100 as segment_end_m,

        -- Soma do que foi perdido/ganho em cada fatia da grade dentro do
        -- trecho. O primeiro ponto de cada piloto nao tem anterior: vem nulo.
        sum(coalesce(delta_change_seconds, 0)) as delta_change_seconds,

        -- Delta acumulado no ponto mais avancado do trecho.
        arg_max(delta_to_pole_seconds, grid_index) as cumulative_delta_seconds,

        avg(speed_kph) as avg_speed_kph,
        avg(pole_speed_kph) as pole_avg_speed_kph,
        min(speed_kph) as min_speed_kph,
        count(*) as grid_points

    from segmented
    group by
        season,
        round_number,
        session_name,
        driver_code,
        segment_start_m

)

select
    a.season || '-' || a.round_number || '-' || a.session_name
        || '-' || a.driver_code || '-' || cast(a.segment_start_m as varchar)
        as gap_id,

    a.season,
    a.round_number,
    a.session_name,

    a.driver_code,
    d.team,

    a.segment_start_m,
    a.segment_end_m,

    a.delta_change_seconds,
    a.cumulative_delta_seconds,

    a.avg_speed_kph,
    a.pole_avg_speed_kph,
    a.avg_speed_kph - a.pole_avg_speed_kph as speed_delta_kph,
    -- Velocidade minima do trecho aproxima a velocidade de apice da curva:
    -- e onde diferenca de confianca e de setup mais aparece.
    a.min_speed_kph,

    f.lap_time_seconds,
    p.pole_lap_time_seconds,
    f.lap_time_seconds - p.pole_lap_time_seconds as total_gap_seconds,
    f.lap_time_seconds = p.pole_lap_time_seconds as is_pole_sitter,

    a.grid_points

from aggregated a
left join drivers d on d.driver_code = a.driver_code
left join fastest_laps f on f.driver_code = a.driver_code
cross join pole p
