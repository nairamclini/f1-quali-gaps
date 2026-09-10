-- Reconciliacao do metodo: o delta acumulado no fim da volta tem que bater com
-- a diferenca real entre os tempos de volta.
--
-- Este e o teste mais importante do projeto. Os outros verificam se o dado
-- chegou; este verifica se a *matematica* esta certa. O delta e construido
-- interpolando telemetria numa grade artificial -- se a reconstrucao
-- distorcesse o tempo, o erro apareceria aqui contra um numero que nao passou
-- por interpolacao nenhuma: o cronometro.
--
-- Este teste ja fez o seu trabalho uma vez. Com a grade em metros absolutos
-- (ADR-0003) ele reprovou, com vies sistematico correlacionado a -1,0 com a
-- distancia maxima de cada piloto. Foi o que motivou o ADR-0004.
--
-- Tolerancia de 0,01 s, e nao mais 0,25 s: na base relativa o ultimo ponto da
-- grade cai exatamente sobre a linha de chegada de cada piloto, sem
-- interpolacao. Nao ha fatia de pista fora da conta, entao nao ha folga
-- estrutural que justifique tolerancia larga.

with fastest_laps as (

    select
        driver_code,
        min(lap_time_seconds) as lap_time_seconds
    from {{ ref('stg_fastf1__laps') }}
    where lap_time_seconds is not null
    group by driver_code

),

pole as (

    select min(lap_time_seconds) as pole_lap_time_seconds
    from fastest_laps

),

final_delta as (

    select
        driver_code,
        -- arg_max: o delta no maior indice da grade, ou seja, na chegada.
        arg_max(delta_to_pole_seconds, grid_index) as interpolated_gap_seconds
    from {{ ref('int_compute__delta_to_pole') }}
    group by driver_code

),

compared as (

    select
        d.driver_code,
        d.interpolated_gap_seconds,
        f.lap_time_seconds - p.pole_lap_time_seconds as official_gap_seconds,
        abs(
            d.interpolated_gap_seconds - (f.lap_time_seconds - p.pole_lap_time_seconds)
        ) as difference_seconds
    from final_delta d
    join fastest_laps f on f.driver_code = d.driver_code
    cross join pole p

)

select *
from compared
where difference_seconds > 0.01
