-- Grain: one row per raw transaction row (duplicates still present; removed in intermediate).

with source as (

    select * from {{ source('kkbox', 'transactions') }}

),

renamed as (

    select
        trim(msno)                                          as member_id,
        payment_method_id,
        payment_plan_days                                   as plan_days,
        plan_list_price                                     as list_price_ntd,
        actual_amount_paid                                  as amount_paid_ntd,
        is_auto_renew = 1                                   as is_auto_renew,
        is_cancel = 1                                       as is_cancel,
        {{ parse_yyyymmdd('transaction_date') }}            as transaction_date,
        {{ parse_yyyymmdd('membership_expire_date') }}      as expire_date,
        source_file

    from source

)

select * from renamed
