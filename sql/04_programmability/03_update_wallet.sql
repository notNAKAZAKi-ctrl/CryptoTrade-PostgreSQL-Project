-- =============================================================================
-- TRIGGER : MISE À JOUR AUTOMATIQUE DU PORTEFEUILLE
-- =============================================================================

CREATE OR REPLACE FUNCTION update_wallet_after_trade()
RETURNS TRIGGER AS $$
BEGIN
    -- CAS 1 : C'est un ACHAT (BUY)
    -- L'acheteur dépense des USDT (crypto_contre) et reçoit de la Crypto (crypto_base)
    IF (SELECT type_ordre FROM ordres WHERE id = NEW.ordre_id) = 'BUY' THEN
        
        -- Débiter l'acheteur (USDT)
        UPDATE portefeuilles 
        SET solde = solde - (NEW.prix * NEW.quantite)
        WHERE utilisateur_id = (SELECT utilisateur_id FROM ordres WHERE id = NEW.ordre_id)
          AND crypto_id = (SELECT crypto_contre FROM paire_trading WHERE id = NEW.paire_id);
          
        -- Créditer l'acheteur (Crypto Base)
        UPDATE portefeuilles
        SET solde = solde + NEW.quantite
        WHERE utilisateur_id = (SELECT utilisateur_id FROM ordres WHERE id = NEW.ordre_id)
          AND crypto_id = (SELECT crypto_base FROM paire_trading WHERE id = NEW.paire_id);

    -- CAS 2 : C'est une VENTE (SELL)
    ELSE
        -- Débiter le vendeur (Crypto Base)
        UPDATE portefeuilles 
        SET solde = solde - NEW.quantite
        WHERE utilisateur_id = (SELECT utilisateur_id FROM ordres WHERE id = NEW.ordre_id)
          AND crypto_id = (SELECT crypto_base FROM paire_trading WHERE id = NEW.paire_id);
          
        -- Créditer le vendeur (USDT)
        UPDATE portefeuilles
        SET solde = solde + (NEW.prix * NEW.quantite)
        WHERE utilisateur_id = (SELECT utilisateur_id FROM ordres WHERE id = NEW.ordre_id)
          AND crypto_id = (SELECT crypto_contre FROM paire_trading WHERE id = NEW.paire_id);
          
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Activation du trigger
CREATE TRIGGER trg_update_wallet
AFTER INSERT ON trades
FOR EACH ROW
EXECUTE FUNCTION update_wallet_after_trade();