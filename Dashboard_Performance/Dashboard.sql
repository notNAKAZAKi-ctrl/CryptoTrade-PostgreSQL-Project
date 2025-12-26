CREATE OR REPLACE VIEW v_dashboard_final AS
SELECT 
    (SELECT COUNT(*) FROM detection_anomalie) AS nb_alertes_fraude,
    (SELECT COUNT(*) FROM ordres WHERE statut = 'EN_ATTENTE') AS ordres_en_cours,
    (SELECT round(avg(prix),2) FROM trades) AS prix_moyen_marche,
    -- Mesure de la santé du cache (Bonus Tuning)
    (SELECT round(sum(blks_hit)*100/nullif(sum(blks_hit+blks_read),0),2) 
     FROM pg_stat_database WHERE datname = current_database()) AS sante_cache_percent;

-- Visualisation
SELECT * FROM v_dashboard_final;