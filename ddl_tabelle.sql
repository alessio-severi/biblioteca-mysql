-- Copyright (C) 2026 Alessio Severi
-- Licensed under CC BY-NC-ND 4.0: https://creativecommons.org/licenses/by-nc-nd/4.0/

-- PROGETTO DATABASE BIBLIOTECA ---



-- Sezione MySQL

-- 1. Definizione dello schema del database (DDL)
CREATE DATABASE IF NOT EXISTS biblioteca;


USE biblioteca;


-- TABELLA 1: LIBRI (Catalogo)
-- Contiene solo i dati bibliografici comuni a tutte le copie.
CREATE TABLE libri (
  id_libro INT PRIMARY KEY AUTO_INCREMENT,
  titolo   VARCHAR(200) NOT NULL,
  autore   VARCHAR(100) NOT NULL,
  genere   VARCHAR(50) NOT NULL,
  isbn     VARCHAR(20) UNIQUE,                      -- Codice univoco internazionale del libro (International Standard Book Number)
  copertina MEDIUMBLOB,                             -- Contiene i dati binari dell’immagine (i byte del file: PNG/JPEG/WebP…).
  copertina_mime_type VARCHAR(50),                  -- il content type (image/jpeg, ecc.), MIME type: 	•	dover “indovinare” il formato dai byte e dover usare sempre un tipo fisso
  fuori_catalogo BOOLEAN NOT NULL DEFAULT FALSE
);



-- TABELLA 2: UTENTI
-- Gestione account come richiesto dalla sezione "Gestione degli Utenti".
CREATE TABLE utenti (
  id_utente          INT PRIMARY KEY AUTO_INCREMENT,
  ruolo              ENUM('admin', 'sub_admin', 'user') NOT NULL DEFAULT 'user',           -- Grado di privilegi: 0 per super amministratore, 1 per amministratore e 2 per user
  nome               VARCHAR(50)  NOT NULL,
  cognome            VARCHAR(50)  NOT NULL,
  email              VARCHAR(100) UNIQUE NOT NULL,
  pass               VARCHAR(255) NOT NULL, 							                                 -- Per l'autenticazione
  data_registrazione DATETIME DEFAULT CURRENT_TIMESTAMP
);



-- TABELLA 3: COPIE_LIBRI (Inventario Fisico)
-- Ogni record rappresenta un libro fisico sullo scaffale.
-- Il campo 'stato' gestisce la disponibilità in tempo reale.
CREATE TABLE copie_libri (
  id_copia          INT PRIMARY KEY AUTO_INCREMENT,
  id_libro          INT NOT NULL,
  codice_inventario VARCHAR(50) UNIQUE NOT NULL,						             -- Es. etichetta col codice a barre
  stato             ENUM('disponibile',
						             'in_prestito',
                         'manutenzione',
                         'ritirato',
                         'perso') DEFAULT 'disponibile',
  FOREIGN KEY (id_libro) REFERENCES libri(id_libro)                      -- Collegamento libri → copie_libri: un libro del catalogo può avere più copie fisiche
  ON DELETE RESTRICT                                                     -- Impedisce l'eliminazione del libro se esistono copie collegate
);



-- TABELLA 4: PRESTITI (Storico e Attivi)
-- Collega l'utente alla copia del libro prestata: in corso (attiva) oppure archiviata.
CREATE TABLE prestiti (
  id_prestito           INT PRIMARY KEY AUTO_INCREMENT,
  id_utente             INT NOT NULL,
  id_copia              INT NOT NULL,
  data_inizio_prestito  DATETIME DEFAULT CURRENT_TIMESTAMP,
  data_restituzione     DATETIME NULL, 							                     -- NULL finché la copia del libro non torna: prestito attivo
  FOREIGN KEY (id_utente) REFERENCES utenti(id_utente)                   -- Collegamento utenti → prestiti: un utente può avere più prestiti nel tempo (storico)
  ON DELETE RESTRICT,                                                    -- Impedisce l'eliminazione dell'utente se esistono prestiti collegati (storico)
  FOREIGN KEY (id_copia)  REFERENCES copie_libri(id_copia)               -- Collegamento copie_libri → prestiti: una copia può apparire in più prestiti nel tempo (storico)
  ON DELETE RESTRICT                                                     -- Impedisce l'eliminazione della copia se esistono prestiti collegati (storico)
);


