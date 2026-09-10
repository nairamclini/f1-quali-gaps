-- 1:1 com o raw: tipagem e renomeacao.
-- A unica coisa acrescentada e o indice da amostra, porque a telemetria nao
-- tem chave natural: (piloto, volta, distancia) pode repetir se o carro estiver
-- parado. Sem chave nao ha teste `unique`, e sem teste o modelo nao avanca.

with source as (

    select * from {{ source('fastf1', 'telemetry') }}

),

indexed as (

    select
        *,
        -- Time_seconds e monotonico dentro da volta, entao a ordenacao e
        -- estavel entre execucoes -- requisito para a chave ser deterministica.
        row_number() over (
            partition by "Driver", "LapNumber"
            order by "Time_seconds"
        ) as sample_index
    from source

),

renamed as (

    select
        "season" || '-' || "round" || '-' || "session"
            || '-' || "Driver" || '-' || cast(cast("LapNumber" as integer) as varchar)
            || '-' || cast(sample_index as varchar)
            as telemetry_sample_id,

        cast("season" as integer) as season,
        cast("round" as integer) as round_number,
        "session" as session_name,

        "Driver" as driver_code,
        cast("LapNumber" as integer) as lap_number,
        sample_index,

        -- Distancia percorrida desde o inicio da volta. E a base da comparacao
        -- entre pilotos: o eixo x de toda a analise de gap.
        "Distance" as distance_m,
        -- Tempo decorrido desde o inicio da volta.
        "Time_seconds" as elapsed_seconds,

        "Speed" as speed_kph,
        "Throttle" as throttle_pct,
        "Brake" as is_braking,
        "nGear" as gear,
        "RPM" as rpm,
        "DRS" as drs

    from indexed

)

select * from renamed
