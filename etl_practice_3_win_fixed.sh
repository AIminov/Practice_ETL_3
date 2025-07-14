
# расчёт формы 101
set -e

# 1) явно сказали bash’у и psql работать в UTF-8
export LANG=ru_RU.UTF-8
export PGCLIENTENCODING=UTF8

echo "[STEP 1] создаем витрину dm.dm_f101_round_f"
psql -U postgres -d postgres -f ./00_ddl/00_dm.dm_f101_round_f.sql

echo "[STEP 2] создаем процедуру dm.fill_f101_round_f(i_OnDate)"
psql -U postgres -d postgres -f ./01_procedure/01_dm.fill_f101_round_f.sql

echo "[STEP 3] вызываем процедуру расчета формы 101 за январь 2018"
psql -U postgres -d postgres -f ./01_procedure/02_dm.fill_f101_round_f_CALL.sql

echo "[DONE] выполнение завершено"