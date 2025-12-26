-- =============================================================================
-- TRIGGER WALLET AVEC ADVISORY LOCKS (CORRIGÉ)
-- =============================================================================

CREATE OR REPLACE FUNCTION update_wallet_after_trade()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id INT;         -- ID du propriétaire de l'ordre
    v_type_ordre VARCHAR(10); -- BUY ou SELL
    v_crypto_base INT;     -- Ex: BTC
    v_crypto_contre INT;   -- Ex: USDT
BEGIN
    -- 1. Récupération propre des infos de l'ordre (Propriétaire + Sens)
    SELECT utilisateur_id, type_ordre 
    INTO v_user_id, v_type_ordre 
    FROM ordres 
    WHERE id = NEW.ordre_id;

    -- 2. Récupération des cryptos de la paire
    SELECT crypto_base, crypto_contre 
    INTO v_crypto_base, v_crypto_contre 
    FROM paire_trading 
    WHERE id = NEW.paire_id;

    -- 🔒 3. ADVISORY LOCK (Anti-Deadlock)
    -- On verrouille uniquement le portefeuille de cet utilisateur pour cette transaction
    PERFORM pg_advisory_xact_lock(v_user_id);

    -- 4. Mise à jour des soldes
    IF v_type_ordre = 'BUY' THEN
        -- ACHAT : L'utilisateur dépense du Cash (Contre) et reçoit de la Crypto (Base)
        
        -- Débit USDT (Crypto Contre)
        UPDATE portefeuilles 
        SET solde = solde - (NEW.prix * NEW.quantite)
        WHERE utilisateur_id = v_user_id AND crypto_id = v_crypto_contre;

        -- Crédit BTC (Crypto Base)
        UPDATE portefeuilles 
        SET solde = solde + NEW.quantite
        WHERE utilisateur_id = v_user_id AND crypto_id = v_crypto_base;

    ELSIF v_type_ordre = 'SELL' THEN
        -- VENTE : L'utilisateur dépense de la Crypto (Base) et reçoit du Cash (Contre)

        -- Débit BTC (Crypto Base)
        UPDATE portefeuilles 
        SET solde = solde - NEW.quantite
        WHERE utilisateur_id = v_user_id AND crypto_id = v_crypto_base;

        -- Crédit USDT (Crypto Contre)
        UPDATE portefeuilles 
        SET solde = solde + (NEW.prix * NEW.quantite)
        WHERE utilisateur_id = v_user_id AND crypto_id = v_crypto_contre;
        
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Réinitialisation du trigger pour être sûr
DROP TRIGGER IF EXISTS trg_update_wallet ON trades;

CREATE TRIGGER trg_update_wallet
AFTER INSERT ON trades
FOR EACH ROW
EXECUTE FUNCTION update_wallet_after_trade();