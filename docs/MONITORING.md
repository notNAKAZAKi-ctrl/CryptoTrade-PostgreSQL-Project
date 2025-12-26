# 📡 Monitoring & Guide d'Intervention

Le système intègre un module de surveillance (`Dashboard_Performance/`) permettant de piloter la plateforme en temps réel.

---

## 1. Seuils d'Alerte (KPIs)

Voici les métriques critiques surveillées par la vue `dashboard_global_synthese` :

| Métrique | Seuil Normal | Seuil Critique 🚨 | Action Requise |
| :--- | :--- | :--- | :--- |
| **Cache Hit Ratio** | > 99% | **< 95%** | Augmenter `shared_buffers` ou vérifier les Full Scans. |
| **Alertes Fraude** | 0 | **> 1** | Bloquer l'utilisateur et analyser les logs `detection_anomalie`. |
| **Seq Scans** | < 1000 | **En hausse** | Manque d'index sur une table volumineuse. |
| **Ordres en Attente**| Variable | **Explosion soudaine** | Vérifier si le moteur de matching est bloqué. |

---

## 2. Le Cockpit de Pilotage
La vue `dashboard_global_synthese` agrège trois dimensions :

### A. Business
Affiche le prix du **Bitcoin (BTC)** et le volume 24h. Si le prix ou le volume tombe à 0, vérifier l'ingestion des données.

### B. Sécurité
Le système remonte automatiquement les statuts :
* 🟢 **OK** : Aucune activité suspecte.
* 🔴 **DANGER** : Détection de *Wash Trading* ou *Spoofing* dans la dernière heure.

### C. Performance Système
Affiche la taille de la base et la santé du cache. Une chute du cache indique souvent une requête mal optimisée qui lit tout le disque.

---

## 3. Procédures d'Intervention

### Cas 1 : Alerte "🔴 DANGER" (Fraude)
1.  Exécuter la vue détaillée : `SELECT * FROM dashboard_securite;`
2.  Identifier l'utilisateur et le type d'attaque.
3.  Bannir l'utilisateur immédiatement :
    ```sql
    UPDATE utilisateurs SET statut = 'INACTIF' WHERE id = [ID_UTILISATEUR];
    ```

### Cas 2 : Lenteur Globale (Cache < 95%)
1.  Identifier les requêtes gourmandes :
    ```sql
    SELECT query, calls, total_exec_time 
    FROM pg_stat_statements 
    ORDER BY total_exec_time DESC LIMIT 5;
    ```
2.  Identifier les tables manquant d'index :
    ```sql
    SELECT * FROM dashboard_performance WHERE scans_lents > 1000;
    ```
3.  Lancer une maintenance d'urgence :
    ```sql
    VACUUM ANALYZE;
    ```