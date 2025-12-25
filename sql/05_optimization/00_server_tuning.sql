-- =============================================================================
-- TUNING & CONFIGURATION (Conforme Cahier des Charges Section 4)
-- =============================================================================

-- 1. OPTIMISATION MÉMOIRE (Work_mem)
-- Limiter les temp file spills sur agrégations lourdes (VWAP, RSI)
ALTER DATABASE postgres SET work_mem = '64MB'; 

-- 2. OPTIMISATION MAINTENANCE
ALTER DATABASE postgres SET maintenance_work_mem = '512MB';

-- 3. MONITORING
-- Permet de suivre les requêtes lentes (Bonus Dashboard)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 4. OPTIMISATION HOT UPDATES (Fillfactor)
-- Tables très modifiées : On laisse 10% de vide pour update rapide sans réécriture d'index
ALTER TABLE portefeuilles SET (fillfactor = 90);
ALTER TABLE prix_marche SET (fillfactor = 90);
ALTER TABLE ordres SET (fillfactor = 90); -- Ajouté pour gérer les changements de statut fréquents

-- 5. EXTENDED STATISTICS (Section "Rappel Technique" du CdC)
-- Aide le planner à comprendre la corrélation entre les colonnes

-- Pour les requêtes analytiques sur les ordres récents (Demandé explicitement)
CREATE STATISTICS s_ordres_paire_date (dependencies) ON paire_id, date_creation FROM ordres;

-- Pour les analyses de type d'ordre par paire
CREATE STATISTICS s_ordres_paire_type (dependencies) ON paire_id, type_ordre FROM ordres;

-- Analyse immédiate pour prise en compte
ANALYZE ordres;