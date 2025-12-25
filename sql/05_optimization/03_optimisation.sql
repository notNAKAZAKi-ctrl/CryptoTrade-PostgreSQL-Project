-- =============================================================================
-- SCHEMA FINAL OPTIMISÉ – CRYPTOTRADE
-- Objectif : Latence < 5ms, Zéro Deadlock, Analytics Performants
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS cryptotrade;
SET search_path = cryptotrade;

-- Extensions pour le monitoring et la performance
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS auto_explain;
-- =============================================================================
-- 1. TABLES DE RÉFÉRENCE
-- =============================================================================

CREATE TABLE utilisateurs (
    id              BIGSERIAL PRIMARY KEY,
    nom             VARCHAR(50) NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,
    date_inscription DATE NOT NULL DEFAULT CURRENT_DATE,
    statut          VARCHAR(20) NOT NULL CHECK (statut IN ('ACTIF', 'INACTIF'))
);

CREATE TABLE cryptomonnaies (
    id              SERIAL PRIMARY KEY,
    nom             VARCHAR(50) NOT NULL,
    symbole         VARCHAR(10) NOT NULL UNIQUE,
    date_creation   DATE,
    statut          VARCHAR(20) NOT NULL CHECK (statut IN ('ACTIVE', 'DESACTIVE'))
);

CREATE TABLE paire_trading (
    id              SERIAL PRIMARY KEY,
    crypto_base     INT NOT NULL REFERENCES cryptomonnaies(id),
    crypto_contre   INT NOT NULL REFERENCES cryptomonnaies(id),
    statut          VARCHAR(20) NOT NULL CHECK (statut IN ('ACTIVE', 'SUSPENDUE')),
    date_ouverture  DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT uq_paire UNIQUE (crypto_base, crypto_contre),
    CONSTRAINT chk_crypto_diff CHECK (crypto_base <> crypto_contre)
);

-- =============================================================================
-- 2. TABLES À FORTE MISE À JOUR (Optimisation HOT Updates / Fillfactor)
-- =============================================================================

CREATE TABLE portefeuilles (
    id              BIGSERIAL PRIMARY KEY,
    utilisateur_id  BIGINT NOT NULL REFERENCES utilisateurs(id) ON DELETE CASCADE,
    crypto_id       INT NOT NULL REFERENCES cryptomonnaies(id),
    solde           NUMERIC(36,18) NOT NULL DEFAULT 0.0 CHECK (solde >= 0),
    solde_bloque    NUMERIC(36,18) NOT NULL DEFAULT 0.0 CHECK (solde_bloque >= 0),
    date_maj        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_utilisateur_crypto UNIQUE (utilisateur_id, crypto_id),
    CONSTRAINT chk_solde_portefeuille CHECK (solde >= solde_bloque)
) WITH (fillfactor = 80); -- Réduit le Vacuum Lag

CREATE TABLE prix_marche (
    id       BIGSERIAL PRIMARY KEY,
    paire_id INT NOT NULL REFERENCES paire_trading(id) UNIQUE,
    prix     NUMERIC(24,8) NOT NULL CHECK (prix > 0),
    volume   NUMERIC(36,8) NOT NULL DEFAULT 0 CHECK (volume >= 0),
    date_maj TIMESTAMPTZ NOT NULL DEFAULT NOW()
) WITH (fillfactor = 80);

-- =============================================================================
-- 3. TABLES PARTITIONNÉES (Gestion de millions de lignes)
-- =============================================================================

CREATE TABLE ordres (
    id              BIGSERIAL,
    utilisateur_id  BIGINT NOT NULL REFERENCES utilisateurs(id),
    paire_id        INT NOT NULL REFERENCES paire_trading(id),
    type_ordre      VARCHAR(10) NOT NULL CHECK (type_ordre IN ('BUY', 'SELL')),
    mode            VARCHAR(10) NOT NULL CHECK (mode IN ('MARKET', 'LIMIT')),
    quantite        NUMERIC(36,18) NOT NULL CHECK (quantite > 0),
    quantite_restante NUMERIC(36,18) NOT NULL,
    prix            NUMERIC(24,8) NOT NULL CHECK (prix > 0),
    statut          VARCHAR(20) NOT NULL CHECK (statut IN ('EN_ATTENTE', 'EXECUTE', 'ANNULE')),
    date_creation   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, date_creation)
) PARTITION BY RANGE (date_creation);

