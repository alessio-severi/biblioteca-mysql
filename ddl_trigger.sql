-- Copyright (C) 2026 Alessio Severi
-- Licensed under CC BY-NC-ND 4.0: https://creativecommons.org/licenses/by-nc-nd/4.0/

-- PROGETTO DATABASE BIBLIOTECA ---



-- Sezione MySQL

-- 2. Creazione dei trigger (DDL)

-- TRIGGER 1
-- Quando un libro viene messo fuori catalogo (0 -> 1),
-- si ritira subito solo le copie attualmente disponibili.
DELIMITER $$

CREATE TRIGGER au_libri_fuori_catalogo
AFTER UPDATE ON libri
FOR EACH ROW
BEGIN
  IF OLD.fuori_catalogo = 0 AND NEW.fuori_catalogo = 1 THEN
    UPDATE copie_libri
    SET stato = 'ritirato'
    WHERE id_libro =  NEW.id_libro       -- oppure OLD.id_libro in generale
      AND stato = 'disponibile';
  END IF;

END$$
DELIMITER ;



-- TRIGGER 2
-- Quando nasce un prestito, la copia passa in stato "in_prestito".
DELIMITER $$

CREATE TRIGGER ai_prestiti_set_in_prestito
AFTER INSERT ON prestiti
FOR EACH ROW
BEGIN
  UPDATE copie_libri
  SET stato = 'in_prestito'
  WHERE id_copia = NEW.id_copia;

END$$
DELIMITER ;



-- TRIGGER 3
-- Quando viene registrata la restituzione (NULL -> data),
-- se il titolo è fuori catalogo la copia diventa "ritirato",
-- altrimenti torna "disponibile".
DELIMITER $$

CREATE TRIGGER au_prestiti_restituzione_set_stato
AFTER UPDATE ON prestiti
FOR EACH ROW
BEGIN
  IF OLD.data_restituzione IS NULL AND NEW.data_restituzione IS NOT NULL THEN

    UPDATE copie_libri c
    JOIN libri l ON l.id_libro = c.id_libro
    SET c.stato =
    CASE
      WHEN l.fuori_catalogo = 1 THEN 'ritirato'
      ELSE 'disponibile'
    END
    WHERE c.id_copia = NEW.id_copia;      -- oppure OLD.id_libro in generale

  END IF;

END$$
DELIMITER ;


-- TRIGGER 4
-- quando un libro torna in catalogo, riattiva le copie "ritirate"
DELIMITER $$

CREATE TRIGGER au_libri_in_catalogo
AFTER UPDATE ON libri
FOR EACH ROW
BEGIN
  IF OLD.fuori_catalogo = 1 AND NEW.fuori_catalogo = 0 THEN

    UPDATE copie_libri
    SET stato = 'disponibile'
    WHERE id_libro = NEW.id_libro AND stato = 'ritirato';

  END IF;

END$$
DELIMITER ;
 

