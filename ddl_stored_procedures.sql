-- Copyright (C) 2026 Alessio Severi
-- Licensed under CC BY-NC-ND 4.0: https://creativecommons.org/licenses/by-nc-nd/4.0/

-- PROGETTO DATABASE BIBLIOTECA ---



-- Sezione MySQL

-- 3. Creazione di una STORED PROCEDURE con parametri IN (in ingresso) e OUT (in uscita)

-- 3.1 Eliminazione utente:
-- cancella un utente solo se non ha prestiti nello storico,
-- coerente con ON DELETE RESTRICT su FK prestiti.id_utente
DROP PROCEDURE IF EXISTS deleteUtente;

DELIMITER $$

CREATE PROCEDURE deleteUtente(IN idutente INT, OUT msg VARCHAR(100))
BEGIN
  DECLARE utente_count INT;
  DECLARE prestiti_totali INT;  -- conteggio dei prestiti (attivi + chiusi)
    
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET msg = 'ERRORE SQL durante la cancellazione dell''utente';
  END;

  START TRANSACTION;
    
  -- Verifica esistenza utente
  SELECT COUNT(*)
  INTO utente_count
  FROM utenti
  WHERE id_utente = idutente;
    
  IF utente_count = 0 THEN
    SET msg = 'Errore: Utente non trovato';
    ROLLBACK;

  ELSE
    -- Verifica se un utente ha almeno un prestito nello storico
    SELECT COUNT(*)
    INTO prestiti_totali
    FROM prestiti
    WHERE id_utente = idutente;
        
    IF prestiti_totali > 0 THEN
      SET msg = CONCAT('Errore: Utente ha ', prestiti_totali, ' prestiti nello storico');
      ROLLBACK;

    ELSE
      -- Nessuna copia presente nello storico dell'utente → Cancellazione sicura
      DELETE FROM utenti
      WHERE id_utente = idutente;

      SET msg = 'Utente cancellato con successo';
      COMMIT;

    END IF;
  END IF;

END$$
DELIMITER ;




-- 3.2 Eliminazione libro
-- cancella libro solo se non esistono copie fisiche,
-- coerente con ON DELETE RESTRICT su FK copie_libri.id_libro
DROP PROCEDURE IF EXISTS deleteLibro;

DELIMITER $$

CREATE PROCEDURE deleteLibro(IN idlibro INT, OUT msg VARCHAR(100))
BEGIN
  DECLARE libro_count INT;
  DECLARE copie_totali INT;  -- conteggio di tutte le copie (qualsiasi stato) per un dato libro
    
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
      SET msg = 'ERRORE SQL durante la cancellazione del libro';
  END;

  START TRANSACTION;
    
  -- Verifica esistenza del libro
  SELECT COUNT(*)
  INTO libro_count
  FROM libri
  WHERE id_libro = idlibro;
    
  IF libro_count = 0 THEN
    SET msg = 'Errore: Libro non trovato';
    ROLLBACK;

  ELSE
    -- Verifica se esistono copie associate al libro in oggetto
    SELECT COUNT(*)
    INTO copie_totali
    FROM copie_libri
    WHERE id_libro = idlibro;
        
    IF copie_totali > 0 THEN
      SET msg = CONCAT('Errore: Esistono ', copie_totali, ' copie collegate');
      ROLLBACK;

    ELSE
      -- Nessuna copia → Cancellazione sicura
      DELETE FROM libri
      WHERE id_libro = idlibro;

      SET msg = 'Libro cancellato con successo';
      COMMIT;
      
    END IF;
  END IF;

END$$
DELIMITER ;




-- 3.3 Elenco dei libri disponibili con conteggio copie disponibili per ciascun libro
-- ps: nella vista non serve il campo L.id_libro (solo per la gestione di altre operazioni)
DROP PROCEDURE IF EXISTS listaLibriDisponibili;

DELIMITER $$

CREATE PROCEDURE listaLibriDisponibili(OUT msg VARCHAR(30))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SET msg = 'ERRORE SQL: Impossibile trovare l''elenco dei libri disponibili';
  END;
  -- Query unificata con campo ha_copertina
  SELECT L.id_libro,
         MAX(L.titolo) AS titolo,
         MAX(L.autore) AS autore,
         MAX(L.genere) AS genere,
         MAX(L.isbn)   AS isbn,
         MAX(CASE
              WHEN L.copertina IS NOT NULL THEN
                1
              ELSE
                0
             END) AS ha_copertina,
         COUNT(C.id_copia) AS "Copie Attualmente Disponibili"

  FROM libri L
  JOIN copie_libri C
  ON L.id_libro = C.id_libro
  WHERE L.fuori_catalogo = FALSE AND C.stato = 'disponibile'
  GROUP BY L.id_libro
  ORDER BY MAX(L.autore), MAX(L.titolo), MAX(L.genere), MAX(L.isbn);


  SET msg = 'Query eseguita';

END$$
DELIMITER ;




-- 3.4 Trova tutti gli utenti che hanno una copia di un libro in prestito da più
-- di 30 giorni e non l'hanno ancora restituito.
DROP PROCEDURE IF EXISTS utentiPrestitiOltre30Giorni;

DELIMITER $$

