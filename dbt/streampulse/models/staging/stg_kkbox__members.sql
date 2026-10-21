-- Grain: one row per member.
-- Staging = clean, typed, renamed. No business logic, no joins.

with source as (

    select * from {{ source('kkbox', 'members') }}

),

cleaned as (

    select
        trim(msno)                                         as member_id,
        city                                               as city_id,
        -- bd (age) has junk values (0, negatives, 1000+). Keep plausible ages only.
        case when bd between 10 and 80 then bd end         as age,
        case when bd between 10 and 80 then false else true end as is_age_missing_or_invalid,
        -- Empty gender is common; make "unknown" explicit instead of NULL/''.
        case when gender in ('male', 'female') then gender else 'unknown' end as gender,
        registered_via                                     as registration_channel_id,
        {{ parse_yyyymmdd('registration_init_time') }}     as registration_date

    from source

)

select * from cleaned
