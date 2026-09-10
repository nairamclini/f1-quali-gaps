-- Um piloto por linha. Existe para o fato nao carregar nome de equipe repetido
-- em cada uma das ~1.000 linhas de gap, e para dar um lugar unico onde
-- consertar grafia de equipe se ela vier inconsistente.

with laps as (

    select * from {{ ref('stg_fastf1__laps') }}

),

drivers as (

    select distinct
        driver_code,
        driver_number,
        team
    from laps

)

select
    driver_code,
    driver_number,
    team
from drivers
