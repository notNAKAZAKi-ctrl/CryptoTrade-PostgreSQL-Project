SET search_path = cryptotrade;

-- 🧹 NETTOYAGE TOTAL (Avec remise à zéro des compteurs ID !)
TRUNCATE TABLE audit_trail, detection_anomalie, statistique_marche, prix_marche, trades, ordres, portefeuilles, paire_trading, cryptomonnaies, utilisateurs RESTART IDENTITY CASCADE;

-- =============================================
-- 1️⃣ UTILISATEURS
-- =============================================
INSERT INTO utilisateurs (nom, email, date_inscription, statut)
SELECT
    'User_' || g,
    'user' || g || '@example.com',
    CURRENT_DATE - (floor(random() * 365)::int),
    CASE WHEN random() < 0.9 THEN 'ACTIF' ELSE 'INACTIF' END
FROM generate_series(1, 1000) g;

-- =============================================
-- 2️⃣ CRYPTOMONNAIES
-- =============================================
INSERT INTO cryptomonnaies (nom, symbole, date_creation, statut) VALUES
('Bitcoin', 'BTC', '2009-01-03', 'ACTIVE'),
('Ethereum', 'ETH', '2015-07-30', 'ACTIVE'),
('Tether', 'USDT', '2014-10-06', 'ACTIVE'),
('Cardano', 'ADA', '2017-09-29', 'ACTIVE'),
('Solana', 'SOL', '2020-03-01', 'ACTIVE');

-- =============================================
-- 3️⃣ PORTEFEUILLES
-- =============================================
INSERT INTO portefeuilles (utilisateur_id, crypto_id, solde, solde_bloque)
SELECT
    u.id,
    c.id,
    (random() * 10)::numeric(36,18),
    0
FROM utilisateurs u
CROSS JOIN cryptomonnaies c
WHERE c.id IN (SELECT id FROM cryptomonnaies LIMIT 3); -- ✅ Plus robuste que "id <= 3"

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
-- 5️⃣ ORDRES (Blindé contre les erreurs d'ID et de Prix)
-- =============================================
INSERT INTO ordres (utilisateur_id, paire_id, type_ordre, mode, quantite, prix, statut, date_creation)
SELECT
    (floor(random() * 1000) + 1)::int, 
    -- ✅ Sécurité : On s'assure que l'ID généré ne dépasse pas le nombre réel de paires
    (floor(random() * (SELECT count(*) FROM paire_trading)) + 1)::int, 
    
    CASE WHEN random() < 0.5 THEN 'BUY' ELSE 'SELL' END,
    
    -- Choix du mode (Market/Limit)
    CASE WHEN rand_val < 0.5 THEN 'MARKET' ELSE 'LIMIT' END, 
    
    (random() * 5 + 0.1)::numeric(36,18),
    
    -- ✅ Prix NULL si MARKET, sinon Prix aléatoire
    CASE 
        WHEN rand_val < 0.5 THEN NULL 
        ELSE (random() * 50000 + 1000)::numeric(24,8) 
    END, 
    
    'EN_ATTENTE',
    '2025-12-01'::timestamp + (random() * (interval '90 days'))
FROM generate_series(1, 1000000)
CROSS JOIN LATERAL (SELECT random() AS rand_val) AS v;

-- =============================================
-- 6️⃣ TRADES
-- =============================================
INSERT INTO trades (ordre_id, paire_id, prix, quantite, date_execution)
SELECT
    o.id,
    o.paire_id,
    COALESCE(o.prix, (random() * 50000 + 1000)::numeric(24,8)), 
    o.quantite,
    o.date_creation + (interval '1 second' * floor(random()*3600))
FROM ordres o
WHERE o.statut = 'EN_ATTENTE' 
LIMIT 500000; 

-- Mise à jour du statut
UPDATE ordres SET statut = 'EXECUTE' WHERE id IN (SELECT ordre_id FROM trades);

-- =============================================
-- 7️⃣ MARKET DATA
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

-- ✅ VERIFICATION FINALE
SELECT 
    (SELECT count(*) FROM utilisateurs) as users,
    (SELECT count(*) FROM ordres) as ordres,
    (SELECT count(*) FROM trades) as trades;