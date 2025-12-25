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
    prix            NUMERIC(24,8),
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