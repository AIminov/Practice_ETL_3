CREATE OR REPLACE PROCEDURE dm.fill_f101_round_f(i_OnDate DATE)
LANGUAGE plpgsql
AS $$
DECLARE
    v_FromDate DATE;
    v_ToDate   DATE;
    v_StartLog TIMESTAMP;
BEGIN
    -- 1. Устанавливаем границы периода
    v_FromDate := (i_OnDate - INTERVAL '1 month')::DATE;
    v_ToDate   := (i_OnDate - INTERVAL '1 day')::DATE;
    v_StartLog := clock_timestamp();

    -- 2. Удаляем старые данные за расчётный период
    DELETE FROM dm.dm_f101_round_f
    WHERE from_date = v_FromDate AND to_date = v_ToDate;

    -- 3. Вставляем агрегированные данные
    INSERT INTO dm.dm_f101_round_f (
        from_date, to_date, chapter, ledger_account, characteristic,
        balance_in_rub, balance_in_val, balance_in_total,
        turn_deb_rub, turn_deb_val, turn_deb_total,
        turn_cre_rub, turn_cre_val, turn_cre_total,
        balance_out_rub, balance_out_val, balance_out_total
    )
    SELECT
        v_FromDate,
        v_ToDate,
        l.chapter,
        SUBSTRING(a.account_number, 1, 5) AS ledger_account,
        a.char_type,
        
        -- Остатки на начало
        SUM(CASE WHEN a.currency_code IN ('810', '643') THEN COALESCE(b_in.balance_out_rub, 0) ELSE 0 END) AS balance_in_rub,
        SUM(CASE WHEN a.currency_code NOT IN ('810', '643') THEN COALESCE(b_in.balance_out_rub, 0) ELSE 0 END) AS balance_in_val,
        SUM(COALESCE(b_in.balance_out_rub, 0)) AS balance_in_total,

        -- Обороты дебет
        SUM(CASE WHEN a.currency_code IN ('810', '643') THEN COALESCE(t.debet_amount_rub, 0) ELSE 0 END) AS turn_deb_rub,
        SUM(CASE WHEN a.currency_code NOT IN ('810', '643') THEN COALESCE(t.debet_amount_rub, 0) ELSE 0 END) AS turn_deb_val,
        SUM(COALESCE(t.debet_amount_rub, 0)) AS turn_deb_total,

        -- Обороты кредит
        SUM(CASE WHEN a.currency_code IN ('810', '643') THEN COALESCE(t.credit_amount_rub, 0) ELSE 0 END) AS turn_cre_rub,
        SUM(CASE WHEN a.currency_code NOT IN ('810', '643') THEN COALESCE(t.credit_amount_rub, 0) ELSE 0 END) AS turn_cre_val,
        SUM(COALESCE(t.credit_amount_rub, 0)) AS turn_cre_total,

        -- Остатки на конец
        SUM(CASE WHEN a.currency_code IN ('810', '643') THEN COALESCE(b_out.balance_out_rub, 0) ELSE 0 END) AS balance_out_rub,
        SUM(CASE WHEN a.currency_code NOT IN ('810', '643') THEN COALESCE(b_out.balance_out_rub, 0) ELSE 0 END) AS balance_out_val,
        SUM(COALESCE(b_out.balance_out_rub, 0)) AS balance_out_total

    FROM ds.md_account_d a
    LEFT JOIN dm.dm_account_balance_f b_in
        ON b_in.account_rk = a.account_rk AND b_in.on_date = v_FromDate - INTERVAL '1 day'
    LEFT JOIN dm.dm_account_balance_f b_out
        ON b_out.account_rk = a.account_rk AND b_out.on_date = v_ToDate
    LEFT JOIN dm.dm_account_turnover_f t
        ON t.account_rk = a.account_rk AND t.on_date BETWEEN v_FromDate AND v_ToDate
    LEFT JOIN ds.md_ledger_account_s l
    	ON l.ledger_account = SUBSTRING(a.account_number, 1, 5)::INTEGER
    WHERE a.data_actual_end_date >= v_ToDate
      AND a.data_actual_date <= v_FromDate
    GROUP BY
        l.chapter,
        SUBSTRING(a.account_number, 1, 5),
        a.char_type;

    -- 4. Логирование
    INSERT INTO logs.etl_proc_log (procedure_name, on_date, log_dt, message)
    VALUES ('dm.fill_f101_round_f', i_OnDate, clock_timestamp(),
            FORMAT('Форма 101 успешно рассчитана за %s (from %s to %s)', i_OnDate, v_FromDate, v_ToDate));
END;
$$;

