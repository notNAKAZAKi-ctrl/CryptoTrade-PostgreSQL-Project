-- =============================================================================
-- FONCTIONS STOCKÉES – Indicateurs de marché (VWAP, RSI, Volatilité)
-- Projet CryptoTrade – PostgreSQL
-- =============================================================================


-- 1. VWAP (Volume Weighted Average Price) sur une période donnée
CREATE OR REPLACE FUNCTION calculer_vwap(
    p_paire_id INT,
    p_periode INTERVAL DEFAULT '24 hours'
)
RETURNS NUMERIC AS $$
DECLARE
    v_vwap NUMERIC;
BEGIN
    SELECT COALESCE(SUM(prix * quantite) / NULLIF(SUM(quantite), 0), 0)
    INTO v_vwap
    FROM trades
    WHERE paire_id = p_paire_id
      AND date_execution >= NOW() - p_periode;

    RETURN v_vwap;
END;
$$ LANGUAGE plpgsql;



-- =============================================================================
-- 2. RSI (Relative Strength Index) – version simplifiée (moyenne arithmétique)
-- =============================================================================
CREATE OR REPLACE FUNCTION calculer_rsi(
    p_paire_id INT,
    p_periode INT DEFAULT 14
)
RETURNS NUMERIC AS $$
DECLARE
    v_rsi NUMERIC;
    avg_gain NUMERIC;
    avg_perte NUMERIC;
BEGIN
    WITH 
    prix_ordonnes AS (
        SELECT prix,
               LAG(prix) OVER (ORDER BY date_execution) AS prix_prec
        FROM trades
        WHERE paire_id = p_paire_id
        ORDER BY date_execution DESC
        LIMIT p_periode + 1
    ),
    variations AS (
        SELECT 
            prix - prix_prec AS delta
        FROM prix_ordonnes
        WHERE prix_prec IS NOT NULL
    ),
    gains_pertes AS (
        SELECT
            SUM(CASE WHEN delta > 0 THEN delta ELSE 0 END) AS total_gain,
            SUM(CASE WHEN delta < 0 THEN -delta ELSE 0 END) AS total_perte
        FROM variations
    )
    SELECT
        CASE
            WHEN total_perte = 0 THEN 100.0
            WHEN total_gain = 0 THEN 0.0
            ELSE 100.0 - (100.0 / (1.0 + (total_gain / p_periode) / (total_perte / p_periode)))
        END
    INTO v_rsi
    FROM gains_pertes;

    RETURN ROUND(v_rsi, 2);
END;
$$ LANGUAGE plpgsql;



-- =============================================================================
-- 3. Volatilité (écart-type des prix sur une période)
-- =============================================================================
CREATE OR REPLACE FUNCTION calculer_volatilite(
    p_paire_id INT,
    p_periode INTERVAL DEFAULT '24 hours'
)
RETURNS NUMERIC AS $$
DECLARE
    v_vol NUMERIC;
BEGIN
    SELECT COALESCE(STDDEV(prix), 0)
    INTO v_vol
    FROM trades
    WHERE paire_id = p_paire_id
      AND date_execution >= NOW() - p_periode;

    RETURN ROUND(v_vol, 6);
END;
$$ LANGUAGE plpgsql;



-- =============================================================================
-- FIN DES FONCTIONS – Tous les indicateurs du cahier des charges sont couverts
-- =============================================================================