CREATE PROCEDURE utentiPrestitiOltre30Giorni(OUT msg VARCHAR(30))
BEGIN
  DECLARE data_minima_inizio_prestito DATETIME;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SET MSG = 'ERRORE SQL: Impossibile trovare gli utenti che hanno una copia di un libro in prestito da più di 30 giorni';
  END;

  SET data_minima_inizio_prestito = NOW() - INTERVAL 30 DAY;

  SELECT U.nome,
         U.cognome,
         U.email,
         L.titolo,
         P.data_inizio_prestito,
         C.stato,
         TIMESTAMPDIFF(DAY, P.data_inizio_prestito, NOW()) AS "Durata prestito"

  FROM prestiti P
  JOIN utenti U
  ON P.id_utente = U.id_utente
  JOIN copie_libri C
  ON P.id_copia = C.id_copia
  JOIN libri L
  ON C.id_libro = L.id_libro
  WHERE C.stato = 'in_prestito'
    AND P.data_inizio_prestito < data_minima_inizio_prestito              -- Non ancora restituito e da almeno 30 giorni
  ORDER BY TIMESTAMPDIFF(DAY, P.data_inizio_prestito, NOW()) DESC;        -- ordine dall'utente con una durata del prestito maggiore


  SET msg = 'Query eseguita';

END$$
DELIMITER ;




-- 3.5 Visualizza tutti i prestiti attivi (non ancora restituiti e non persi)
DROP PROCEDURE IF EXISTS prestitiAttivi;

DELIMITER $$

CREATE PROCEDURE prestitiAttivi(OUT msg VARCHAR(30))
BEGIN

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SET msg = 'ERRORE SQL: Impossibile visualizzare tutti i prestiti attivi (non persi)';
  END;

  SELECT p.id_prestito,
         u.nome, u.cognome, u.email,
         l.titolo, l.autore,
         c.codice_inventario, c.stato,
         p.data_inizio_prestito,
         TIMESTAMPDIFF(DAY, p.data_inizio_prestito, NOW()) AS "Durata prestito"

  FROM prestiti p
  JOIN utenti u
  ON p.id_utente = u.id_utente
  JOIN copie_libri c
  ON p.id_copia = c.id_copia
  JOIN libri l
  ON c.id_libro = l.id_libro
  WHERE c.stato = 'in_prestito'
  ORDER BY p.data_inizio_prestito;


  SET msg = 'Query eseguita';
  
END$$

DELIMITER ;





-- 3.6 Visualizza tutti gli utenti registrati tranne l'admin
DROP PROCEDURE IF EXISTS listaUtentiRegistrati;

DELIMITER $$

CREATE PROCEDURE listaUtentiRegistrati(OUT msg VARCHAR(30))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SET msg = 'ERRORE SQL: Impossibile visualizzare tutti gli utenti registrati';
  END;

  SELECT id_utente,
         ruolo,
         nome,
         cognome,
         email,
        data_registrazione
  FROM utenti
  WHERE ruolo IN ('sub_admin', 'user')
  ORDER BY data_registrazione DESC;

  SET msg = 'Query eseguita';

END$$

DELIMITER ;