CREATE TABLE trades (
    id              BIGSERIAL,
    ordre_id        BIGINT NOT NULL,
    paire_id        INT NOT NULL REFERENCES paire_trading(id),
    acheteur_id     BIGINT NOT NULL REFERENCES utilisateurs(id),
    vendeur_id      BIGINT NOT NULL REFERENCES utilisateurs(id),
    prix            NUMERIC(24,8) NOT NULL CHECK (prix > 0),
    quantite        NUMERIC(36,18) NOT NULL CHECK (quantite > 0),
    date_execution  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, date_execution)
) PARTITION BY RANGE (date_execution);

CREATE TABLE audit_trail (
    id              BIGSERIAL,
    table_cible     VARCHAR(50) NOT NULL,
    record_id       BIGINT NOT NULL,
    action          VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    utilisateur_id  BIGINT REFERENCES utilisateurs(id),
    date_action     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    details         TEXT,
    PRIMARY KEY (id, date_action)
) PARTITION BY RANGE (date_action);

-- =============================================================================
-- AUTOMATISATION DES PARTITIONS 
-- =============================================================================

-- Fonction Générique de création de partition
CREATE OR REPLACE FUNCTION cryptotrade.fn_auto_partition()
RETURNS TRIGGER AS $$
DECLARE
    v_table_name TEXT := TG_TABLE_NAME;
    v_partition_name TEXT;
    v_start_date DATE;
    v_end_date DATE;
