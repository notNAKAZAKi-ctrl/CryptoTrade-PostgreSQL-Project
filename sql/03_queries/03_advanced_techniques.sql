-- =============================================================================
-- REQUÊTES AVANCÉES (Cahier des charges Section 3)
-- =============================================================================
SET search_path = cryptotrade;

-- 1. DISTINCT ON : Obtenir le tout dernier prix connu pour chaque paire
-- "DISTINCT ON pour obtenir le dernier prix ou état de l’ordre"
SELECT DISTINCT ON (paire_id) 
    pt.crypto_base, 
    pt.crypto_contre, 
    pm.prix, 
    pm.date_maj
FROM prix_marche pm
JOIN paire_trading pt ON pm.paire_id = pt.id
ORDER BY paire_id, date_maj DESC;

-- 2. LATERAL JOIN : Statistiques complexes par utilisateur
-- "LATERAL joins pour récupérer des statistiques complexes par utilisateur"
-- Pour chaque utilisateur actif, on calcule sa dernière action et son volume total
SELECT 
    u.nom,
    stats.dernier_ordre,
    stats.volume_total
FROM utilisateurs u
CROSS JOIN LATERAL (
    SELECT 
        MAX(o.date_creation) as dernier_ordre,
        SUM(o.prix * o.quantite) as volume_total
    FROM ordres o
    WHERE o.utilisateur_id = u.id
) stats
WHERE u.statut = 'ACTIF'
LIMIT 10;

-- 3. RECURSIVE CTE : Détection de chaîne de transactions suspectes
-- "Recursive CTE pour détecter anomalies et patterns suspects"
-- On cherche une chaîne d'utilisateurs qui s'achètent/vendent entre eux (Cercle)
WITH RECURSIVE chaine_suspecte AS (
    -- Cas de base : Un trade initial
    SELECT 
        t.id as trade_id, 
        t.ordre_id, 
        o_buy.utilisateur_id as acheteur, 
        o_sell.utilisateur_id as vendeur,
        1 as profondeur
    FROM trades t
    JOIN ordres o_buy ON t.ordre_id = o_buy.id AND o_buy.type_ordre = 'BUY'
    JOIN ordres o_sell ON t.paire_id = o_sell.paire_id AND o_sell.type_ordre = 'SELL' 
        AND o_sell.date_creation BETWEEN o_buy.date_creation - interval '1s' AND o_buy.date_creation + interval '1s'
    WHERE t.date_execution > NOW() - INTERVAL '1 hour'
    
    UNION ALL
    
    -- Partie récursive : On cherche si le vendeur a racheté à l'acheteur initial
    SELECT 
        t2.id, 
        t2.ordre_id, 
        o_buy2.utilisateur_id, 
        o_sell2.utilisateur_id,
        cs.profondeur + 1
    FROM trades t2
    JOIN chaine_suspecte cs ON cs.vendeur = (SELECT utilisateur_id FROM ordres WHERE id = t2.ordre_id AND type_ordre='BUY')
    JOIN ordres o_buy2 ON t2.ordre_id = o_buy2.id
    JOIN ordres o_sell2 ON t2.paire_id = o_sell2.paire_id
    WHERE cs.profondeur < 5 -- On limite la profondeur pour éviter les boucles infinies
)
SELECT * FROM chaine_suspecte;