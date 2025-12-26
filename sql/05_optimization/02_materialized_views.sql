-- =============================================================================
-- VUES MATÉRIALISÉES (OPTIMISATION) - VERSION CORRIGÉE
-- =============================================================================
SET search_path = cryptotrade;

-- 1. VUE VWAP (Prix moyen pondéré)
CREATE MATERIALIZED VIEW mv_vwap AS
SELECT
    paire_id,
    SUM(prix * quantite) / NULLIF(SUM(quantite), 0) AS vwap,
    MAX(date_execution) AS date_maj
FROM trades
WHERE date_execution >= NOW() - INTERVAL '24 hours'
GROUP BY paire_id;

-- ✅ CORRECTIF : Index UNIQUE obligatoire pour REFRESH CONCURRENTLY
CREATE UNIQUE INDEX idx_mv_vwap_paire ON mv_vwap(paire_id);


-- 2. VUE RSI (Indicateur Force Relative)
CREATE MATERIALIZED VIEW mv_rsi AS
WITH base AS (
    SELECT
        paire_id,
        date_execution,
        prix - LAG(prix) OVER (PARTITION BY paire_id ORDER BY date_execution) AS variation
    FROM trades
)
SELECT
    paire_id,
    100 - (100 / (1 +
        NULLIF(AVG(CASE WHEN variation > 0 THEN variation ELSE 0 END), 0)
        /
        NULLIF(AVG(CASE WHEN variation < 0 THEN ABS(variation) ELSE 0 END), 0)
    )) AS rsi
FROM base
GROUP BY paire_id;

-- ✅ CORRECTIF : Index UNIQUE
CREATE UNIQUE INDEX idx_mv_rsi_paire ON mv_rsi(paire_id);


-- 3. VUE VOLATILITÉ
CREATE MATERIALIZED VIEW mv_volatilite AS
SELECT
    paire_id,
    date_trunc('hour', date_execution) AS heure,
    STDDEV(prix) AS volatilite
FROM trades
GROUP BY paire_id, date_trunc('hour', date_execution);

-- ✅ CORRECTIF : Index UNIQUE Composite
CREATE UNIQUE INDEX idx_mv_volatilite_composite ON mv_volatilite(paire_id, heure);

-- 4. RAFRAÎCHISSEMENT
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vwap;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_rsi;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_volatilite;