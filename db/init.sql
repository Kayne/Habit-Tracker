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

-- =====================================================================
-- Migracje ręczne (brak Alembic — patrz AGENTS.md).
-- Uruchamiaj tylko na istniejących wolumenach (po `docker compose up`
-- bez flagi -v). Nowe wolumeny tworzą tabele przez SQLAlchemy create_all,
-- które uwzględnia już wszystkie kolumny z models.py.
-- =====================================================================

-- v2: dodanie frequency_type + zmiana nazwy target_per_week → target_per_frequency
-- ALTER TABLE habits_schema.habits
--     ADD COLUMN IF NOT EXISTS frequency_type VARCHAR(10) NOT NULL DEFAULT 'weekly';
-- ALTER TABLE habits_schema.habits
--     RENAME COLUMN target_per_week TO target_per_frequency;
