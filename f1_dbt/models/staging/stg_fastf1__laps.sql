-- 1:1 com o raw: tipagem e renomeacao, nada de regra de negocio.
-- Nenhuma linha e filtrada aqui, nem as voltas invalidas -- filtrar e decisao
-- de negocio e mora no intermediate.

with source as (

    select * from {{ source('fastf1', 'laps') }}

),

renamed as (

    select
        -- Chave natural da volta. Concatenada em texto simples em vez de hash:
        -- da para ler no terminal e descobrir de que volta se trata.
        "season" || '-' || "round" || '-' || "session"
            || '-' || "Driver" || '-' || cast(cast("LapNumber" as integer) as varchar)
            as lap_id,

        cast("season" as integer) as season,
        -- O hive partitioning devolve 'round' como texto ('01'), nao numero.
        cast("round" as integer) as round_number,
        "session" as session_name,

        "Driver" as driver_code,
        "DriverNumber" as driver_number,
        "Team" as team,

        cast("LapNumber" as integer) as lap_number,
        cast("Stint" as integer) as stint,
        cast("Position" as integer) as position,

        "LapTime_seconds" as lap_time_seconds,
        "Sector1Time_seconds" as sector1_seconds,
        "Sector2Time_seconds" as sector2_seconds,
        "Sector3Time_seconds" as sector3_seconds,
        "LapStartTime_seconds" as lap_start_time_seconds,
        "LapStartDate" as lap_start_date,

        "SpeedI1" as speed_i1_kph,
        "SpeedI2" as speed_i2_kph,
        "SpeedFL" as speed_fl_kph,
        "SpeedST" as speed_st_kph,

        "Compound" as compound,
        cast("TyreLife" as integer) as tyre_life_laps,
        "FreshTyre" as is_fresh_tyre,

        "IsPersonalBest" as is_personal_best,
        "IsAccurate" as is_accurate,
        -- Deleted chega como inteiro anulavel; nulo aqui significa "nao deletada".
        coalesce(cast("Deleted" as boolean), false) as is_deleted,
        "DeletedReason" as deleted_reason,
        "TrackStatus" as track_status

    from source

)

select * from renamed
