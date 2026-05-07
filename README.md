# biblioteca-mysql

Schema e logica del database relazionale per una web app di gestione biblioteca, sviluppato in MySQL.

Per altri progetti su codice e algoritmi, visita: [chorax.it/codice-e-creativita](https://chorax.it/codice-e-creativita/)

## Descrizione

Il database gestisce il catalogo bibliografico, l'inventario fisico delle copie, gli utenti con sistema di ruoli e i prestiti attivi e storici. Tutta la logica operativa è incapsulata in stored procedure, con trigger che mantengono automaticamente la coerenza degli stati delle copie.

## Struttura del repository

- [`ddl_tabelle.sql`](ddl_tabelle.sql) — 4 definizioni per le tabelle principali: `libri`, `utenti`, `copie_libri`, `prestiti`
- [`ddl_trigger.sql`](ddl_trigger.sql) — 4 trigger per la gestione automatica degli stati delle copie
- [`ddl_stored_procedures.sql`](ddl_stored_procedures.sql) — 24 stored procedure che coprono catalogo, inventario, prestiti e gestione utenti
- [`query_biblioteca.sql`](query_biblioteca.sql) — inserimenti e chiamate dimostrative a tutte le stored procedure
- [`documentazione_biblioteca_mysql.pdf`](documentazione_biblioteca_mysql.pdf) — documentazione completa: struttura tabelle, trigger, architettura permessi e matrice delle stored procedure per ruolo

## Funzionalità principali

Il database supporta tre ruoli con gerarchia inclusiva: `admin`, `sub_admin` e `user`. Le stored procedure coprono:

- Consultazione e ricerca del catalogo per titolo, autore, genere o ISBN
- Gestione catalogo: aggiunta e rimozione libri, messa fuori catalogo e ripristino
- Gestione inventario: aggiunta copie, manutenzione, copie perse
- Gestione prestiti: creazione, restituzione, annullamento, storico per utente, controllo ritardi oltre 30 giorni
- Gestione utenti: registrazione, modifica dati, cambio password, modifica ruolo, eliminazione
- Upload e rimozione copertine

Le restrizioni di accesso per ruolo sono documentate nel PDF allegato e delegate al backend applicativo.

## Requisiti

- MySQL 8.0+

## Avvio

```sql
SOURCE ddl_tabelle.sql;
SOURCE ddl_trigger.sql;
SOURCE ddl_stored_procedures.sql;
```

Per caricare i dati dimostrativi:

```sql
SOURCE query_biblioteca.sql;
```

## Licenza

© 2026 Alessio Severi — licensed under [CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/).
See the [LICENSE](LICENSE) file for details.
