-- Fonction de détection automatique
CREATE OR REPLACE FUNCTION fn_analyse_comportement_suspect()
RETURNS TRIGGER AS $$
DECLARE
    v_nb_annulations INT;
BEGIN
    -- 1. DETECTION WASH TRADING (Sur la table TRADES)
    IF TG_TABLE_NAME = 'trades' THEN
        IF NEW.acheteur_id = NEW.vendeur_id THEN
            INSERT INTO detection_anomalie (type, ordre_id, utilisateur_id, commentaire)
            VALUES ('WASH_TRADING', NEW.ordre_id, NEW.acheteur_id, 
                   format('Auto-trade détecté : l''utilisateur a matché son propre ordre sur la paire %s', NEW.paire_id));
        END IF;
    END IF;

    -- 2. DETECTION SPOOFING (Sur la table ORDRES)
    -- On cherche si l'utilisateur a annulé beaucoup d'ordres importants en peu de temps
    IF TG_TABLE_NAME = 'ordres' AND NEW.statut = 'ANNULE' THEN
        SELECT COUNT(*) INTO v_nb_annulations
        FROM ordres
        WHERE utilisateur_id = NEW.utilisateur_id
          AND statut = 'ANNULE'
          AND date_creation > NOW() - INTERVAL '10 minutes';

        IF v_nb_annulations > 10 THEN
            INSERT INTO detection_anomalie (type, ordre_id, utilisateur_id, commentaire)
            VALUES ('SPOOFING', NEW.id, NEW.utilisateur_id, 
                   format('Pattern suspect : %s annulations en moins de 10 minutes', v_nb_annulations));
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Activation des triggers
CREATE TRIGGER trg_detect_wash_trade AFTER INSERT ON trades FOR EACH ROW EXECUTE FUNCTION fn_analyse_comportement_suspect();
CREATE TRIGGER trg_detect_spoofing AFTER UPDATE ON ordres FOR EACH ROW WHEN (NEW.statut = 'ANNULE') EXECUTE FUNCTION fn_analyse_comportement_suspect();


-- verifier que  detection_anomalie se remplit correctement

CREATE OR REPLACE PROCEDURE simuler_scenarios_fraude()
LANGUAGE plpgsql AS $$
BEGIN
    -- SCÉNARIO 1 : Simulation Wash Trading
    -- Un utilisateur crée un ordre d'achat et un ordre de vente au même prix
    RAISE NOTICE 'Simulation Wash Trading...';
    INSERT INTO trades (ordre_id, paire_id, acheteur_id, vendeur_id, prix, quantite)
    VALUES (1, 1, 100, 100, 50000, 0.5); -- Acheteur ID = Vendeur ID

    -- SCÉNARIO 2 : Simulation Spoofing
    -- Un utilisateur crée et annule rapidement 11 ordres
    RAISE NOTICE 'Simulation Spoofing...';
    FOR i IN 1..11 LOOP
        INSERT INTO ordres (utilisateur_id, paire_id, type_ordre, mode, quantite, quantite_restante, prix, statut)
        VALUES (200, 1, 'BUY', 'LIMIT', 10, 10, 49000, 'EN_ATTENTE')
        RETURNING id INTO i;
        
        UPDATE ordres SET statut = 'ANNULE' WHERE id = i;
    END LOOP;

    RAISE NOTICE 'Simulation terminée. Vérifiez la table detection_anomalie.';
END;
$$;

-- Execution de la vue 
CALL simuler_scenarios_fraude();
SELECT 
    date_detection, 
    type, 
    utilisateur_id, 
    commentaire 
FROM detection_anomalie 
ORDER BY date_detection DESC;