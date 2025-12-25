SET search_path = cryptotrade;

-- Nettoyage préventif (Optionnel : vide les tables avant de remplir)
TRUNCATE TABLE audit_trail, detection_anomalie, statistique_marche, prix_marche, trades, ordres, portefeuilles, paire_trading, cryptomonnaies, utilisateurs CASCADE;

-- =============================================
-- 1️⃣ UTILISATEURS (1 000 users)
-- =============================================
INSERT INTO utilisateurs (nom, email, date_inscription, statut)
SELECT
    'User_' || g,
    'user' || g || '@example.com',
    CURRENT_DATE - (floor(random() * 365)::int),
    CASE WHEN random() < 0.9 THEN 'ACTIF' ELSE 'INACTIF' END
FROM generate_series(1, 1000) g;

-- =============================================
-- 2️⃣ CRYPTOMONNAIES (5 cryptos)
-- =============================================
INSERT INTO cryptomonnaies (nom, symbole, date_creation, statut) VALUES
('Bitcoin', 'BTC', '2009-01-03', 'ACTIVE'),
('Ethereum', 'ETH', '2015-07-30', 'ACTIVE'),
('Tether', 'USDT', '2014-10-06', 'ACTIVE'),
('Cardano', 'ADA', '2017-09-29', 'ACTIVE'),
('Solana', 'SOL', '2020-03-01', 'ACTIVE');

-- =============================================
-- 3️⃣ PORTEFEUILLES (CORRIGÉ : solde + précision)
-- =============================================
INSERT INTO portefeuilles (utilisateur_id, crypto_id, solde, solde_bloque)
SELECT
    u.id,
    c.id,
    (random() * 10)::numeric(36,18), -- ✅ Précision 36,18 comme dans le CREATE TABLE
    0
FROM utilisateurs u
CROSS JOIN cryptomonnaies c
WHERE c.id <= 3; 

-- =============================================
-- 4️⃣ PAIRES DE TRADING
-- =============================================
INSERT INTO paire_trading (crypto_base, crypto_contre, statut, date_ouverture)
SELECT
    c1.id,
    c2.id,
    'ACTIVE',
    CURRENT_DATE - (floor(random() * 365)::int)
FROM cryptomonnaies c1
JOIN cryptomonnaies c2 ON c1.id < c2.id; 

-- =============================================
-- 5️⃣ ORDRES (1 000 000 lignes - Adapté Précision)
-- =============================================
INSERT INTO ordres (utilisateur_id, paire_id, type_ordre, mode, quantite, prix, statut, date_creation)
SELECT
    (floor(random() * 1000) + 1)::int, 
    (floor(random() * (SELECT count(*) FROM paire_trading)) + 1)::int, 
    CASE WHEN random() < 0.5 THEN 'BUY' ELSE 'SELL' END,
    CASE WHEN random() < 0.5 THEN 'MARKET' ELSE 'LIMIT' END,
    (random() * 5 + 0.1)::numeric(36,18),    -- ✅ Quantité (36,18)
    (random() * 50000 + 1000)::numeric(24,8), -- ✅ Prix (24,8)
    'EN_ATTENTE',
    -- Dates étalées sur Décembre, Janvier, Février
    '2025-12-01'::timestamp + (random() * (interval '90 days'))
FROM generate_series(1, 1000000);

-- =============================================
-- 6️⃣ TRADES (CORRIGÉ - Avec paire_id)
-- =============================================
INSERT INTO trades (ordre_id, paire_id, prix, quantite, date_execution)
SELECT
    o.id,
    o.paire_id, -- ✅ On garde bien le paire_id
    o.prix,
    o.quantite,
    o.date_creation + (interval '1 second' * floor(random()*3600))
FROM ordres o
WHERE o.statut = 'EN_ATTENTE' 
LIMIT 500000; 

-- Mise à jour du statut des ordres
UPDATE ordres SET statut = 'EXECUTE' WHERE id IN (SELECT ordre_id FROM trades);

-- =============================================
-- 7️⃣ & 8️⃣ MARKET DATA
-- =============================================
INSERT INTO prix_marche (paire_id, prix, volume, date_maj)
SELECT 
    id, 
    (random()*50000 + 1000)::numeric(24,8), 
    (random()*1000)::numeric(36,8), 
    NOW() 
FROM paire_trading;

INSERT INTO statistique_marche (paire_id, indicateur, valeur, periode, date_maj)
SELECT id, 'RSI', (random()*100), '1D', NOW() FROM paire_trading;

-- VERIFICATION FINALE
SELECT 'Utilisateurs' as table, count(*) FROM utilisateurs
UNION ALL SELECT 'Ordres', count(*) FROM ordres
UNION ALL SELECT 'Trades', count(*) FROM trades;