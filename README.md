# 🚀 CryptoTrade - High-Performance PostgreSQL Database

**Projet :** Architecture de Base de Données Trading Temps Réel
**Date :** Décembre 2025
**Technologie :** PostgreSQL 16+, PL/pgSQL

---

## 📌 Présentation du Projet
CryptoTrade est une infrastructure de base de données optimisée pour gérer des **millions d'ordres boursiers** avec une latence minimale (<50ms). Ce projet résout les problèmes classiques des plateformes de trading (deadlocks, lenteur des indicateurs, fraude) grâce à une utilisation experte de PostgreSQL.

### 🏆 Fonctionnalités Clés
- **Haute Performance :** Partitionnement natif (Time-Series) et Tuning serveur avancé (`work_mem`, `fillfactor`).
- **Finance Temps Réel :** Calculs instantanés (VWAP, RSI, Volatilité) grâce au *Caching* (Vues Matérialisées).
- **Sécurité Anti-Fraude :** Détection automatique du *Wash Trading* et *Spoofing* via Triggers comportementaux.
- **Intégrité Transactionnelle :** Gestion des portefeuilles avec **Advisory Locks** (Verrous Consultatifs) pour garantir 0 conflit.

---

## 🏗️ Structure du Projet

Le dépôt est organisé selon une structure modulaire stricte :

```text
CryptoTrade-Project/
├── Dashboard_Performance/   # Tableau de Bord et Monitoring
│   └── Dashboard.sql        # Vue synthétique unifiée (KPIs, Alertes, Cache)
│
├── docs/                    # Documentation Technique Détaillée
│   ├── PERFORMANCE_TUNING.md # Justification des choix d'optimisation
│   └── MONITORING.md         # Guide de surveillance et d'intervention
│
├── sql/                     # Codes Sources SQL
│   ├── 01_ddl/              # Structure (Schema, Tables, Partitions)
│   ├── 02_dml/              # Données (Script de génération 1M lignes)
│   ├── 03_queries/          # Requêtes (Business, Benchmarks, Advanced)
│   ├── 04_programmability/  # Logique (Fonctions, Triggers, Procédures)
│   └── 05_optimization/     # Performance (Tuning Serveur, Vues Matérialisées)
│
└── README.md                # Documentation Générale
```
---

## ⚙️ Guide d'Installation (Ordre d'Exécution)
**Pour déployer le projet sans erreur, exécutez les scripts SQL dans cet ordre précis :**

- **Structure :** sql/01_ddl/01_create_tables.sql

- **Configuration Serveur :** sql/05_optimization/00_server_tuning.sql

- **Injection de Données :** sql/02_dml/01_generate_data.sql (Patientez ~30sec)

- **Logique Métier :**

        sql/04_programmability/ 01_market_indicators.sql

        sql/04_programmability/02_fraud_detection.sql

        sql/04_programmability/03_update_wallet.sql

- **Accélération :** sql/05_optimization/02_materialized_views.sql

- **Monitoring :** Dashboard_Performance/Dashboard.sql

## 📊 Utilisation & Démo

1. **Le Cockpit de Pilotage**
Pour voir l'état de santé global du système (Business, Sécurité, Cache) :
```
SELECT * FROM dashboard_global_synthese;
```
2. **Tests de Performance**
Un script de benchmark "Avant/Après" est disponible pour prouver les gains d'indexation :

```
-- Exécuter le fichier sql/03_queries/02_benchmark_tests.sql
```

3. **Validation des Performances**

Nous avons inclus un script de benchmark **(sql/03_queries/02_benchmark_tests.sql)** qui compare les temps d'exécution AVANT et APRÈS indexation.

    Résultat attendu : Gain moyen de x40 sur les requêtes analytiques.

## 💻 Prérequis Techniques
Pour déployer ce projet, vous avez besoin de :

* **PostgreSQL 15 ou 16** (Requis pour `CREATE STATISTICS`).
* **pgAdmin 4** ou **DBeaver** (Pour la visualisation).
* **Espace disque :** ~500MB pour le dataset de test (1M lignes).