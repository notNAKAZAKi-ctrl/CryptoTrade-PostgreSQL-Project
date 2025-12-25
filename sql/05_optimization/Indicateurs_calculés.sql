-- Vue matérialisée VWAP
CREATE MATERIALIZED VIEW mv_vwap AS
SELECT
    paire_id,
    SUM(prix * quantite) / SUM(quantite) AS vwap,
    MAX(date_execution) AS date_maj
FROM trades
WHERE date_execution >= NOW() - INTERVAL '24 hours'
GROUP BY paire_id;

-- Index pour accès rapide
CREATE INDEX idx_mv_vwap_paire ON mv_vwap(paire_id);

-- Vue matérialisée RSI
CREATE MATERIALIZED VIEW mv_rsi AS
WITH base AS (
    SELECT
        paire_id,
        date_execution,
        prix - LAG(prix) OVER (
            PARTITION BY paire_id
            ORDER BY date_execution
        ) AS variation
    FROM trades
)
SELECT
    paire_id,
    100 - (100 / (1 +
        AVG(CASE WHEN variation > 0 THEN variation ELSE 0 END)
        /
        NULLIF(AVG(CASE WHEN variation < 0 THEN ABS(variation) ELSE 0 END), 0)
    )) AS rsi
FROM base
GROUP BY paire_id;

-- index
CREATE INDEX idx_mv_rsi_paire ON mv_rsi(paire_id);

-- Vue matérialisée Volatilité
CREATE MATERIALIZED VIEW mv_volatilite AS
SELECT
    paire_id,
    date_trunc('hour', date_execution) AS heure,
    STDDEV(prix) AS volatilite
FROM trades
GROUP BY paire_id, date_trunc('hour', date_execution);

-- index
CREATE INDEX idx_mv_volatilite_paire ON mv_volatilite(paire_id);

-- Rafraîchissement contrôlé
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vwap;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_rsi;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_volatilite;