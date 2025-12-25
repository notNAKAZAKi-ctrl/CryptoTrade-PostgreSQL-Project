-- =============================================================================
-- SCHEMA MLD COMPLET – CRYPTOTRADE
-- Projet PostgreSQL – Optimisation plateforme de trading crypto
-- =============================================================================

-- 1. CRÉATION DU SCHÉMA ET EXTENSIONS
CREATE SCHEMA IF NOT EXISTS cryptotrade;
SET search_path = cryptotrade;

-- Activation des extensions (à exécuter une fois)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS auto_explain;

-- =============================================================================
-- 2. TABLES DE RÉFÉRENCE
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

-- =============================================================================
-- 3. TABLES DÉPENDANTES
-- =============================================================================

CREATE TABLE portefeuilles (
    id              BIGSERIAL PRIMARY KEY,
    utilisateur_id  BIGINT NOT NULL REFERENCES utilisateurs(id) ON DELETE CASCADE,
    crypto_id       INT NOT NULL REFERENCES cryptomonnaies(id),
    solde           NUMERIC(36,18) NOT NULL DEFAULT 0.0 CHECK (solde >= 0),       -- ✅ CORRIGÉ : solde (pas solde_total)
    solde_bloque    NUMERIC(36,18) NOT NULL DEFAULT 0.0 CHECK (solde_bloque >= 0),
    date_maj        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_utilisateur_crypto UNIQUE (utilisateur_id, crypto_id),
    CONSTRAINT chk_solde_portefeuille CHECK (solde >= solde_bloque)
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
-- 4. TABLES PARTITIONNÉES
-- =============================================================================

-- ORDRES (partitionné par date)
CREATE TABLE ordres (
    id              BIGSERIAL,
    utilisateur_id  BIGINT NOT NULL REFERENCES utilisateurs(id),
    paire_id        INT NOT NULL REFERENCES paire_trading(id),
    type_ordre      VARCHAR(10) NOT NULL CHECK (type_ordre IN ('BUY', 'SELL')),
    mode            VARCHAR(10) NOT NULL CHECK (mode IN ('MARKET', 'LIMIT')),
    quantite        NUMERIC(36,18) NOT NULL CHECK (quantite > 0),
    prix            NUMERIC(24,8),
    statut          VARCHAR(20) NOT NULL CHECK (statut IN ('EN_ATTENTE', 'EXECUTE', 'ANNULE')),
    date_creation   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, date_creation),
    CONSTRAINT chk_prix_limit CHECK (
        (mode = 'LIMIT' AND prix IS NOT NULL) OR
        (mode = 'MARKET' AND prix IS NULL)
    )
) PARTITION BY RANGE (date_creation);

-- Partitions ORDRES
CREATE TABLE ordres_p2025_12 PARTITION OF ordres FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE ordres_p2026_01 PARTITION OF ordres FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE ordres_p2026_02 PARTITION OF ordres FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE ordres_p2026_03 PARTITION OF ordres FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE ordres_default  PARTITION OF ordres DEFAULT;

-- TRADES (partitionné par date + avec paire_id ✅)
CREATE TABLE trades (
    id              BIGSERIAL,
    ordre_id        BIGINT NOT NULL, -- FK gérée au niveau applicatif (partitionnement)
    paire_id        INT NOT NULL REFERENCES paire_trading(id), -- ✅ AJOUTÉ
    prix            NUMERIC(24,8) NOT NULL CHECK (prix > 0),
    quantite        NUMERIC(36,18) NOT NULL CHECK (quantite > 0),
    date_execution  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, date_execution)
) PARTITION BY RANGE (date_execution);

-- Partitions TRADES
CREATE TABLE trades_p2025_12 PARTITION OF trades FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE trades_p2026_01 PARTITION OF trades FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE trades_p2026_02 PARTITION OF trades FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE trades_p2026_03 PARTITION OF trades FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE trades_default  PARTITION OF trades DEFAULT;

-- =============================================================================
-- 5. TABLES ANALYTIQUES & AUDIT
-- =============================================================================

