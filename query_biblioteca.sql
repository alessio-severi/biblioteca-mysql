-- Copyright (C) 2026 Alessio Severi
-- Licensed under CC BY-NC-ND 4.0: https://creativecommons.org/licenses/by-nc-nd/4.0/

-- ============================================================
--  query_biblioteca.sql
--  File dimostrativo: inserimenti e chiamate alle stored procedure
--  Database: biblioteca
-- ============================================================

USE biblioteca;


-- ============================================================
--  1. INSERIMENTO DATI DI ESEMPIO
-- ============================================================

-- Utenti (password fittizie: in produzione vanno hashate con bcrypt/argon2)
INSERT INTO utenti (ruolo, nome, cognome, email, pass) VALUES
  ('admin',     'Laura',    'Ferretti',  'laura.ferretti@biblioteca.it',  '$2b$12$adminHashFittizio1234567890adminHashFittizio'),
  ('sub_admin', 'Marco',    'Ricci',     'marco.ricci@biblioteca.it',     '$2b$12$subAdminHashFittizio123456789subAdminHashFi'),
  ('user',      'Sofia',    'Martini',   'sofia.martini@gmail.com',       '$2b$12$userHashFittizio12345678901234567890userHash'),
  ('user',      'Luca',     'Colombo',   'luca.colombo@yahoo.it',         '$2b$12$userHashFittizio12345678901234567890userHash'),
  ('user',      'Anna',     'Esposito',  'anna.esposito@outlook.com',     '$2b$12$userHashFittizio12345678901234567890userHash'),
  ('user',      'Giovanni', 'Romano',    'giovanni.romano@libero.it',     '$2b$12$userHashFittizio12345678901234567890userHash');


-- Libri (catalogo)
INSERT INTO libri (titolo, autore, genere, isbn) VALUES
  ('Il nome della rosa',         'Umberto Eco',        'Storico',    '9788845292613'),
  ('Se questo è un uomo',        'Primo Levi',         'Narrativa',  '9788806219390'),
  ('I Promessi Sposi',           'Alessandro Manzoni', 'Classico',   '9788804667339'),
  ('Il deserto dei Tartari',     'Dino Buzzati',       'Narrativa',  '9788817127394'),
  ('Siddharta',                  'Hermann Hesse',      'Filosofico', '9788804700951'),
  ('Fahrenheit 451',             'Ray Bradbury',       'Fantascienza','9788804668220'),
  ('Il vecchio e il mare',       'Ernest Hemingway',   'Narrativa',  '9788845296864'),
  ('La fattoria degli animali',  'George Orwell',      'Satira',     '9788804731382');


-- Copie fisiche (inventario)
INSERT INTO copie_libri (id_libro, codice_inventario, stato) VALUES
  (1, 'LIB-001-A', 'disponibile'),
  (1, 'LIB-001-B', 'disponibile'),
  (1, 'LIB-001-C', 'manutenzione'),
  (2, 'LIB-002-A', 'disponibile'),
  (2, 'LIB-002-B', 'disponibile'),
  (3, 'LIB-003-A', 'disponibile'),
  (4, 'LIB-004-A', 'disponibile'),
  (4, 'LIB-004-B', 'disponibile'),
  (5, 'LIB-005-A', 'disponibile'),
  (6, 'LIB-006-A', 'disponibile'),
  (6, 'LIB-006-B', 'disponibile'),
  (7, 'LIB-007-A', 'disponibile'),
  (8, 'LIB-008-A', 'disponibile'),
  (8, 'LIB-008-B', 'disponibile');




-- ============================================================
--  2. STORED PROCEDURE — CATALOGO (Consultazione)
-- ============================================================

-- Lista tutti i libri disponibili con conteggio copie
CALL listaLibriDisponibili(@msg);
SELECT @msg;


-- Ricerca per autore
CALL ricercaLibri('autore', 'Orwell', @msg);
SELECT @msg;

-- Ricerca per genere
CALL ricercaLibri('genere', 'Narrativa', @msg);
SELECT @msg;

-- Ricerca per titolo
CALL ricercaLibri('titolo', 'rosa', @msg);
SELECT @msg;

-- Ricerca per ISBN
CALL ricercaLibri('isbn', '9788845292613', @msg);
SELECT @msg;

-- Tipo ricerca non valido (errore atteso)
CALL ricercaLibri('editore', 'Mondadori', @msg);
SELECT @msg;




-- ============================================================
--  3. STORED PROCEDURE — COPIE FISICHE
-- ============================================================

-- Visualizza copie in manutenzione
CALL copiePerStato('manutenzione', @msg);
SELECT @msg;

-- Visualizza copie disponibili
CALL copiePerStato('disponibile', @msg);
SELECT @msg;

-- Stato non valido (errore atteso)
CALL copiePerStato('smarrito', @msg);
SELECT @msg;


-- Aggiunge una nuova copia a un libro esistente
CALL aggiungiCopia(5, 'LIB-005-B', @msg);
SELECT @msg;

-- Errore: libro non trovato
CALL aggiungiCopia(99, 'LIB-099-A', @msg);
SELECT @msg;


-- Mette una copia in manutenzione (copia 3 = LIB-001-C già in manutenzione → errore)
CALL metteCopiaInManutenzione(1, @msg);
SELECT @msg;

