-- =============================================
-- 1️⃣ UTILISATEURS
-- =============================================
SET search_path = cryptotrade;
INSERT INTO utilisateurs (nom, email, date_inscription, statut)
SELECT
    'User_' || g AS nom,
    'user' || g || '@example.com' AS email,
    CURRENT_DATE - (random()*365)::int AS date_inscription,
    CASE WHEN random() < 0.9 THEN 'ACTIF' ELSE 'INACTIF' END AS statut
FROM generate_series(1, 1000) g;  -- 1000 utilisateurs

-- =============================================
-- 2️⃣ CRYPTOMONNAIES
-- =============================================
INSERT INTO cryptomonnaies (nom, symbole, date_creation, statut)
VALUES
('Bitcoin', 'BTC', '2009-01-03', 'ACTIVE'),
('Ethereum', 'ETH', '2015-07-30', 'ACTIVE'),
('Tether', 'USDT', '2014-10-06', 'ACTIVE'),
('Cardano', 'ADA', '2017-09-29', 'ACTIVE'),
('Solana', 'SOL', '2020-03-01', 'ACTIVE');

-- =============================================
-- 3️⃣ PORTEFEUILLES
-- Chaque utilisateur a 1 à 3 cryptos
-- =============================================
INSERT INTO portefeuilles (utilisateur_id, crypto_id, solde_total, solde_bloque)
SELECT
    u.id AS utilisateur_id,
    c.id AS crypto_id,
    solde_total,
    (solde_total * random())::numeric(20,8) AS solde_bloque
FROM utilisateurs u
JOIN cryptomonnaies c ON c.id <= 3
CROSS JOIN LATERAL (
    SELECT (random()*10)::numeric(20,8) AS solde_total
) s;
  -- Chaque user reçoit BTC, ETH, USDT

-- =============================================
-- 4️⃣ PAIRES DE TRADING
-- =============================================
INSERT INTO paire_trading (crypto_base, crypto_contre, statut, date_ouverture)
SELECT
    c1.id AS crypto_base,
    c2.id AS crypto_contre,
    'ACTIVE' AS statut,
    CURRENT_DATE - (random()*365)::int AS date_ouverture
FROM cryptomonnaies c1
JOIN cryptomonnaies c2 ON c1.id < c2.id;  -- toutes les combinaisons uniques

-- =============================================
-- 5️⃣ ORDRES (1 000 000 lignes)
-- =============================================
INSERT INTO ordres (
    utilisateur_id,
    paire_id,
    type_ordre,
    mode,
    quantite,
    prix,
    statut,
    date_creation
)
SELECT
    u.id AS utilisateur_id,
    p.id AS paire_id,
    CASE WHEN random() < 0.5 THEN 'BUY' ELSE 'SELL' END AS type_ordre,
    mode,
    (random()*5 + 0.1)::numeric(20,8) AS quantite,
    CASE
        WHEN mode = 'LIMIT'
        THEN (random()*50000 + 1000)::numeric(20,8)
        ELSE NULL
    END AS prix,
    'EN_ATTENTE' AS statut,
    NOW() - (random()*interval '30 days') AS date_creation
FROM (
    SELECT
        id
    FROM utilisateurs
    ORDER BY random()
    LIMIT 1000000
) u
JOIN LATERAL (
    SELECT id
    FROM paire_trading
    ORDER BY random()
    LIMIT 1
) p ON TRUE
JOIN LATERAL (
    SELECT
        CASE WHEN random() < 0.5 THEN 'MARKET' ELSE 'LIMIT' END AS mode
) m ON TRUE;

-- =============================================
-- 6️⃣ TRADES (1 000 000 lignes)
-- =============================================
INSERT INTO trades (ordre_id, prix, quantite, date_execution)
SELECT
    o.id AS ordre_id,
    COALESCE(o.prix, 5000 + random()*1000) AS prix,
    o.quantite AS quantite,
    o.date_creation + (random() * interval '2 hours') AS date_execution
FROM ordres o
WHERE o.mode = 'LIMIT'
LIMIT 1000000;

-- =============================================
-- 7️⃣ PRIX DU MARCHÉ (Simulation)
-- =============================================
INSERT INTO prix_marche (paire_id, prix, volume, date_maj)
SELECT
    p.id AS paire_id,
    (random()*50000 + 1000)::numeric(20,8) AS prix,
    (random()*1000)::numeric(20,8) AS volume,
    NOW() - (random()*interval '30 days') AS date_maj
FROM paire_trading p;

-- =============================================
-- 8️⃣ STATISTIQUE MARCHÉ (RSI, Volatilité...)
-- =============================================
INSERT INTO statistique_marche (paire_id, indicateur, valeur, periode, date_maj)
SELECT
    p.id AS paire_id,
    CASE WHEN random() < 0.5 THEN 'RSI' ELSE 'Volatilité' END AS indicateur,
    (random()*100)::numeric(20,8) AS valeur,
    CASE WHEN random() < 0.5 THEN '1D' ELSE '1W' END AS periode,
    NOW() - (random()*interval '30 days') AS date_maj
FROM paire_trading p;


SELECT COUNT(*) FROM utilisateurs;
SELECT COUNT(*) FROM portefeuilles;
SELECT COUNT(*) FROM ordres;
SELECT COUNT(*) FROM trades;
