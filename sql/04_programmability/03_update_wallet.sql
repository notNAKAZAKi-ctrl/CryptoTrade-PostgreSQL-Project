-- =============================================================================
-- TRIGGER WALLET AVEC ADVISORY LOCKS (Anti-Deadlock)
-- =============================================================================

CREATE OR REPLACE FUNCTION update_wallet_after_trade()
RETURNS TRIGGER AS $$
DECLARE
    v_buyer_id INT;
    v_seller_id INT;
    v_crypto_base INT;
    v_crypto_contre INT;
BEGIN
    -- Récupération des infos (Optimisé pour éviter trop de requêtes)
    SELECT utilisateur_id, type_ordre INTO v_buyer_id FROM ordres WHERE id = NEW.ordre_id;
    -- Note: Dans un vrai système, on aurait l'ID du vendeur dans la table trade. 
    -- Ici on simplifie selon ton modèle actuel.
    
    SELECT crypto_base, crypto_contre INTO v_crypto_base, v_crypto_contre 
    FROM paire_trading WHERE id = NEW.paire_id;

    -- ADVISORY LOCK : On verrouille le portefeuille de l'utilisateur pour cette transaction
    -- Cela empêche deux trades simultanés de modifier le même solde en même temps (Race Condition)
    PERFORM pg_advisory_xact_lock(v_buyer_id);

    -- Logique de mise à jour (Identique à avant, mais sécurisée)
    IF (SELECT type_ordre FROM ordres WHERE id = NEW.ordre_id) = 'BUY' THEN
        -- Débiter Cash / Créditer Crypto
        UPDATE portefeuilles SET solde = solde - (NEW.prix * NEW.quantite)
        WHERE utilisateur_id = v_buyer_id AND crypto_id = v_crypto_contre;

        UPDATE portefeuilles SET solde = solde + NEW.quantite
        WHERE utilisateur_id = v_buyer_id AND crypto_id = v_crypto_base;
    ELSE
        -- VENTE : Débiter Crypto / Créditer Cash
        UPDATE portefeuilles SET solde = solde - NEW.quantite
        WHERE utilisateur_id = v_buyer_id AND crypto_id = v_crypto_base;

        UPDATE portefeuilles SET solde = solde + (NEW.prix * NEW.quantite)
        WHERE utilisateur_id = v_buyer_id AND crypto_id = v_crypto_contre;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_wallet ON trades;
CREATE TRIGGER trg_update_wallet
AFTER INSERT ON trades
FOR EACH ROW
EXECUTE FUNCTION update_wallet_after_trade();