-- 3.7 Storico completo prestiti di un utente specifico (accesso per l'utente):
-- User vede solo il proprio storico (senza anomalie)
-- Storico completo prestiti di un utente specifico (accesso solo per admin o sub_admin):
-- Admin/sub_admin vedono qualsiasi storico (con anomalie visibili)
DROP PROCEDURE IF EXISTS storicoUtente;

DELIMITER $$

CREATE PROCEDURE storicoUtente(IN idutente INT, IN p_mostra_anomalie BOOLEAN, OUT msg VARCHAR(50))
BEGIN
  DECLARE utente_count INT;
  
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SET msg = 'ERRORE SQL: Impossibile visualizzare lo storico completo dei prestiti dell''utente';
  END;
    
    -- Verifica l'esistenza dell'utente
    SELECT COUNT(*)
    INTO utente_count
    FROM utenti
    WHERE id_utente = idutente;
    
    IF utente_count = 0 THEN
      SET msg = 'Errore: Utente non trovato';
  
    ELSE

      SELECT p.id_prestito,
            l.titolo, l.autore,
            c.codice_inventario,
            p.data_inizio_prestito,
            p.data_restituzione,
            CASE
              WHEN p.data_restituzione IS NOT NULL THEN 'Restituito'
              WHEN p.data_restituzione IS NULL AND c.stato = 'in_prestito' THEN 'In corso'
              WHEN p.data_restituzione IS NULL AND c.stato = 'perso' THEN 'Chiuso (perso)'
              WHEN p_mostra_anomalie = TRUE THEN CONCAT('Anomalo: ', c.stato)
            END AS "Stato prestito"

      FROM prestiti p
      JOIN copie_libri c
      ON p.id_copia = c.id_copia
      JOIN libri l
      ON c.id_libro = l.id_libro
      WHERE p.id_utente = idutente
      ORDER BY p.data_inizio_prestito DESC;


      SET msg = 'Query eseguita';

    END IF;

END$$
DELIMITER ;




-- 3.8 Crea un nuovo prestito
-- 1. Verifica l'esistenza della copia di un libro
-- 2. Verifica la disponibilità della copia di un libro
-- 3. Verifica l'esistenza dell'utente
-- 4. Inserisce un nuovo prestito di una copia di un libro per un utente
DROP PROCEDURE IF EXISTS creaPrestito;

DELIMITER $$

CREATE PROCEDURE creaPrestito(IN p_id_utente INT, IN p_id_copia INT, OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_stato_copia VARCHAR(20);
  DECLARE v_titolo VARCHAR(200);
  DECLARE v_autore VARCHAR(200);
  DECLARE copia_count INT;
  DECLARE utente_count INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile creare il prestito';
  END;


  START TRANSACTION;

  -- Verifica l'esistenza della copia
  SELECT COUNT(*)
  INTO copia_count
  FROM copie_libri
  WHERE id_copia = p_id_copia;
    
  IF copia_count = 0 THEN
      SET p_esito = 'ERRORE: Copia non trovata';
      ROLLBACK;
  ELSE
  
    -- Verifica se la copia esiste ed è disponibile
    -- Recupera stato, titolo e autore
    SELECT c.stato, l.titolo, l.autore
    INTO v_stato_copia, v_titolo, v_autore
    FROM copie_libri c
    JOIN libri l
    ON c.id_libro = l.id_libro
    WHERE c.id_copia = p_id_copia;
      
    IF v_stato_copia != 'disponibile' THEN
      SET p_esito = CONCAT('ERRORE: Copia non disponibile (stato: ', v_stato_copia, ')');
      ROLLBACK;
    ELSE

      -- Verifica l'esistenza dell'utente
      SELECT COUNT(*)
      INTO utente_count
      FROM utenti
      WHERE id_utente = p_id_utente;
      
      IF utente_count = 0 THEN
        SET p_esito = 'Errore: Utente non trovato';
        ROLLBACK;

      ELSE

        -- Crea il prestito
        INSERT INTO prestiti (id_utente, id_copia, data_inizio_prestito)
        VALUES (p_id_utente, p_id_copia, NOW());

        SET p_esito = CONCAT('OK: Prestito creato (', v_titolo, ' di ', v_autore, ')');

        COMMIT;

       END IF;
    END IF;
  END IF;

END$$
DELIMITER ;



-- 3.9 Registrare una restituzione
DROP PROCEDURE IF EXISTS registraRestituzione;

DELIMITER $$

CREATE PROCEDURE registraRestituzione(IN p_id_prestito INT, OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_data_restituzione DATETIME;
  DECLARE v_titolo VARCHAR(200);
  DECLARE v_autore VARCHAR(200);
  DECLARE v_stato_copia VARCHAR(20);
  DECLARE prestito_count INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile registrare la restituzione';
  END;


  START TRANSACTION;

  -- Verifica l'esistenza del prestito
  SELECT COUNT(*)
  INTO prestito_count
  FROM prestiti
  WHERE id_prestito = p_id_prestito;
    
  IF prestito_count = 0 THEN
      SET p_esito = 'ERRORE: Prestito non trovato';
      ROLLBACK;
  ELSE


    SELECT p.data_restituzione, c.stato, l.titolo, l.autore
    INTO v_data_restituzione, v_stato_copia, v_titolo, v_autore
    FROM prestiti p
    JOIN copie_libri c
    ON p.id_copia = c.id_copia
    JOIN libri l
    ON c.id_libro = l.id_libro
    WHERE p.id_prestito = p_id_prestito;


    IF v_data_restituzione IS NULL AND v_stato_copia = 'in_prestito' THEN

      -- Registra la restituzione
      UPDATE prestiti
      SET data_restituzione = NOW()
      WHERE id_prestito = p_id_prestito;
      
      SET p_esito = CONCAT('OK: Restituzione registrata (', v_titolo, ' di ', v_autore, ')');

      COMMIT;


    ELSEIF v_data_restituzione IS NOT NULL THEN
      SET p_esito = 'ERRORE: Prestito già restituito';
      ROLLBACK;

    ELSEIF v_data_restituzione IS NULL AND v_stato_copia = 'perso' THEN
      SET p_esito = 'ERRORE: Prestito perso e non può essere restituito';
      ROLLBACK;

    ELSE
      SET p_esito = CONCAT('ERRORE: Lo stato della copia è: ', v_stato_copia, ' -> Modifica lo stato');
      ROLLBACK;

    END IF;
  END IF;

END$$
DELIMITER ;



-- 3.10 Aggiorna lo stato della copia prestata come 'perso'
DROP PROCEDURE IF EXISTS registraCopiaPrestataPersa;

DELIMITER $$

CREATE PROCEDURE registraCopiaPrestataPersa(IN p_id_prestito INT, OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_data_restituzione DATETIME;
  DECLARE v_titolo VARCHAR(200);
  DECLARE v_autore VARCHAR(200);
  DECLARE v_stato_copia VARCHAR(20);
  DECLARE prestito_count INT;
  DECLARE v_id_copia INT;


  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile aggiornare lo stato della copia prestata come "perso"';
  END;


  START TRANSACTION;

  -- Verifica l'esistenza del prestito
  SELECT COUNT(*)
  INTO prestito_count
  FROM prestiti
  WHERE id_prestito = p_id_prestito;
    
  IF prestito_count = 0 THEN
      SET p_esito = 'ERRORE: Prestito non trovato';
      ROLLBACK;

  ELSE

    SELECT p.data_restituzione, c.id_copia, c.stato, l.titolo, l.autore
    INTO v_data_restituzione, v_id_copia, v_stato_copia, v_titolo, v_autore
    FROM prestiti p
    JOIN copie_libri c
    ON p.id_copia = c.id_copia
    JOIN libri l
    ON c.id_libro = l.id_libro
    WHERE p.id_prestito = p_id_prestito;


    IF v_data_restituzione IS NULL AND v_stato_copia = 'in_prestito' THEN

      -- Aggiornamento dello stato della copia prestata come 'perso'
      UPDATE copie_libri
      SET stato = 'perso'
      WHERE id_copia = v_id_copia;
      
      SET p_esito = CONCAT('OK: Copia prestata in stato "perso" (', v_titolo, ' di ', v_autore, ')');

      COMMIT;


    ELSEIF v_data_restituzione IS NOT NULL THEN
      SET p_esito = 'ERRORE: Prestito già restituito';
      ROLLBACK;

    ELSEIF v_data_restituzione IS NULL AND v_stato_copia = 'perso' THEN
      SET p_esito = 'ERRORE: Copia già in stato "perso"';
      ROLLBACK;

    ELSE
      SET p_esito = CONCAT('ERRORE: Lo stato della copia è: ', v_stato_copia, ' -> Modifica lo stato');
      ROLLBACK;

    END IF;
  END IF;

END$$
DELIMITER ;



-- 3.11 Aggiungere una nuova copia all'inventario
DROP PROCEDURE IF EXISTS aggiungiCopia;

DELIMITER $$

CREATE PROCEDURE aggiungiCopia(IN p_id_libro INT, IN p_codice_inventario VARCHAR(50), OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_titolo VARCHAR(200);
  DECLARE v_autore VARCHAR(200);
  DECLARE v_fuori_catalogo BOOLEAN;
  DECLARE libro_count INT;
  
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile aggiungere la copia all''inventario';
  END;


  START TRANSACTION;
    
  -- Verifica esistenza del libro
  SELECT COUNT(*)
  INTO libro_count
  FROM libri
  WHERE id_libro = p_id_libro;
    
  IF libro_count = 0 THEN
    SET p_esito = 'Errore: Libro non trovato';
    ROLLBACK;

  ELSE

    SELECT titolo, autore, fuori_catalogo
    INTO v_titolo, v_autore, v_fuori_catalogo
    FROM libri
    WHERE id_libro = p_id_libro;
    
    IF v_fuori_catalogo = TRUE THEN
      SET p_esito = CONCAT('ERRORE: "', v_titolo, '" di "', v_autore, '" è fuori catalogo');
      ROLLBACK;

    ELSE
      INSERT INTO copie_libri (id_libro, codice_inventario, stato)
      VALUES (p_id_libro, p_codice_inventario, 'disponibile');
      
      SET p_esito = CONCAT('OK: Copia aggiunta (', v_titolo, ' di ', v_autore, ')');

      COMMIT;

    END IF;
  END IF;

END$$
DELIMITER ;



-- 3.12 Mettere un libro fuori catalogo (il trigger gestisce le copie)
DROP PROCEDURE IF EXISTS metteFuoriCatalogo;

DELIMITER $$

CREATE PROCEDURE metteFuoriCatalogo(IN p_id_libro INT, OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_titolo         VARCHAR(200);
  DECLARE v_autore         VARCHAR(200);
  DECLARE v_copie_ritirate INT;
  DECLARE v_fuori_catalogo BOOLEAN;
  DECLARE libro_count      INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile mettere il libro fuori catalogo';
  END;

  START TRANSACTION;

  -- Verifica esistenza del libro
  SELECT COUNT(*)
  INTO libro_count
  FROM libri
  WHERE id_libro = p_id_libro;

  IF libro_count = 0 THEN
    SET p_esito = 'ERRORE: Libro non trovato';
    ROLLBACK;

  ELSE
    -- Legge info libro
    SELECT titolo, autore, fuori_catalogo
    INTO v_titolo, v_autore, v_fuori_catalogo
    FROM libri
    WHERE id_libro = p_id_libro;

    -- Verifica se già fuori catalogo
    IF v_fuori_catalogo = TRUE THEN
      SET p_esito = CONCAT('ERRORE: "', v_titolo, '" di "', v_autore, '" è già fuori catalogo');
      ROLLBACK;

    ELSE
      -- Aggiorna il libro (il trigger gestirà lo stato delle copie associate)
      UPDATE libri
      SET fuori_catalogo = TRUE
      WHERE id_libro = p_id_libro;

      -- Conta quante copie risultano ritirate (dopo l'azione del trigger)
      SELECT COUNT(*)
      INTO v_copie_ritirate
      FROM copie_libri
      WHERE id_libro = p_id_libro AND stato = 'ritirato';

      SET p_esito = CONCAT('OK: "', v_titolo, '" di "', v_autore, '" fuori catalogo. Copie attualmente ritirate: ', v_copie_ritirate);

      COMMIT;

    END IF;
  END IF;

END$$
DELIMITER ;



-- 3.13 Rimettere un libro in catalogo (il trigger gestisce le copie)
DROP PROCEDURE IF EXISTS rimetteInCatalogo;

DELIMITER $$

CREATE PROCEDURE rimetteInCatalogo(IN p_id_libro INT, OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_titolo         VARCHAR(200);
  DECLARE v_autore         VARCHAR(200);
  DECLARE v_fuori_catalogo BOOLEAN;
  DECLARE libro_count      INT;
  DECLARE v_copie_attivate INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile rimettere il libro in catalogo';
  END;

  START TRANSACTION;

  -- Verifica esistenza del libro
  SELECT COUNT(*)
  INTO libro_count
  FROM libri
  WHERE id_libro = p_id_libro;

  IF libro_count = 0 THEN
    SET p_esito = 'ERRORE: Libro non trovato';
    ROLLBACK;

  ELSE
    -- Legge info libro e verifica stato catalogo
    SELECT titolo, autore, fuori_catalogo
    INTO v_titolo, v_autore, v_fuori_catalogo
    FROM libri
    WHERE id_libro = p_id_libro;

    IF v_fuori_catalogo = FALSE THEN
      SET p_esito = CONCAT('ERRORE: "', v_titolo, '" di "', v_autore, '" è già in catalogo');
      ROLLBACK;

    ELSE
      -- Aggiorna il libro: il trigger riattiverà le copie ritirate
      UPDATE libri
      SET fuori_catalogo = FALSE
      WHERE id_libro = p_id_libro;

      -- Conta quante copie risultano disponibili dopo l'azione del trigger
      SELECT COUNT(*)
      INTO v_copie_attivate
      FROM copie_libri
      WHERE id_libro = p_id_libro AND stato = 'disponibile';

      SET p_esito = CONCAT('OK: "', v_titolo, '" di "', v_autore, '" rimesso in catalogo. Copie disponibili: ', v_copie_attivate);

      COMMIT;

    END IF;
  END IF;

END$$
DELIMITER ;



-- 3.14 Mettere una copia in manutenzione
DROP PROCEDURE IF EXISTS metteCopiaInManutenzione;

DELIMITER $$

CREATE PROCEDURE metteCopiaInManutenzione(IN p_id_copia INT, OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_titolo      VARCHAR(200);
  DECLARE v_autore      VARCHAR(200);
  DECLARE v_stato_copia VARCHAR(20);
  DECLARE copia_count   INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile mettere la copia in manutenzione';
  END;

  START TRANSACTION;

  -- Verifica esistenza della copia
  SELECT COUNT(*)
  INTO copia_count
  FROM copie_libri
  WHERE id_copia = p_id_copia;

  IF copia_count = 0 THEN
    SET p_esito = 'ERRORE: Copia non trovata';
    ROLLBACK;

  ELSE
    -- Legge lo stato della copia e le info del libro associato
    SELECT c.stato, l.titolo, l.autore
    INTO v_stato_copia, v_titolo, v_autore
    FROM copie_libri c
    JOIN libri l
    ON l.id_libro = c.id_libro
    WHERE c.id_copia = p_id_copia;

    IF v_stato_copia = 'in_prestito' THEN
      SET p_esito = CONCAT('ERRORE: Copia in prestito (', v_titolo, ' di ', v_autore, ')');
      ROLLBACK;

    ELSEIF v_stato_copia = 'perso' THEN
      SET p_esito = CONCAT('ERRORE: Copia persa (', v_titolo, ' di ', v_autore, ')');
      ROLLBACK;

    ELSEIF v_stato_copia = 'ritirato' THEN
      SET p_esito = CONCAT('ERRORE: Copia ritirata (', v_titolo, ' di ', v_autore, ')');
      ROLLBACK;

    ELSEIF v_stato_copia = 'manutenzione' THEN
      SET p_esito = CONCAT('ERRORE: Copia già in manutenzione (', v_titolo, ' di ', v_autore, ')');
      ROLLBACK;

    ELSE
      UPDATE copie_libri
      SET stato = 'manutenzione'
      WHERE id_copia = p_id_copia;

      SET p_esito = CONCAT('OK: Copia in manutenzione (', v_titolo, ' di ', v_autore, ')');
      COMMIT;

    END IF;
  END IF;

END$$
DELIMITER ;




-- 3.15 Mettere una copia in stato di "perso" (solo se "era" disponibile oppure in manutenzione)
DROP PROCEDURE IF EXISTS metteCopiaPersa;

DELIMITER $$

CREATE PROCEDURE metteCopiaPersa(IN p_id_copia INT, OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_titolo      VARCHAR(200);
  DECLARE v_autore      VARCHAR(200);
  DECLARE v_stato_copia VARCHAR(20);
  DECLARE copia_count   INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile impostare la copia come "perso"';
  END;

  START TRANSACTION;

  -- Verifica esistenza della copia
  SELECT COUNT(*)
  INTO copia_count
  FROM copie_libri
  WHERE id_copia = p_id_copia;

  IF copia_count = 0 THEN
    SET p_esito = 'ERRORE: Copia non trovata';
    ROLLBACK;

  ELSE
    -- Legge lo stato della copia e le info del libro associato
    SELECT c.stato, l.titolo, l.autore
    INTO v_stato_copia, v_titolo, v_autore
    FROM copie_libri c
    JOIN libri l
    ON l.id_libro = c.id_libro
    WHERE c.id_copia = p_id_copia;

    IF v_stato_copia = 'in_prestito' THEN
      SET p_esito = CONCAT('ERRORE: Copia in prestito (', v_titolo, ' di ', v_autore, ')');
      ROLLBACK;

    ELSEIF v_stato_copia = 'perso' THEN
      SET p_esito = CONCAT('ERRORE: Copia già in stato "perso" (', v_titolo, ' di ', v_autore, ')');
      ROLLBACK;

    ELSEIF v_stato_copia = 'ritirato' THEN
      SET p_esito = CONCAT('ERRORE: Copia ritirata (', v_titolo, ' di ', v_autore, ')');
      ROLLBACK;

    ELSE
      UPDATE copie_libri
      SET stato = 'perso'
      WHERE id_copia = p_id_copia;

      SET p_esito = CONCAT('OK: Copia impostata come "perso" (', v_titolo, ' di ', v_autore, ')');
      COMMIT;

    END IF;
  END IF;

END$$
DELIMITER ;



-- 3.16 Rimette una copia che era in manutenzione a disponibile
DROP PROCEDURE IF EXISTS rimetteCopiaMDisponibile;

DELIMITER $$

CREATE PROCEDURE rimetteCopiaMDisponibile(IN p_id_copia INT, OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_titolo      VARCHAR(200);
  DECLARE v_autore      VARCHAR(200);
  DECLARE v_stato_copia VARCHAR(20);
  DECLARE copia_count   INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile rimettere la copia disponibile';
  END;

  START TRANSACTION;

  -- Verifica esistenza della copia
  SELECT COUNT(*)
  INTO copia_count
  FROM copie_libri
  WHERE id_copia = p_id_copia;

  IF copia_count = 0 THEN
    SET p_esito = 'ERRORE: Copia non trovata';
    ROLLBACK;

  ELSE
    -- Legge stato copia e info libro associato
    SELECT c.stato, l.titolo, l.autore
    INTO v_stato_copia, v_titolo, v_autore
    FROM copie_libri c
    JOIN libri l
    ON l.id_libro = c.id_libro
    WHERE c.id_copia = p_id_copia;

    IF v_stato_copia = 'in_prestito' THEN
      SET p_esito = CONCAT('ERRORE: Copia in prestito (', v_titolo, ' di ', v_autore, ')');
      ROLLBACK;

    ELSEIF v_stato_copia = 'perso' THEN
      SET p_esito = CONCAT('ERRORE: Copia persa (', v_titolo, ' di ', v_autore, ')');
      ROLLBACK;

    ELSEIF v_stato_copia = 'ritirato' THEN
      SET p_esito = CONCAT('ERRORE: Copia ritirata (', v_titolo, ' di ', v_autore, ')');
      ROLLBACK;

    ELSEIF v_stato_copia = 'disponibile' THEN
      SET p_esito = CONCAT('ERRORE: Copia già disponibile (', v_titolo, ' di ', v_autore, ')');
      ROLLBACK;

    ELSE
      UPDATE copie_libri
      SET stato = 'disponibile'
      WHERE id_copia = p_id_copia;

      SET p_esito = CONCAT('OK: Copia rimessa disponibile (', v_titolo, ' di ', v_autore, ')');
      COMMIT;

    END IF;
  END IF;

END$$
DELIMITER ;




-- Copie che necessitano attenzione
-- 3.17 Visualizza le copie filtrate per stato (con dati copia + dati libro)
DROP PROCEDURE IF EXISTS copiePerStato;

DELIMITER $$

CREATE PROCEDURE copiePerStato(IN p_stato VARCHAR(20), OUT msg VARCHAR(50))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SET msg = 'Errore SQL: impossibile visualizza le copie filtrate per stato';
  END;

  -- Validazione stato
  IF p_stato NOT IN ('disponibile','in_prestito','manutenzione','ritirato','perso') THEN
    SET msg = 'ERRORE: Stato non valido';
  
  ELSE
    
    SELECT
        l.id_libro,
        l.titolo,
        l.autore,
        l.genere,
        l.isbn,
        c.id_copia,
        c.codice_inventario,
        c.stato
    FROM copie_libri c
    JOIN libri l
    ON l.id_libro = c.id_libro
    WHERE c.stato = p_stato
    ORDER BY l.titolo, c.codice_inventario;

    SET msg = 'Query eseguita';

  END IF;

END$$
DELIMITER ;



-- 3.18 Ricerca libri per titolo/autore/genere/isbn e mostra quante copie disponibili ci sono
DROP PROCEDURE IF EXISTS ricercaLibri;

DELIMITER $$

CREATE PROCEDURE ricercaLibri(IN  p_tipo_ricerca    VARCHAR(20),
                              IN  p_termine_ricerca VARCHAR(200),
                              OUT msg               VARCHAR(50))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    SET msg = 'Errore SQL: impossibile ricercare libri tramite filtro sui campi che lo caratterizzano';
  END;

  -- Validazione input
  IF p_tipo_ricerca IS NULL OR TRIM(p_tipo_ricerca) = '' THEN
    SET msg = 'ERRORE: Tipo di ricerca non valido';

  ELSEIF p_tipo_ricerca NOT IN ('titolo','autore','genere','isbn') THEN
    SET msg = 'ERRORE: Tipo di ricerca non supportato';

  ELSEIF p_termine_ricerca IS NULL OR TRIM(p_termine_ricerca) = '' THEN
    SET msg = 'ERRORE: Termine di ricerca non valido';

  ELSE
    -- Query unificata con campo copertina
    SELECT L.id_libro,
           MAX(L.titolo) AS titolo,
           MAX(L.autore) AS autore,
           MAX(L.genere) AS genere,
           MAX(L.isbn)   AS isbn,
           MAX(CASE
                WHEN L.copertina IS NOT NULL THEN
                    1
                ELSE
                    0
               END) AS ha_copertina,
           COUNT(C.id_copia) AS "Copie Attualmente Disponibili"

    FROM libri L
    JOIN copie_libri C
    ON L.id_libro = C.id_libro
    WHERE L.fuori_catalogo = FALSE
      AND C.stato = 'disponibile'
      AND (
            (p_tipo_ricerca = 'titolo' AND L.titolo LIKE CONCAT('%', p_termine_ricerca, '%'))
         OR (p_tipo_ricerca = 'autore' AND L.autore LIKE CONCAT('%', p_termine_ricerca, '%'))
         OR (p_tipo_ricerca = 'genere' AND L.genere LIKE CONCAT('%', p_termine_ricerca, '%'))
         OR (p_tipo_ricerca = 'isbn'   AND L.isbn   LIKE CONCAT('%', p_termine_ricerca, '%'))
          )
    GROUP BY L.id_libro
    ORDER BY
      CASE p_tipo_ricerca
        WHEN 'titolo' THEN MAX(L.titolo)
        WHEN 'autore' THEN MAX(L.autore)
        WHEN 'genere' THEN MAX(L.genere)
        WHEN 'isbn'   THEN MAX(L.isbn)
      END;

    SET msg = 'Query eseguita';

  END IF;

END$$
DELIMITER ;



-- 3.19 Modifica dati utente (nome, cognome, email)
DROP PROCEDURE IF EXISTS modificaUtente;

DELIMITER $$

CREATE PROCEDURE modificaUtente(IN p_id_utente INT,
                                IN p_nome      VARCHAR(50),
                                IN p_cognome   VARCHAR(50),
                                IN p_email     VARCHAR(100),
                                OUT p_esito    VARCHAR(200))
BEGIN
  DECLARE v_utente_count INT;
  DECLARE v_email_exists INT;
  DECLARE v_email_attuale VARCHAR(100);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile modificare l''utente';
  END;


  START TRANSACTION;

  -- Verifica esistenza utente
  SELECT COUNT(*)
  INTO v_utente_count
  FROM utenti
  WHERE id_utente = p_id_utente;

  IF v_utente_count = 0 THEN
    SET p_esito = 'ERRORE: Utente non trovato';
    ROLLBACK;

  ELSE
    -- Recupera email attuale
    SELECT email
    INTO v_email_attuale
    FROM utenti
    WHERE id_utente = p_id_utente;

    -- Verifica se la nuova email è già usata da un altro utente
    IF p_email != v_email_attuale THEN
      SELECT COUNT(*)
      INTO v_email_exists
      FROM utenti
      WHERE email = p_email
        AND id_utente != p_id_utente;

      IF v_email_exists > 0 THEN
        SET p_esito = 'ERRORE: Email già utilizzata da un altro utente';
        ROLLBACK;

      ELSE
        -- Aggiorna dati utente
        UPDATE utenti
        SET nome = p_nome,
            cognome = p_cognome,
            email = p_email
        WHERE id_utente = p_id_utente;

        SET p_esito = CONCAT('OK: Utente modificato (', p_nome, ' ', p_cognome, ')');
        COMMIT;

      END IF;

    ELSE
      -- Email non cambiata, aggiorna solo nome e cognome
      UPDATE utenti
      SET nome = p_nome,
          cognome = p_cognome
      WHERE id_utente = p_id_utente;

      SET p_esito = CONCAT('OK: Utente modificato (', p_nome, ' ', p_cognome, ')');
      COMMIT;

    END IF;
  END IF;

END$$
DELIMITER ;



-- 3.20 Modifica ruolo utente (solo admin può cambiare ruoli)
-- con controllo che blocca l'operazione se l'utente target è un admin.
DROP PROCEDURE IF EXISTS modificaRuoloUtente;

DELIMITER $$

CREATE PROCEDURE modificaRuoloUtente(IN p_id_utente INT,
                                     IN p_nuovo_ruolo VARCHAR(20),
                                     OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_utente_count INT;
  DECLARE v_ruolo_attuale VARCHAR(20);
  DECLARE v_nome VARCHAR(50);
  DECLARE v_cognome VARCHAR(50);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile modificare il ruolo';
  END;


  START TRANSACTION;
  

  -- Verifica esistenza utente
  SELECT COUNT(*)
  INTO v_utente_count
  FROM utenti
  WHERE id_utente = p_id_utente;

  IF v_utente_count = 0 THEN
    SET p_esito = 'ERRORE: Utente non trovato';
    ROLLBACK;

  ELSE

    -- Validazione: non si può promuovere nessuno ad admin
    IF p_nuovo_ruolo = 'admin' THEN
      SET p_esito = 'ERRORE: Non puoi assegnare il ruolo di admin';
      ROLLBACK;

    -- Validazione: solo 'sub_admin' e 'user' sono ruoli assegnabili
    ELSEIF p_nuovo_ruolo NOT IN ('sub_admin', 'user') THEN
      SET p_esito = CONCAT('ERRORE: Ruolo "', p_nuovo_ruolo, '" non valido. Valori accettati: sub_admin, user');
      ROLLBACK;

    ELSE
      -- Recupera dati attuali
      SELECT ruolo, nome, cognome
      INTO v_ruolo_attuale, v_nome, v_cognome
      FROM utenti
      WHERE id_utente = p_id_utente;


      -- Il ruolo di un admin non può essere modificato
      IF v_ruolo_attuale = 'admin' THEN
        SET p_esito = 'ERRORE: Non puoi modificare il ruolo di un admin';
        ROLLBACK;

      -- Verifica se il ruolo è effettivamente diverso
      ELSEIF v_ruolo_attuale = p_nuovo_ruolo THEN
        SET p_esito = CONCAT('ERRORE: Utente ha già il ruolo "', p_nuovo_ruolo, '"');
        ROLLBACK;

      ELSE
        -- Aggiorna ruolo
        UPDATE utenti
        SET ruolo = p_nuovo_ruolo
        WHERE id_utente = p_id_utente;

        SET p_esito = CONCAT('OK: Ruolo cambiato da "', v_ruolo_attuale, '" a "', p_nuovo_ruolo, '" per ', v_nome, ' ', v_cognome);
        COMMIT;

      END IF;

    END IF;
  END IF;

END$$
DELIMITER ;



-- 3.21 Modifica password utente (per cambio password)
DROP PROCEDURE IF EXISTS modificaPasswordUtente;

DELIMITER $$

CREATE PROCEDURE modificaPasswordUtente(IN p_id_utente INT,
                                        IN p_nuova_password_hash VARCHAR(255),
                                        OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_utente_count INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile modificare la password';
  END;


  START TRANSACTION;

  -- Verifica esistenza utente
  SELECT COUNT(*)
  INTO v_utente_count
  FROM utenti
  WHERE id_utente = p_id_utente;

  IF v_utente_count = 0 THEN
    SET p_esito = 'ERRORE: Utente non trovato';
    ROLLBACK;

  ELSEIF p_nuova_password_hash IS NULL OR LENGTH(p_nuova_password_hash) < 50 THEN
    SET p_esito = 'ERRORE: Password hash non valido';
    ROLLBACK;

  ELSE
    -- Aggiorna password
    UPDATE utenti
    SET pass = p_nuova_password_hash
    WHERE id_utente = p_id_utente;

    SET p_esito = 'OK: Password modificata con successo';
    COMMIT;

  END IF;

END$$
DELIMITER ;



-- 3.22 Elimina/Annulla prestito (solo admin/sub_admin - pulizia errori da parte di chi ha fatto
-- il prestito oppure annullare un prestito di un utente)
DROP PROCEDURE IF EXISTS eliminaPrestito;

DELIMITER $$

CREATE PROCEDURE eliminaPrestito(IN p_id_prestito INT, OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_prestito_count INT;
  DECLARE v_data_restituzione DATETIME;
  DECLARE v_id_copia INT;
  DECLARE v_titolo VARCHAR(200);
  DECLARE v_autore VARCHAR(200);
  DECLARE v_fuori_catalogo BOOLEAN;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile eliminare il prestito';
  END;


  START TRANSACTION;

  -- Verifica esistenza prestito
  SELECT COUNT(*)
  INTO v_prestito_count
  FROM prestiti
  WHERE id_prestito = p_id_prestito;

  IF v_prestito_count = 0 THEN
    SET p_esito = 'ERRORE: Prestito non trovato';
    ROLLBACK;

  ELSE
    -- Recupera dati prestito
    SELECT p.data_restituzione, p.id_copia, l.titolo, l.autore, l.fuori_catalogo
    INTO v_data_restituzione, v_id_copia, v_titolo, v_autore, v_fuori_catalogo
    FROM prestiti p
    JOIN copie_libri c
    ON p.id_copia = c.id_copia
    JOIN libri l
    ON c.id_libro = l.id_libro
    WHERE p.id_prestito = p_id_prestito;

    -- Se il prestito era ancora attivo, ripristina lo stato della copia
    -- con lo stesso criterio del trigger au_prestiti_restituzione_set_stato:
    --   1 fuori catalogo  → 'ritirato'
    --   2 in catalogo     → 'disponibile'
    IF v_data_restituzione IS NULL THEN
      UPDATE copie_libri
      SET stato = CASE
                    WHEN v_fuori_catalogo = 1 THEN 'ritirato'
                    ELSE 'disponibile'
                  END
      WHERE id_copia = v_id_copia AND stato = 'in_prestito';

    END IF;

    -- Elimina prestito dallo storico
    DELETE FROM prestiti
    WHERE id_prestito = p_id_prestito;

    SET p_esito = CONCAT('OK: Prestito eliminato definitivamente (', v_titolo, ' di ', v_autore, ')');
    COMMIT;

  END IF;

END$$
DELIMITER ;



-- 3.23 Upload Copertina
DROP PROCEDURE IF EXISTS uploadCopertina;

DELIMITER $$

CREATE PROCEDURE uploadCopertina(IN p_id_libro INT,
                                 IN p_copertina MEDIUMBLOB,
                                 IN p_mime_type VARCHAR(50),
                                 OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_libro_count INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile caricare la copertina';
  END;

  START TRANSACTION;

  -- Verifica esistenza libro
  SELECT COUNT(*)
  INTO v_libro_count
  FROM libri
  WHERE id_libro = p_id_libro;

  IF v_libro_count = 0 THEN
    SET p_esito = 'ERRORE: Libro non trovato';
    ROLLBACK;

  ELSEIF p_copertina IS NULL THEN
    SET p_esito = 'ERRORE: Immagine non valida';
    ROLLBACK;

  ELSE
    -- Carica copertina
    UPDATE libri
    SET copertina = p_copertina,
        copertina_mime_type = p_mime_type
    WHERE id_libro = p_id_libro;
      
    SET p_esito = 'OK: Copertina caricata con successo';
    COMMIT;

  END IF;

END$$
DELIMITER ;



-- 3.24 Rimuovi Copertina
DROP PROCEDURE IF EXISTS rimuoviCopertina;

DELIMITER $$

CREATE PROCEDURE rimuoviCopertina(IN p_id_libro INT,
                                  OUT p_esito VARCHAR(200))
BEGIN
  DECLARE v_libro_count INT;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    SET p_esito = 'ERRORE SQL: Impossibile rimuovere la copertina';
  END;

  START TRANSACTION;

  -- Verifica esistenza libro
  SELECT COUNT(*)
  INTO v_libro_count
  FROM libri
  WHERE id_libro = p_id_libro;

  IF v_libro_count = 0 THEN
    SET p_esito = 'ERRORE: Libro non trovato';
    ROLLBACK;

  ELSE
    -- Rimuovi copertina
    UPDATE libri
    SET copertina = NULL,
        copertina_mime_type = NULL
    WHERE id_libro = p_id_libro
      AND (copertina IS NOT NULL OR copertina_mime_type IS NOT NULL);

    SET p_esito = 'OK: Copertina rimossa';
    COMMIT;

  END IF;

END$$
DELIMITER ;


