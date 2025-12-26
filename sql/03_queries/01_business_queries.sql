-- =============================================================================
-- 1. REQUÊTES MÉTIER (BUSINESS LOGIC)
-- =============================================================================
-- Ce fichier contient les requêtes utilisées par l'application au quotidien.
-- =============================================================================

SET search_path = cryptotrade;

-- A. CONSULTATION DU PORTEFEUILLE
-- "Combien j'ai d'argent sur mon compte ?" (Exemple pour User ID = 1)
SELECT 
    c.nom, 
    c.symbole, 
    p.solde, 
    p.solde_bloque 
FROM portefeuilles p
JOIN cryptomonnaies c ON p.crypto_id = c.id
WHERE p.utilisateur_id = 1;

-- B. HISTORIQUE DES ORDRES
-- "Montre-moi mes 10 derniers ordres"
SELECT 
    o.date_creation, 
    pt.id as paire, 
    o.type_ordre, 
    o.prix, 
    o.quantite, 
    o.statut
FROM ordres o
JOIN paire_trading pt ON o.paire_id = pt.id
WHERE o.utilisateur_id = 1
ORDER BY o.date_creation DESC
LIMIT 10;

-- C. TOP 5 DES MEILLEURES PAIRS (Par volume)
-- "Quelles sont les cryptos les plus échangées ?"
SELECT 
    c.symbole || '/USD' as paire,
    pm.prix,
    pm.volume
FROM prix_marche pm
JOIN paire_trading pt ON pm.paire_id = pt.id
JOIN cryptomonnaies c ON pt.crypto_base = c.id
ORDER BY pm.volume DESC
LIMIT 5;

-- D. ANALYSE RAPIDE (VWAP)
-- "Quel est le prix moyen du Bitcoin aujourd'hui ?"
SELECT 
    SUM(prix * quantite) / SUM(quantite) as vwap_btc
FROM trades t
WHERE t.paire_id = 1 -- Supposons que 1 est BTC/USD
AND t.date_execution >= CURRENT_DATE;

-- E. DÉTECTION FRAUDE (Version Admin)
-- "Liste les utilisateurs suspects pour l'admin"
SELECT u.email, COUNT(*) as nb_alertes
FROM detection_anomalie d
JOIN utilisateurs u ON d.utilisateur_id = u.id
GROUP BY u.email
ORDER BY nb_alertes DESC;