-- Coloca a volta de todos os pilotos numa base comum de comparacao.
--
-- A base e POSICAO RELATIVA (0 = inicio da volta, 1 = linha de chegada), nao
-- metros absolutos. Ver ADR-0004 -- e uma correcao do ADR-0003, feita depois
-- de o metodo em metros ser reprovado pela reconciliacao.
--
-- Por que relativo funciona e absoluto nao: a distancia da FastF1 e derivada
-- integrando velocidade, entao acumula erro proprio de cada piloto. Na sessao
-- 2025 R01 a mesma volta mede de 5.219,6 m a 5.252,0 m conforme o carro. Em
-- metros, o ponto "5.000 m" e um lugar diferente da pista para cada um. Ja a
-- fracao da volta e consistente, porque foi medido que a telemetria de cada
-- piloto cobre exatamente uma volta cronometrada (sobra de tempo = 0,000 s
-- para os 19 pilotos).
--
-- O metodo continua sendo interpolacao linear, e nao "amostra mais proxima":
-- com espacamento nativo de ~9 m, arredondar erraria ate ~0,16 s a 200 km/h.

with telemetry as (

    select * from {{ ref('stg_fastf1__telemetry') }}

),

driver_bounds as (

    select
        driver_code,
        max(distance_m) as lap_distance_m
    from telemetry
    group by driver_code

),

relative as (

    select
        t.driver_code,
        t.season,
        t.round_number,
        t.session_name,
        t.sample_index,
        t.elapsed_seconds,
        t.speed_kph,
        -- Ultima amostra da volta cai exatamente em 1.0, porque e ela que
        -- define o denominador. Isso importa: garante que o ponto final da
        -- grade seja a linha de chegada de verdade, sem interpolacao.
        t.distance_m / b.lap_distance_m as relative_position
    from telemetry t
    join driver_bounds b on b.driver_code = t.driver_code

),

with_next_sample as (

    select
        driver_code,
        season,
        round_number,
        session_name,
        relative_position,
        elapsed_seconds,
        speed_kph,
        lead(relative_position) over (
            partition by driver_code order by sample_index
        ) as next_relative_position,
        lead(elapsed_seconds) over (
            partition by driver_code order by sample_index
        ) as next_elapsed_seconds
    from relative

),

-- 501 pontos: 0, 0.002, 0.004, ... 1.0. Gerado por inteiro e dividido depois
-- para evitar acumulo de erro de ponto flutuante num passo fracionario, e
-- para ter um indice inteiro exato como chave.
grid as (

    select
        cast(generate_series as integer) as grid_index,
        cast(generate_series as double) / 500.0 as grid_relative_position
    from generate_series(0, 500, 1)

),

drivers as (

    select distinct driver_code, season, round_number, session_name
    from telemetry

),

spine as (

    select
        d.driver_code,
        d.season,
        d.round_number,
        d.session_name,
        g.grid_index,
        g.grid_relative_position
    from drivers d
    cross join grid g

),

bracketed as (

    select
        s.driver_code,
        s.season,
        s.round_number,
        s.session_name,
        s.grid_index,
        s.grid_relative_position,
        t.relative_position,
        t.elapsed_seconds,
        t.next_relative_position,
        t.next_elapsed_seconds,
        t.speed_kph
    from spine s
    asof left join with_next_sample t
        on s.driver_code = t.driver_code
        and s.grid_relative_position >= t.relative_position

),

-- Escala nominal em metros, apenas para leitura humana e para agrupar em
-- trechos no mart. Nao e a base de comparacao -- a comparacao e relativa.
reference_scale as (

    select avg(lap_distance_m) as reference_lap_distance_m
    from driver_bounds

),

interpolated as (

    select
        b.driver_code,
        b.season,
        b.round_number,
        b.session_name,
        b.grid_index,
        b.grid_relative_position,
        b.grid_relative_position * r.reference_lap_distance_m as nominal_distance_m,
        b.speed_kph,
        case
            -- Ponto final da grade: cai exatamente sobre a ultima amostra, que
            -- nao tem proxima. Nao ha o que interpolar -- o valor ja e o certo.
            when b.next_relative_position is null
                then b.elapsed_seconds
            else
                b.elapsed_seconds
                + (b.next_elapsed_seconds - b.elapsed_seconds)
                * (b.grid_relative_position - b.relative_position)
                / nullif(b.next_relative_position - b.relative_position, 0)
        end as elapsed_seconds_at_grid
    from bracketed b
    cross join reference_scale r

)

select
    season || '-' || round_number || '-' || session_name
        || '-' || driver_code || '-' || cast(grid_index as varchar)
        as grid_point_id,
    driver_code,
    season,
    round_number,
    session_name,
    grid_index,
    grid_relative_position,
    nominal_distance_m,
    speed_kph,
    elapsed_seconds_at_grid
from interpolated
-- Nulo so aparece antes da primeira amostra do piloto. Descartar e correto:
-- o contrario seria extrapolar.
where elapsed_seconds_at_grid is not null
