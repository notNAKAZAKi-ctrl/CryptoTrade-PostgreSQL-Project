CREATE SCHEMA IF NOT EXISTS cryptotrade;
SET search_path = cryptotrade;

CREATE TABLE utilisateurs (
    id                BIGSERIAL PRIMARY KEY,
    nom               VARCHAR(50) NOT NULL,
    email             VARCHAR(100) NOT NULL UNIQUE,
    date_inscription  DATE NOT NULL DEFAULT CURRENT_DATE,
    statut            VARCHAR(20) NOT NULL CHECK (statut IN ('ACTIF', 'INACTIF'))
);

CREATE TABLE portefeuilles (
    id              BIGSERIAL PRIMARY KEY,
    utilisateur_id  BIGINT NOT NULL REFERENCES utilisateurs(id),
    crypto_id       INT NOT NULL REFERENCES cryptomonnaies(id),
    solde_total     NUMERIC(20,8) NOT NULL CHECK (solde_total >= 0),
    solde_bloque    NUMERIC(20,8) NOT NULL CHECK (solde_bloque >= 0),
    date_maj        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_crypto UNIQUE (utilisateur_id, crypto_id),
    CONSTRAINT chk_solde CHECK (solde_total >= solde_bloque)
);

ALTER TABLE utilisateurs
ADD CONSTRAINT fk_utilisateur_portefeuille
FOREIGN KEY (portefeuille_id)
REFERENCES portefeuilles(id);

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
    date_ouverture  DATE NOT NULL,
    CONSTRAINT uq_paire UNIQUE (crypto_base, crypto_contre),
    CONSTRAINT chk_crypto_diff CHECK (crypto_base <> crypto_contre)
);

CREATE TABLE ordres (
    id              BIGSERIAL PRIMARY KEY,
    utilisateur_id  BIGINT NOT NULL REFERENCES utilisateurs(id),
    paire_id        INT NOT NULL REFERENCES paire_trading(id),
    type_ordre      VARCHAR(10) NOT NULL CHECK (type_ordre IN ('BUY', 'SELL')),
    mode            VARCHAR(10) NOT NULL CHECK (mode IN ('MARKET', 'LIMIT')),
    quantite        NUMERIC(20,8) NOT NULL CHECK (quantite > 0),
    prix            NUMERIC(20,8),
    statut          VARCHAR(20) NOT NULL CHECK (statut IN ('EN_ATTENTE', 'EXECUTE', 'ANNULE')),
    date_creation   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_prix_limit
        CHECK (
            (mode = 'LIMIT' AND prix IS NOT NULL) OR
            (mode = 'MARKET' AND prix IS NULL)
        )
);

CREATE TABLE trades (
    id              BIGSERIAL PRIMARY KEY,
    ordre_id        BIGINT NOT NULL REFERENCES ordres(id),
    prix            NUMERIC(20,8) NOT NULL CHECK (prix > 0),
    quantite        NUMERIC(20,8) NOT NULL CHECK (quantite > 0),
    date_execution  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE prix_marche (
    id        BIGSERIAL PRIMARY KEY,
    paire_id  INT NOT NULL REFERENCES paire_trading(id),
    prix      NUMERIC(20,8) NOT NULL CHECK (prix > 0),
    volume    NUMERIC(20,8) NOT NULL CHECK (volume >= 0),
    date_maj  TIMESTAMPTZ NOT NULL
);

CREATE TABLE statistique_marche (
    id          BIGSERIAL PRIMARY KEY,
    paire_id    INT NOT NULL REFERENCES paire_trading(id),
    indicateur  VARCHAR(50) NOT NULL,
    valeur      NUMERIC(20,8) NOT NULL,
    periode     VARCHAR(20) NOT NULL,
    date_maj    TIMESTAMPTZ NOT NULL
);

CREATE TABLE detection_anomalie (
    id              BIGSERIAL PRIMARY KEY,
    type            VARCHAR(50) NOT NULL,
    ordre_id        BIGINT REFERENCES ordres(id),
    utilisateur_id  BIGINT REFERENCES utilisateurs(id),
    date_detection  TIMESTAMPTZ NOT NULL DEFAULT now(),
    commentaire     TEXT
);

CREATE TABLE audit_trail (
    id              BIGSERIAL PRIMARY KEY,
    table_cible     VARCHAR(50) NOT NULL,
    record_id       BIGINT NOT NULL,
    action          VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    utilisateur_id  BIGINT REFERENCES utilisateurs(id),
    date_action     TIMESTAMPTZ NOT NULL DEFAULT now(),
    details         TEXT
);