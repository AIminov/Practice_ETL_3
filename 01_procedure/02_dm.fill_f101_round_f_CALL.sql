DO $$
DECLARE
    d DATE := DATE '2018-02-01';
BEGIN
    CALL dm.fill_f101_round_f(d);
END;
$$;

