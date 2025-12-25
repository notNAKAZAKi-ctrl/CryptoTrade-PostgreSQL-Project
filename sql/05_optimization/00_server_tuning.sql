-- =============================================================================
-- TUNING & CONFIGURATION (Cahier des charges Section 4)
-- =============================================================================

-- 1. OPTIMISATION MÉMOIRE (Pour éviter les temp file spills sur les gros tris)
-- On augmente la mémoire de travail pour les requêtes analytiques complexes
ALTER DATABASE postgres SET work_mem = '64MB'; 

-- 2. OPTIMISATION MAINTENANCE (VACUUM)
ALTER DATABASE postgres SET maintenance_work_mem = '512MB';

-- 3. MONITORING (pg_stat_statements)
-- Note: Doit être activé dans postgresql.conf (shared_preload_libraries)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 4. OPTIMISATION HOT UPDATES (Fillfactor)
-- On laisse 10% de place vide dans les pages pour les mises à jour rapides (HOT)
-- Surtout critique pour la table PORTEFEUILLES et PRIX_MARCHE qui bougent tout le temps
ALTER TABLE portefeuilles SET (fillfactor = 90);
ALTER TABLE prix_marche SET (fillfactor = 90);

-- 5. EXTENDED STATISTICS (Bonus Section 3)
-- Aide le planner à comprendre la corrélation entre les colonnes
CREATE STATISTICS s_ordres_paire_type (dependencies) ON paire_id, type_ordre FROM ordres;