-- Rimette disponibile la copia in manutenzione
CALL rimetteCopiaMDisponibile(3, @msg);
SELECT @msg;

-- Segna una copia come persa (copia 14 = LIB-008-B)
CALL metteCopiaPersa(14, @msg);
SELECT @msg;




-- ============================================================
--  4. STORED PROCEDURE — PRESTITI (Gestione)
-- ============================================================

-- Crea prestiti: utente 3 (Sofia) prende la copia 1, utente 4 (Luca) prende la copia 4
CALL creaPrestito(3, 1, @msg);
SELECT @msg;

CALL creaPrestito(4, 4, @msg);
SELECT @msg;

CALL creaPrestito(5, 6, @msg);
SELECT @msg;

-- Errore: copia già in prestito
CALL creaPrestito(6, 1, @msg);
SELECT @msg;

-- Errore: utente non trovato
CALL creaPrestito(99, 2, @msg);
SELECT @msg;


-- Registra la restituzione del prestito 1 (Sofia restituisce LIB-001-A)
CALL registraRestituzione(1, @msg);
SELECT @msg;

-- Errore: prestito già restituito
CALL registraRestituzione(1, @msg);
SELECT @msg;


-- Segna la copia del prestito 2 come persa durante il prestito
CALL registraCopiaPrestataPersa(2, @msg);
SELECT @msg;


-- Elimina/annulla prestito 3 (Luca aveva LIB-006-A)
CALL eliminaPrestito(3, @msg);
SELECT @msg;

-- Errore: prestito non trovato
CALL eliminaPrestito(99, @msg);
SELECT @msg;




-- ============================================================
--  5. STORED PROCEDURE — PRESTITI (Consultazione)
-- ============================================================

-- Visualizza tutti i prestiti attivi
CALL prestitiAttivi(@msg);
SELECT @msg;

-- Visualizza utenti con prestiti oltre 30 giorni (inizialmente vuoto nei dati demo)
CALL utentiPrestitiOltre30Giorni(@msg);
SELECT @msg;

-- Storico utente 3 (Sofia) senza anomalie (accesso user)
CALL storicoUtente(3, FALSE, @msg);
SELECT @msg;

-- Storico utente 4 (Luca) con anomalie visibili (accesso admin/sub_admin)
CALL storicoUtente(4, TRUE, @msg);
SELECT @msg;

-- Errore: utente non trovato
CALL storicoUtente(99, FALSE, @msg);
SELECT @msg;




-- ============================================================
--  6. STORED PROCEDURE — CATALOGO (Gestione)
-- ============================================================

-- Mette fuori catalogo il libro 8 (La fattoria degli animali)
CALL metteFuoriCatalogo(8, @msg);
SELECT @msg;

-- Errore: libro già fuori catalogo
CALL metteFuoriCatalogo(8, @msg);
SELECT @msg;

-- Rimette in catalogo il libro 8
CALL rimetteInCatalogo(8, @msg);
SELECT @msg;

-- Errore: libro già in catalogo
CALL rimetteInCatalogo(8, @msg);
SELECT @msg;




-- ============================================================
--  7. STORED PROCEDURE — UTENTI (Consultazione e gestione)
-- ============================================================

-- Lista utenti registrati (esclude admin)
CALL listaUtentiRegistrati(@msg);
SELECT @msg;


-- Modifica dati utente 3 (Sofia)
CALL modificaUtente(3, 'Sofia', 'Martini', 'sofia.martini.new@gmail.com', @msg);
SELECT @msg;

-- Errore: email già in uso
CALL modificaUtente(4, 'Luca', 'Colombo', 'sofia.martini.new@gmail.com', @msg);
SELECT @msg;


-- Modifica password utente 5 (Anna) — hash fittizio valido (>= 50 caratteri)
CALL modificaPasswordUtente(5, '$2b$12$nuovoHashFittizioDiAlmenoC inquantaCaratteri', @msg);
SELECT @msg;

-- Errore: hash troppo corto
CALL modificaPasswordUtente(5, 'corto', @msg);
SELECT @msg;


-- Modifica ruolo utente 4 (Luca) da user a sub_admin
CALL modificaRuoloUtente(4, 'sub_admin', @msg);
SELECT @msg;

-- Errore: non si può assegnare il ruolo admin
CALL modificaRuoloUtente(5, 'admin', @msg);
SELECT @msg;

-- Errore: ruolo non valido
CALL modificaRuoloUtente(5, 'superuser', @msg);
SELECT @msg;




-- ============================================================
--  8. STORED PROCEDURE — ELIMINAZIONE
-- ============================================================

-- Elimina utente 6 (Giovanni, senza prestiti)
CALL deleteUtente(6, @msg);
SELECT @msg;

-- Errore: utente con prestiti nello storico (Sofia, id 3)
CALL deleteUtente(3, @msg);
SELECT @msg;

-- Errore: utente non trovato
CALL deleteUtente(99, @msg);
SELECT @msg;


-- Elimina libro 8 (La fattoria degli animali): prima rimuovi le copie manualmente per la demo
-- In produzione: le copie vanno gestite prima della cancellazione del libro
-- DELETE FROM copie_libri WHERE id_libro = 8;
CALL deleteLibro(8, @msg);
SELECT @msg;

-- Errore: libro con copie collegate
CALL deleteLibro(1, @msg);
SELECT @msg;
