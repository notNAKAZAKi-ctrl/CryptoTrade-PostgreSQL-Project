-- =========================
-- TABLE UTILISATEURS
-- =========================
CREATE TABLE UTILISATEURS (
  id INT PRIMARY KEY,
  nom VARCHAR(50),
  email VARCHAR(100),
  date_inscription DATE,
  statut VARCHAR(20)
);

-- =========================
-- TABLE CRYPTOMONNAIES
-- =========================
CREATE TABLE CRYPTOMONNAIES (
  id INT PRIMARY KEY,
  nom VARCHAR(50),
  symbole VARCHAR(10),
  date_creation DATE,
  statut VARCHAR(20)
);

-- =========================
-- TABLE PAIRE_TRADING
-- =========================
CREATE TABLE PAIRE_TRADING (
  id INT PRIMARY KEY,
  crypto_base INT,
  crypto_contre INT,
  statut VARCHAR(20),
  date_ouverture DATE,
  CONSTRAINT fk_crypto_base FOREIGN KEY (crypto_base)
    REFERENCES CRYPTOMONNAIES(id),
  CONSTRAINT fk_crypto_contre FOREIGN KEY (crypto_contre)
    REFERENCES CRYPTOMONNAIES(id)
);

-- =========================
-- TABLE PORTEFEUILLES
-- =========================
CREATE TABLE PORTEFEUILLES (
  id INT PRIMARY KEY,
  utilisateur_id INT,
  solde_total NUMERIC,
  solde_bloque NUMERIC,
  date_maj TIMESTAMP,
  CONSTRAINT fk_portefeuille_user FOREIGN KEY (utilisateur_id)
    REFERENCES UTILISATEURS(id)
);

-- =========================
-- TABLE ORDRES
-- =========================
CREATE TABLE ORDRES (
  id INT PRIMARY KEY,
  utilisateur_id INT,
  paire_id INT,
  type_ordre VARCHAR(10),
  mode VARCHAR(10),
  quantite NUMERIC,
  prix NUMERIC,
  statut VARCHAR(20),
  date_creation TIMESTAMP,
  CONSTRAINT fk_ordre_user FOREIGN KEY (utilisateur_id)
    REFERENCES UTILISATEURS(id),
  CONSTRAINT fk_ordre_paire FOREIGN KEY (paire_id)
    REFERENCES PAIRE_TRADING(id)
);

-- =========================
-- TABLE TRADES
-- =========================
CREATE TABLE TRADES (
  id INT PRIMARY KEY,
  ordre_id INT,
  prix NUMERIC,
  quantite NUMERIC,
  date_execution TIMESTAMP,
  CONSTRAINT fk_trade_ordre FOREIGN KEY (ordre_id)
    REFERENCES ORDRES(id)
);

-- =========================
-- TABLE PRIX_MARCHE
-- =========================
CREATE TABLE PRIX_MARCHE (
  id INT PRIMARY KEY,
  paire_id INT,
  prix NUMERIC,
  volume NUMERIC,
  date_maj TIMESTAMP,
  CONSTRAINT fk_prix_paire FOREIGN KEY (paire_id)
    REFERENCES PAIRE_TRADING(id)
);

-- =========================
-- TABLE STATISTIQUE_MARCHE
-- =========================
CREATE TABLE STATISTIQUE_MARCHE (
  id INT PRIMARY KEY,
  paire_id INT,
  indicateur VARCHAR(50),
  valeur NUMERIC,
  periode VARCHAR(20),
  date_maj TIMESTAMP,
  CONSTRAINT fk_stat_paire FOREIGN KEY (paire_id)
    REFERENCES PAIRE_TRADING(id)
);

-- =========================
-- TABLE DETECTION_ANOMALIE
-- =========================
CREATE TABLE DETECTION_ANOMALIE (
  id INT PRIMARY KEY,
  type VARCHAR(50),
  ordre_id INT,
  utilisateur_id INT,
  date_detection TIMESTAMP,
  commentaire TEXT,
  CONSTRAINT fk_anomalie_ordre FOREIGN KEY (ordre_id)
    REFERENCES ORDRES(id),
  CONSTRAINT fk_anomalie_user FOREIGN KEY (utilisateur_id)
    REFERENCES UTILISATEURS(id)
);

-- =========================
-- TABLE AUDIT_TRAIL
-- =========================
CREATE TABLE AUDIT_TRAIL (
  id INT PRIMARY KEY,
  table_cible VARCHAR(50),
  record_id INT,
  action VARCHAR(10),
  utilisateur_id INT,
  date_action TIMESTAMP,
  details TEXT,
  CONSTRAINT fk_audit_user FOREIGN KEY (utilisateur_id)
    REFERENCES UTILISATEURS(id)
);
