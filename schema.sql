-- Tabela para armazenar informações dos usuários de corrida
CREATE TABLE IF NOT EXISTS `race_users` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `citizenid` VARCHAR(50) NOT NULL,
    `racername` VARCHAR(255) NOT NULL,
    `auth` VARCHAR(255) NOT NULL,
    `creator_citizenid` VARCHAR(50) NOT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `ranking` INT(11) NOT NULL DEFAULT 1000,
    `races` INT(11) NOT NULL DEFAULT 0,
    `wins` INT(11) NOT NULL DEFAULT 0,
    `crypto` INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `citizenid_racername` (`citizenid`, `racername`)
);

-- Tabela para armazenar informações sobre as corridas
CREATE TABLE IF NOT EXISTS `races` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(255) NOT NULL,
    `creator_citizenid` VARCHAR(50) NOT NULL,
    `track_id` VARCHAR(255) NOT NULL,
    `laps` INT(11) NOT NULL,
    `vehicle_model` VARCHAR(255) NULL DEFAULT NULL,
    `status` VARCHAR(50) NOT NULL DEFAULT 'pending',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

-- Tabela para armazenar informações sobre as equipes de corrida
CREATE TABLE IF NOT EXISTS `racing_crews` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(255) NOT NULL,
    `owner_citizenid` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `name` (`name`)
);