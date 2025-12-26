-- =============================================================================
-- TABLEAU DE BORD & MONITORING (FUSION FINAL)
-- =============================================================================
SET search_path = cryptotrade;

-- 1. VUES DÉTAILLÉES (Pour l'analyse approfondie)
-- -----------------------------------------------------------------------------

-- A. SÉCURITÉ : Qui sont les fraudeurs ?
CREATE OR REPLACE VIEW dashboard_securite AS
SELECT 
    da.type AS type_alerte,
    COUNT(*) AS nombre_cas,
    MAX(da.date_detection) AS derniere_detection,
    STRING_AGG(DISTINCT u.nom, ', ') AS suspects
FROM detection_anomalie da
JOIN utilisateurs u ON da.utilisateur_id = u.id
GROUP BY da.type;

-- B. PERFORMANCE : Quelles tables prennent de la place ?
CREATE OR REPLACE VIEW dashboard_performance AS
SELECT 
    relname AS table_nom,
    pg_size_pretty(pg_total_relation_size(relid)) AS taille_disque,
    seq_scan AS scans_lents_total,
    n_tup_ins AS lignes_inserees
FROM pg_stat_user_tables
ORDER BY seq_scan DESC;

-- 2. LA "SUPER VUE" SYNTHÉTIQUE (KPIs)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW dashboard_global_synthese AS

-- A. INDICATEURS BUSINESS
SELECT 
    'BUSINESS'::TEXT as categorie,
    'Ordres en attente'::TEXT as indicateur,
    count(*)::TEXT as valeur,
    'INFO'::TEXT as statut
FROM ordres WHERE statut = 'EN_ATTENTE'

UNION ALL

-- On prend le BTC comme référence de marché (plus logique qu'une moyenne globale)
SELECT 
    'BUSINESS', 
    'Prix Bitcoin (BTC)', 
    ROUND(prix, 2)::TEXT || ' $', 
    'INFO' 
FROM prix_marche 
WHERE paire_id = (SELECT id FROM paire_trading WHERE crypto_base = (SELECT id FROM cryptomonnaies WHERE symbole='BTC') LIMIT 1)

UNION ALL

-- B. INDICATEURS SÉCURITÉ
SELECT 
    'SÉCURITÉ', 
    'Alertes Fraude Total', 
    count(*)::TEXT, 
    CASE WHEN count(*) > 0 THEN '🔴 DANGER' ELSE '🟢 OK' END
FROM detection_anomalie

UNION ALL

-- C. INDICATEURS TECHNIQUES (Avec ton idée de Cache Hit Ratio !)
SELECT 
    'SYSTÈME', 
    'Santé du Cache (Hit Ratio)', 
    (SELECT round(sum(blks_hit)*100/nullif(sum(blks_hit+blks_read),0),2)::TEXT || ' %' 
     FROM pg_stat_database WHERE datname = current_database()), 
    '🟢 OPTIMAL' -- Si > 95% c'est excellent

UNION ALL

SELECT 
    'SYSTÈME', 
    'Taille Base de Données', 
    pg_size_pretty(pg_database_size(current_database()))::TEXT, 
    'INFO';