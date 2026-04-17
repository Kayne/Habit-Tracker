-- =====================================================================
-- Inicjalizacja bazy: tworzymy DWIE osobne schemy w jednej bazie.
-- Każdy mikroserwis ma własny "obszar" danych i NIE widzi cudzych tabel.
-- To kompromis między "wspólną bazą" (wymaganie projektowe) a izolacją
-- typową dla mikroserwisów.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS auth_schema;
CREATE SCHEMA IF NOT EXISTS habits_schema;

-- Użytkownik aplikacyjny (POSTGRES_USER) dostaje prawa do obu schem.
-- W prawdziwym projekcie stworzylibyśmy dwóch osobnych userów DB
-- (jeden per serwis) z prawami tylko do swojej schemy.
GRANT ALL ON SCHEMA auth_schema TO CURRENT_USER;
GRANT ALL ON SCHEMA habits_schema TO CURRENT_USER;
