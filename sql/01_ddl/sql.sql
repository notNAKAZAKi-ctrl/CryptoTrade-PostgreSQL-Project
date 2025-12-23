-- Initialisation du Schéma
CREATE SCHEMA IF NOT EXISTS cryptotrade;
SET search_path = cryptotrade;

-- =============================================
-- 1. TABLES DE RÉFÉRENCE (A créer en premier !)
-- =============================================

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

-- =============================================
-- 2. TABLES DÉPENDANTES (Besoin des refs ci-dessus)
-- =============================================

CREATE TABLE portefeuilles (
    id              BIGSERIAL PRIMARY KEY,
    utilisateur_id  BIGINT NOT NULL REFERENCES utilisateurs(id),
    crypto_id       INT NOT NULL REFERENCES cryptomonnaies(id),
    solde_total     NUMERIC(20,8) NOT NULL CHECK (solde_total >= 0),
    solde_bloque    NUMERIC(20,8) NOT NULL CHECK (solde_bloque >= 0),
    date_maj        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_utilisateur_crypto UNIQUE (utilisateur_id, crypto_id),
    CONSTRAINT chk_solde_portefeuille CHECK (solde_total >= solde_bloque)
);

CREATE TABLE paire_trading (
    id              SERIAL PRIMARY KEY,
    crypto_base     INT NOT NULL REFERENCES cryptomonnaies(id),
    crypto_contre   INT NOT NULL REFERENCES cryptomonnaies(id),
    statut          VARCHAR(20) NOT NULL CHECK (statut IN ('ACTIVE', 'SUSPENDUE')),
    date_ouverture  DATE NOT NULL,
    CONSTRAINT uq_paire UNIQUE (crypto_base, crypto_contre),
    CONSTRAINT chk_crypto_diff CHECK (crypto_base <> crypto_contre)
);

-- =============================================
-- 3. TABLES PARTITIONNÉES (Le coeur du sujet)
-- =============================================

-- Table ORDRES : Partitionnée par RANGE (date_creation)
CREATE TABLE ordres (
    id              BIGSERIAL, -- Pas de PK simple ici
    utilisateur_id  BIGINT NOT NULL REFERENCES utilisateurs(id),
    paire_id        INT NOT NULL REFERENCES paire_trading(id),
    type_ordre      VARCHAR(10) NOT NULL CHECK (type_ordre IN ('BUY', 'SELL')),
    mode            VARCHAR(10) NOT NULL CHECK (mode IN ('MARKET', 'LIMIT')),
    quantite        NUMERIC(20,8) NOT NULL CHECK (quantite > 0),
    prix            NUMERIC(20,8),
    statut          VARCHAR(20) NOT NULL CHECK (statut IN ('EN_ATTENTE', 'EXECUTE', 'ANNULE')),
    date_creation   TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- La PK doit inclure la clé de partition
    PRIMARY KEY (id, date_creation),
    CONSTRAINT chk_prix_limit CHECK (
        (mode = 'LIMIT' AND prix IS NOT NULL) OR
        (mode = 'MARKET' AND prix IS NULL)
    )
) PARTITION BY RANGE (date_creation);

-- Création des partitions (Décembre, Janvier, Février)
CREATE TABLE ordres_p2025_12 PARTITION OF ordres FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE ordres_p2026_01 PARTITION OF ordres FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE ordres_default  PARTITION OF ordres DEFAULT; -- Pour le reste

-- Table TRADES : Partitionnée par RANGE (date_execution)
CREATE TABLE trades (
    id              BIGSERIAL,
    -- On enlève la FK stricte vers ordres(id) car ordres est partitionnée
    -- C'est complexe à maintenir sur des tables massives, on gère l'intégrité via l'appli ou triggers
    ordre_id        BIGINT NOT NULL, 
    prix            NUMERIC(20,8) NOT NULL CHECK (prix > 0),
    quantite        NUMERIC(20,8) NOT NULL CHECK (quantite > 0),
    date_execution  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id, date_execution)
) PARTITION BY RANGE (date_execution);

CREATE TABLE trades_p2025_12 PARTITION OF trades FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE trades_default  PARTITION OF trades DEFAULT;
-- Ajout des partitions pour le futur (à mettre dans le script DDL)
CREATE TABLE ordres_p2026_02 PARTITION OF ordres FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE ordres_p2026_03 PARTITION OF ordres FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

CREATE TABLE trades_p2026_02 PARTITION OF trades FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE trades_p2026_03 PARTITION OF trades FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');

-- =============================================
-- 4. TABLES ANALYTIQUES & AUDIT
-- =============================================

CREATE TABLE prix_marche (
    id            BIGSERIAL PRIMARY KEY,
    paire_id      INT NOT NULL REFERENCES paire_trading(id),
    prix          NUMERIC(20,8) NOT NULL CHECK (prix > 0),
    volume        NUMERIC(20,8) NOT NULL CHECK (volume >= 0),
    date_maj      TIMESTAMPTZ NOT NULL
);

CREATE TABLE statistique_marche (
    id            BIGSERIAL PRIMARY KEY,
    paire_id      INT NOT NULL REFERENCES paire_trading(id),
    indicateur    VARCHAR(50) NOT NULL,
    valeur        NUMERIC(20,8) NOT NULL,
    periode       VARCHAR(20) NOT NULL,
    date_maj      TIMESTAMPTZ NOT NULL
);

CREATE TABLE detection_anomalie (
    id              BIGSERIAL PRIMARY KEY,
    type            VARCHAR(50) NOT NULL,
    ordre_id        BIGINT, -- Pas de FK stricte cause partitionnement
    utilisateur_id  BIGINT REFERENCES utilisateurs(id),
    date_detection  TIMESTAMPTZ NOT NULL DEFAULT now(),
    commentaire     TEXT
);

-- Table AUDIT_TRAIL : Partitionnée par LIST (action)
CREATE TABLE audit_trail (
    id              BIGSERIAL,
    table_cible     VARCHAR(50) NOT NULL,
    record_id       BIGINT NOT NULL,
    action          VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    utilisateur_id  BIGINT REFERENCES utilisateurs(id),
    date_action     TIMESTAMPTZ NOT NULL DEFAULT now(),
    details         TEXT,
    PRIMARY KEY (id, action) 
) PARTITION BY LIST (action);

CREATE TABLE audit_insert PARTITION OF audit_trail FOR VALUES IN ('INSERT');
CREATE TABLE audit_update PARTITION OF audit_trail FOR VALUES IN ('UPDATE');
CREATE TABLE audit_delete PARTITION OF audit_trail FOR VALUES IN ('DELETE');