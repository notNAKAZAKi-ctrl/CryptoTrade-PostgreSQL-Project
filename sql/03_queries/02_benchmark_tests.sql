-- =============================================================================
-- 🧪 PROTOCOLE DE TEST DE PERFORMANCE : AVANT / APRÈS OPTIMISATION
-- =============================================================================

SET search_path = cryptotrade;

-- 🔴 PHASE 1 : SIMULATION "SANS OPTIMISATION" (Mode Lent) 🐢
-- =============================================================================
-- On désactive les scans d'index pour simuler une base mal optimisée
SET enable_indexscan = OFF;
SET enable_bitmapscan = OFF;
SET enable_indexonlyscan = OFF;

RAISE NOTICE '--- 🔴 DÉBUT DES TESTS EN MODE LENT (SANS INDEX) ---';

-- 🧪 TEST 1 : Recherche Filtrée (Doit scanner toute la table ordres)
-- "Trouver les ordres en attente avec un prix élevé"
EXPLAIN ANALYZE
SELECT * FROM ordres 
WHERE statut = 'EN_ATTENTE' 
AND prix > 10000;

-- 🧪 TEST 2 : Calcul Financier VWAP (Jointures Lourdes)
-- "Calculer le prix moyen pondéré par crypto"
EXPLAIN ANALYZE
SELECT 
    c.symbole, 
    COUNT(t.id) as nb_trades, 
    SUM(t.prix * t.quantite) / SUM(t.quantite) as vwap
FROM trades t
JOIN paire_trading pt ON t.paire_id = pt.id
JOIN cryptomonnaies c ON pt.crypto_base = c.id
GROUP BY c.symbole;

-- 🧪 TEST 3 : Détection de Fraude (Auto-jointure massive)
-- ⚠️⚠️⚠️ ATTENTION : Si cette requête dépasse 15-20 secondes, ARRÊTEZ-LA manuellement.⚠️⚠️⚠️
-- ⚠️⚠️⚠️  C'est la preuve que sans index, la fraude est impossible à détecter en temps réel.⚠️⚠️⚠️
EXPLAIN ANALYZE
SELECT u.nom, COUNT(*) as suspicion
FROM ordres o_buy
JOIN ordres o_sell 
    ON o_buy.utilisateur_id = o_sell.utilisateur_id 
    AND o_buy.paire_id = o_sell.paire_id
WHERE o_buy.type_ordre = 'BUY' 
    AND o_sell.type_ordre = 'SELL'
    AND o_sell.date_creation BETWEEN o_buy.date_creation AND o_buy.date_creation + interval '15 minutes'
GROUP BY u.nom 
HAVING COUNT(*) > 1;


-- 🟢 PHASE 2 : MODE "OPTIMISÉ" (Mode Rapide) 🚀
-- =============================================================================
-- On réactive tout : Le moteur va utiliser vos Index Partiels et Composites
SET enable_indexscan = ON;
SET enable_bitmapscan = ON;
SET enable_indexonlyscan = ON;

RAISE NOTICE '--- 🟢 DÉBUT DES TESTS EN MODE OPTIMISÉ (AVEC INDEX) ---';

-- 🚀 TEST 1 : Recherche Filtrée (Doit utiliser "idx_ordres_paire_statut_prix")
EXPLAIN ANALYZE
SELECT * FROM ordres 
WHERE statut = 'EN_ATTENTE' 
AND prix > 10000;

-- 🚀 TEST 2 : Calcul Financier VWAP (Jointures optimisées par index FK)
EXPLAIN ANALYZE
SELECT 
    c.symbole, 
    COUNT(t.id) as nb_trades, 
    SUM(t.prix * t.quantite) / SUM(t.quantite) as vwap
FROM trades t
JOIN paire_trading pt ON t.paire_id = pt.id
JOIN cryptomonnaies c ON pt.crypto_base = c.id
GROUP BY c.symbole;

-- 🚀 TEST 3 : Détection de Fraude (Accélérée par "idx_ordres_user")
EXPLAIN ANALYZE
SELECT u.nom, COUNT(*) as suspicion
FROM ordres o_buy
JOIN ordres o_sell 
    ON o_buy.utilisateur_id = o_sell.utilisateur_id 
    AND o_buy.paire_id = o_sell.paire_id
WHERE o_buy.type_ordre = 'BUY' 
    AND o_sell.type_ordre = 'SELL'
    AND o_sell.date_creation BETWEEN o_buy.date_creation AND o_buy.date_creation + interval '15 minutes'
GROUP BY u.nom 
HAVING COUNT(*) > 1;

-- Fin du protocole