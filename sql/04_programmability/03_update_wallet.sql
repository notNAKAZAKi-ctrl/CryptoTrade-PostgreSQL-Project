-- =============================================================================
-- TRIGGER WALLET AVEC ADVISORY LOCKS (VERSION FINALE CORRIGÉE)
-- =============================================================================

CREATE OR REPLACE FUNCTION update_wallet_after_trade()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id INT;
    v_type_ordre VARCHAR(10);
    v_crypto_base INT;
    v_crypto_contre INT;
BEGIN
    -- 1. Récupérer qui a passé l'ordre initial
    SELECT utilisateur_id, type_ordre 
    INTO v_user_id, v_type_ordre 
    FROM ordres 
    WHERE id = NEW.ordre_id;

    -- 2. Récupérer quelles monnaies sont échangées
    SELECT crypto_base, crypto_contre 
    INTO v_crypto_base, v_crypto_contre 
    FROM paire_trading 
    WHERE id = NEW.paire_id;

    -- 3. VERROUILLAGE (Anti-Deadlock)
    PERFORM pg_advisory_xact_lock(v_user_id);

    -- 4. Mise à jour des soldes
    IF v_type_ordre = 'BUY' THEN
        -- ACHAT : Il paie en USDT (Contre) et reçoit du BTC (Base)
        UPDATE portefeuilles 
        SET solde = solde - (NEW.prix * NEW.quantite)
        WHERE utilisateur_id = v_user_id AND crypto_id = v_crypto_contre;

        UPDATE portefeuilles 
        SET solde = solde + NEW.quantite
        WHERE utilisateur_id = v_user_id AND crypto_id = v_crypto_base;

    ELSIF v_type_ordre = 'SELL' THEN
        -- VENTE : Il donne du BTC (Base) et reçoit des USDT (Contre)
        UPDATE portefeuilles 
        SET solde = solde - NEW.quantite
        WHERE utilisateur_id = v_user_id AND crypto_id = v_crypto_base;

        UPDATE portefeuilles 
        SET solde = solde + (NEW.prix * NEW.quantite)
        WHERE utilisateur_id = v_user_id AND crypto_id = v_crypto_contre;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_wallet ON trades;

CREATE TRIGGER trg_update_wallet
AFTER INSERT ON trades
FOR EACH ROW
EXECUTE FUNCTION update_wallet_after_trade();