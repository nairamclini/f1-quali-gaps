-- Responde a pergunta de negocio: onde, especificamente, cada piloto ganha ou
-- perde tempo em relacao ao pole sitter.
--
-- Duas colunas importam, e dizem coisas diferentes:
--   delta_to_pole_seconds  -- tempo acumulado perdido ate aqui (o placar)
--   delta_change_seconds   -- tempo perdido NESTE trecho da grade (a acao)
-- A segunda e a que o engenheiro de performance usa para priorizar setup.
--
-- O join e por `grid_index`, inteiro. Comparar posicao relativa em ponto
-- flutuante daria falha silenciosa de igualdade.

with grid_times as (

    select * from {{ ref('int_interpolate__telemetry_grid') }}

),

-- Pole vem do dado, nao de constante: menor tempo de volta valido e nao
-- deletado. Volta anulada por limite de pista nao vale pole.
pole_driver as (

    select driver_code
    from {{ ref('stg_fastf1__laps') }}
    where lap_time_seconds is not null
      and not is_deleted
    order by lap_time_seconds
    limit 1

),

pole_reference as (

    select
        g.grid_index,
        g.elapsed_seconds_at_grid as pole_elapsed_seconds,
        g.speed_kph as pole_speed_kph
    from grid_times g
    join pole_driver p on p.driver_code = g.driver_code

),

compared as (

    select
        g.grid_point_id,
        g.season,
        g.round_number,
        g.session_name,
        g.driver_code,
        g.grid_index,
        g.grid_relative_position,
        g.nominal_distance_m,
        g.elapsed_seconds_at_grid,
        p.pole_elapsed_seconds,
        g.speed_kph,
        p.pole_speed_kph,
        -- Positivo = perdendo tempo para o pole.
        g.elapsed_seconds_at_grid - p.pole_elapsed_seconds as delta_to_pole_seconds
    from grid_times g
    join pole_reference p on p.grid_index = g.grid_index

)

select
    grid_point_id,
    season,
    round_number,
    session_name,
    driver_code,
    grid_index,
    grid_relative_position,
    nominal_distance_m,
    elapsed_seconds_at_grid,
    pole_elapsed_seconds,
    speed_kph,
    pole_speed_kph,
    delta_to_pole_seconds,
    speed_kph - pole_speed_kph as speed_delta_kph,
    -- Derivada do delta acumulado: quanto foi perdido so neste trecho.
    delta_to_pole_seconds - lag(delta_to_pole_seconds) over (
        partition by driver_code
        order by grid_index
    ) as delta_change_seconds
from compared