CREATE TABLE prix_marche (
    id       BIGSERIAL PRIMARY KEY,
    paire_id INT NOT NULL REFERENCES paire_trading(id) UNIQUE,
    prix     NUMERIC(24,8) NOT NULL CHECK (prix > 0),
    volume   NUMERIC(36,8) NOT NULL DEFAULT 0 CHECK (volume >= 0),
    date_maj TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE statistique_marche (
    id         BIGSERIAL PRIMARY KEY,
    paire_id   INT NOT NULL REFERENCES paire_trading(id),
    indicateur VARCHAR(50) NOT NULL,
    valeur     NUMERIC,
    periode    VARCHAR(20) NOT NULL,
    date_maj   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (paire_id, indicateur, periode)
);

CREATE TABLE detection_anomalie (
    id             BIGSERIAL PRIMARY KEY,
    type           VARCHAR(50) NOT NULL,
    ordre_id       BIGINT,
    utilisateur_id BIGINT REFERENCES utilisateurs(id),
    date_detection TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    commentaire    TEXT
);

-- AUDIT_TRAIL (partitionné par action)
CREATE TABLE audit_trail (
    id            BIGSERIAL,
    table_cible   VARCHAR(50) NOT NULL,
    record_id     BIGINT NOT NULL,
    action        VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    utilisateur_id BIGINT REFERENCES utilisateurs(id),
    date_action   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    details       TEXT,
    PRIMARY KEY (id, action)
) PARTITION BY LIST (action);

CREATE TABLE audit_insert PARTITION OF audit_trail FOR VALUES IN ('INSERT');
CREATE TABLE audit_update PARTITION OF audit_trail FOR VALUES IN ('UPDATE');
CREATE TABLE audit_delete PARTITION OF audit_trail FOR VALUES IN ('DELETE');

-- =============================================================================
-- 6. INDEX STRATÉGIQUES
-- =============================================================================

-- UTILISATEURS
CREATE INDEX idx_utilisateurs_email ON utilisateurs(email);

-- CRYPTOMONNAIES
CREATE INDEX idx_crypto_symbole ON cryptomonnaies(symbole);

-- PAIRE_TRADING
CREATE INDEX idx_paire_base_contre ON paire_trading(crypto_base, crypto_contre);

-- PORTEFEUILLES
CREATE INDEX idx_portefeuilles_user ON portefeuilles(utilisateur_id);
CREATE INDEX idx_portefeuilles_user_crypto ON portefeuilles(utilisateur_id, crypto_id);

-- ORDRES
CREATE INDEX idx_ordres_paire_statut_prix ON ordres(paire_id, statut, prix)
  WHERE statut = 'EN_ATTENTE'; -- ✅ Partial index

CREATE INDEX idx_ordres_user ON ordres(utilisateur_id);
CREATE INDEX idx_ordres_date ON ordres(date_creation);

-- TRADES ✅ CORRIGÉ : index couvrant avec INCLUDE
CREATE INDEX idx_trades_covering ON trades(paire_id, date_execution) INCLUDE (prix, quantite);
CREATE INDEX idx_trades_ordre ON trades(ordre_id);

-- PRIX_MARCHE
CREATE INDEX idx_prix_paire ON prix_marche(paire_id);

-- STATISTIQUE_MARCHE
CREATE INDEX idx_stat_paire_indic ON statistique_marche(paire_id, indicateur);

-- DETECTION_ANOMALIE
CREATE INDEX idx_detection_user ON detection_anomalie(utilisateur_id);
CREATE INDEX idx_detection_ordre ON detection_anomalie(ordre_id);

-- AUDIT_TRAIL
CREATE INDEX idx_audit_table_record ON audit_trail(table_cible, record_id);
CREATE INDEX idx_audit_date ON audit_trail(date_action);

CREATE INDEX idx_audit_details_gin
ON audit_trail
USING GIN (to_tsvector('simple', details));


-- =============================================================================
-- FIN DU SCRIPT
-- =============================================================================
