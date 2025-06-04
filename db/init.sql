-- Base de données : `iot_db`

CREATE DATABASE IF NOT EXISTS iot_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE iot_db;

-- Table `identifiant`

CREATE TABLE IF NOT EXISTS `identifiant` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(255) NOT NULL,
  `password` VARCHAR(255) NOT NULL,
  `est_admin` TINYINT(1) DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Données initiales pour `identifiant`

INSERT INTO `identifiant` (`id`, `username`, `password`, `est_admin`) VALUES
(1, 'admin', 'd033e22ae348aeb5660fc2140aec35850c4da997', 0),
(2, 'test', 'a94a8fe5ccb19ba61c4c0873d391e987982fbbd3', 0);

-- Table `mesure`

CREATE TABLE IF NOT EXISTS `mesure` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `temperature` FLOAT NOT NULL,
  `humidite` FLOAT NOT NULL,
  `historique` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Données initiales pour `mesure`

INSERT INTO `mesure` (`id`, `temperature`, `humidite`, `historique`) VALUES
(1, 20.7, 19.4, '2025-01-24 17:58:12'),
(2, 22.4, 19.1, '2025-01-24 17:58:14'),
(3, 19.8, 18.5, '2025-01-24 17:58:14'),
(4, 24.6, 21.3, '2025-01-24 17:58:27'),
(5, 20.9, 19.2, '2025-01-24 17:58:28'),
(6, 21.6, 18.2, '2025-01-24 17:58:28');