BEGIN
    -- Format du nom : table_p2025_12
    v_partition_name := v_table_name || '_p' || to_char(NEW.date_creation, 'YYYY_MM');
    
    -- Pour la table audit_trail, la colonne s'appelle date_action et non date_creation
    IF v_table_name = 'audit_trail' THEN
        v_partition_name := v_table_name || '_p' || to_char(NEW.date_action, 'YYYY_MM');
        v_start_date := date_trunc('month', NEW.date_action);
    ELSE
        v_start_date := date_trunc('month', NEW.date_creation);
    END IF;
    
    v_end_date := v_start_date + INTERVAL '1 month';

    -- Création si n'existe pas
    IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace 
                   WHERE c.relname = v_partition_name AND n.nspname = 'cryptotrade') THEN
        
        EXECUTE format(
            'CREATE TABLE cryptotrade.%I PARTITION OF cryptotrade.%I FOR VALUES FROM (%L) TO (%L)',
            v_partition_name, v_table_name, v_start_date, v_end_date
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Application des triggers aux 3 tables volumineuses
CREATE TRIGGER trg_partition_ordres BEFORE INSERT ON ordres FOR EACH ROW EXECUTE FUNCTION fn_auto_partition();
CREATE TRIGGER trg_partition_trades BEFORE INSERT ON trades FOR EACH ROW EXECUTE FUNCTION fn_auto_partition();
CREATE TRIGGER trg_partition_audit BEFORE INSERT ON audit_trail FOR EACH ROW EXECUTE FUNCTION fn_auto_partition();

-- =============================================================================
-- 4. TABLES ANALYTIQUES ET ANOMALIES
-- =============================================================================

CREATE TABLE statistique_marche (
    id         BIGSERIAL PRIMARY KEY,
    paire_id   INT NOT NULL REFERENCES paire_trading(id),
    indicateur VARCHAR(50) NOT NULL, -- RSI, VWAP, Volatilité
    valeur     NUMERIC,
    periode    VARCHAR(20) NOT NULL,
    date_maj   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (paire_id, indicateur, periode)
);

CREATE TABLE detection_anomalie (
    id             BIGSERIAL PRIMARY KEY,
    type           VARCHAR(50) NOT NULL, -- WASH_TRADING, SPOOFING
    ordre_id       BIGINT,
    utilisateur_id BIGINT REFERENCES utilisateurs(id),
    date_detection TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    commentaire    TEXT
);

-- =============================================================================
-- 4. ANALYTIQUES AVANCÉES (Vues Matérialisées)
-- =============================================================================

-- 1. VWAP (Volume Weighted Average Price) sur 24h
CREATE MATERIALIZED VIEW mv_vwap AS
SELECT
    paire_id,
    SUM(prix * quantite) / NULLIF(SUM(quantite), 0) AS vwap,
    MAX(date_execution) AS last_update
FROM trades
WHERE date_execution >= NOW() - INTERVAL '24 hours'
GROUP BY paire_id;

-- Index UNIQUE obligatoire pour le rafraîchissement CONCURRENT
CREATE UNIQUE INDEX idx_mv_vwap_unique ON mv_vwap(paire_id);

-- 2. RSI (Relative Strength Index)
CREATE MATERIALIZED VIEW mv_rsi AS
WITH base AS (
    SELECT
        paire_id,
        date_execution,
        prix - LAG(prix) OVER (PARTITION BY paire_id ORDER BY date_execution) AS variation
    FROM trades
    WHERE date_execution >= NOW() - INTERVAL '24 hours' -- Limiter la fenêtre pour la performance
)
SELECT
    paire_id,
    100 - (100 / (1 + 
        NULLIF(AVG(CASE WHEN variation > 0 THEN variation ELSE 0 END), 0) 
        / 
        NULLIF(AVG(CASE WHEN variation < 0 THEN ABS(variation) ELSE 0 END), 1)
    )) AS rsi,
    NOW() as last_update
FROM base
GROUP BY paire_id;

CREATE UNIQUE INDEX idx_mv_rsi_unique ON mv_rsi(paire_id);

-- 3. Volatilité horaire
CREATE MATERIALIZED VIEW mv_volatilite AS
SELECT
    paire_id,
    date_trunc('hour', date_execution) AS heure,
    STDDEV(prix) AS volatilite
FROM trades
GROUP BY paire_id, date_trunc('hour', date_execution);

-- Index unique sur le couple paire/heure
CREATE UNIQUE INDEX idx_mv_vol_unique ON mv_volatilite(paire_id, heure);

-- =============================================================================
-- BONUS : PROCEDURE DE MISE À JOUR AUTOMATIQUE
-- =============================================================================
-- Cette procédure peut être appelée par un cron job ou après un gros batch de trades
CREATE OR REPLACE PROCEDURE rafraichir_indicateurs()
LANGUAGE plpgsql AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_vwap;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_rsi;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_volatilite;
END;
$$;

-- =============================================================================
-- 5. INDEXATION STRATÉGIQUE (Le coeur de la performance)
-- =============================================================================

CREATE INDEX idx_utilisateurs_email ON utilisateurs(email);
CREATE INDEX idx_crypto_symbole ON cryptomonnaies(symbole);
CREATE INDEX idx_portefeuilles_user ON portefeuilles(utilisateur_id);
CREATE INDEX idx_audit_table_record ON audit_trail(table_cible, record_id);

-- Performance Trading (Optimisés)
-- Index PARTIEL : ne contient que les ordres actifs. Taille réduite = Vitesse max.
CREATE INDEX idx_ordres_active_book ON ordres (paire_id, prix DESC, date_creation ASC) 
WHERE statut = 'EN_ATTENTE';

-- Index couvrant pour l'analytique (VWAP)
CREATE INDEX idx_trades_analytics ON trades (paire_id, date_execution) INCLUDE (prix, quantite);

-- Statistiques pour aider le query planner
CREATE STATISTICS st_ordres_stat ON statut, type_ordre FROM ordres;

-- =============================================================================
-- 6. PROCÉDURE DE MATCHING (Anti-Deadlock avec SKIP LOCKED)
-- =============================================================================

CREATE OR REPLACE PROCEDURE executer_matching(p_ordre_id BIGINT, p_date TIMESTAMPTZ)
LANGUAGE plpgsql AS $$
DECLARE
    v_ordre RECORD;
    v_match RECORD;
BEGIN
    -- Verrouille l'ordre entrant
    SELECT * INTO v_ordre FROM ordres WHERE id = p_ordre_id AND date_creation = p_date FOR UPDATE;

    -- Cherche une contrepartie sans bloquer les autres workers (SKIP LOCKED)
    SELECT * INTO v_match 
    FROM ordres 
    WHERE paire_id = v_ordre.paire_id 
      AND statut = 'EN_ATTENTE' 
      AND type_ordre <> v_ordre.type_ordre
      AND (CASE WHEN v_ordre.type_ordre = 'BUY' THEN prix <= v_ordre.prix ELSE prix >= v_ordre.prix END)
    ORDER BY prix (CASE WHEN v_ordre.type_ordre = 'BUY' THEN ASC ELSE DESC END), date_creation ASC
    FOR UPDATE SKIP LOCKED
    LIMIT 1;

    IF FOUND THEN
        -- Ici tu insères le trade et updates les statuts (simplifié pour le code)
        UPDATE ordres SET statut = 'EXECUTE' WHERE id IN (v_ordre.id, v_match.id);
    END IF;
END;
$$;

-- Fonction de détection automatique
CREATE OR REPLACE FUNCTION fn_analyse_comportement_suspect()
RETURNS TRIGGER AS $$
DECLARE
    v_nb_annulations INT;
BEGIN
    -- 1. DETECTION WASH TRADING (Sur la table TRADES)
    IF TG_TABLE_NAME = 'trades' THEN
        IF NEW.acheteur_id = NEW.vendeur_id THEN
            INSERT INTO detection_anomalie (type, ordre_id, utilisateur_id, commentaire)
            VALUES ('WASH_TRADING', NEW.ordre_id, NEW.acheteur_id, 
                   format('Auto-trade détecté : l''utilisateur a matché son propre ordre sur la paire %s', NEW.paire_id));
        END IF;
    END IF;

    -- 2. DETECTION SPOOFING (Sur la table ORDRES)
    -- On cherche si l'utilisateur a annulé beaucoup d'ordres importants en peu de temps
    IF TG_TABLE_NAME = 'ordres' AND NEW.statut = 'ANNULE' THEN
        SELECT COUNT(*) INTO v_nb_annulations
        FROM ordres
        WHERE utilisateur_id = NEW.utilisateur_id
          AND statut = 'ANNULE'
          AND date_creation > NOW() - INTERVAL '10 minutes';

        IF v_nb_annulations > 10 THEN
            INSERT INTO detection_anomalie (type, ordre_id, utilisateur_id, commentaire)
            VALUES ('SPOOFING', NEW.id, NEW.utilisateur_id, 
                   format('Pattern suspect : %s annulations en moins de 10 minutes', v_nb_annulations));
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Activation des triggers
CREATE TRIGGER trg_detect_wash_trade AFTER INSERT ON trades FOR EACH ROW EXECUTE FUNCTION fn_analyse_comportement_suspect();
CREATE TRIGGER trg_detect_spoofing AFTER UPDATE ON ordres FOR EACH ROW WHEN (NEW.statut = 'ANNULE') EXECUTE FUNCTION fn_analyse_comportement_suspect();


-- =============================================================================
-- INSERTION DE QUELQUES FRAUDES POUR TESTER (VERSION CORRIGÉE)
-- =============================================================================

CREATE OR REPLACE PROCEDURE cryptotrade.simuler_scenarios_fraude()
LANGUAGE plpgsql AS $$
DECLARE
    v_now TIMESTAMPTZ := NOW(); -- On utilise la même seconde pour tout le test
    v_ordre_id BIGINT;
BEGIN
    -- Nettoyage pour repartir sur un test propre
    DELETE FROM cryptotrade.detection_anomalie;

    -- SCÉNARIO 1 : Simulation Wash Trading
    -- Un utilisateur crée un trade où il est acheteur ET vendeur
    RAISE NOTICE 'Simulation Wash Trading...';
    INSERT INTO cryptotrade.trades (ordre_id, paire_id, acheteur_id, vendeur_id, prix, quantite, date_execution)
    VALUES (999, 1, 100, 100, 50000, 0.5, v_now); -- Ajout de date_execution pour le partitionnement

    -- SCÉNARIO 2 : Simulation Spoofing
    -- Un utilisateur crée et annule rapidement 11 ordres
    RAISE NOTICE 'Simulation Spoofing...';
    FOR i IN 1..11 LOOP
        -- 1. Insertion de l'ordre avec date_creation
        INSERT INTO cryptotrade.ordres (utilisateur_id, paire_id, type_ordre, mode, quantite, quantite_restante, prix, statut, date_creation)
        VALUES (200, 1, 'BUY', 'LIMIT', 10, 10, 49000, 'EN_ATTENTE', v_now)
        RETURNING id INTO v_ordre_id;
        
        -- 2. Annulation immédiate (déclenche le trigger fn_analyse_comportement_suspect)
        -- Important : on précise la date dans le WHERE pour que PostgreSQL cible la bonne partition
        UPDATE cryptotrade.ordres 
        SET statut = 'ANNULE' 
        WHERE id = v_ordre_id AND date_creation = v_now;
    END LOOP;

    RAISE NOTICE 'Simulation terminée. Vérifiez la table detection_anomalie.';
END;
$$;