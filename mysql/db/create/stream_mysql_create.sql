CREATE TABLE `casters` (
    `id` bigint NOT NULL AUTO_INCREMENT,
    `nick` varchar(255) NOT NULL,
    `stream_key` varchar(255) NOT NULL,
    `discord_id` varchar(255),
    `active` BOOLEAN NOT NULL,
    `internal` BOOLEAN NOT NULL,
    `date_added` DATETIME NOT NULL,
    PRIMARY KEY (`id`)
);

CREATE TABLE `channels` (
    `id` bigint NOT NULL AUTO_INCREMENT,
    `name` varchar(255) NOT NULL UNIQUE,
    `display_name` varchar(255),
    `access_token` varchar(255),
    `client_id` varchar(255),
    `refresh_token` varchar(255),
    `access_token_expires` DATETIME,
    `port` int NOT NULL,
    `url` varchar(255),
    PRIMARY KEY (`id`)
);

CREATE TABLE `games` (
    `id` bigint NOT NULL AUTO_INCREMENT UNIQUE,
    `name` varchar(255) NOT NULL UNIQUE,
    `display_name` varchar(255) NOT NULL,
    `abbreviation` varchar(255) NOT NULL,
    `delay` int NOT NULL,
    PRIMARY KEY (`id`)
);

CREATE TABLE `streams` (
    `id` bigint NOT NULL AUTO_INCREMENT,
    `caster_id` bigint NOT NULL,
    `channel_id` bigint NOT NULL,
    `game_id` bigint,
    `title` varchar(255),
    `description` TEXT,
    `live` BOOLEAN NOT NULL,
    `skip` BOOLEAN NOT NULL,
    `start_time` DATETIME NOT NULL,
    `end_time` DATETIME NOT NULL,
    PRIMARY KEY (`id`)
);

ALTER TABLE `streams` ADD CONSTRAINT `streams_fk0` FOREIGN KEY (`caster_id`) REFERENCES `casters`(`id`);

ALTER TABLE `streams` ADD CONSTRAINT `streams_fk1` FOREIGN KEY (`channel_id`) REFERENCES `channels`(`id`);

ALTER TABLE `streams` ADD CONSTRAINT `streams_fk2` FOREIGN KEY (`game_id`) REFERENCES `games`(`id`);

ALTER TABLE `streams` ADD CONSTRAINT `streams_et_chk` CHECK (`end_time` > `start_time`);

INSERT INTO casters (nick, stream_key, active, internal, date_added) VALUES ('internal_technical_user', 'c940cdf1ce11b0a9', true, true, NOW());
INSERT INTO casters (nick, stream_key, active, internal, date_added) VALUES ('vlc_viewer', 'spectator', true, true, NOW());
INSERT INTO channels (name, display_name, port) VALUES ('proxy-only', 'Internal Proxy Channel', '48005');
INSERT INTO channels (name, display_name, port) VALUES ('proxy-only2', 'Internal Proxy Channel 2', '48006');
INSERT INTO games (name, display_name, abbreviation, delay) VALUES ('pubg', 'PlayerUnknown''s Battlegrounds', 'PUBG', '480');
INSERT INTO games (name, display_name, abbreviation, delay) VALUES ('csgo', 'Counter-Strike: Global Offensive', 'CS:GO', '120');
INSERT INTO games (name, display_name, abbreviation, delay) VALUES ('dota2', 'DOTA 2', 'DOTA2', '300');
INSERT INTO games (name, display_name, abbreviation, delay) VALUES ('rl', 'Rocket League', 'RL', '0');
INSERT INTO games (name, display_name, abbreviation, delay) VALUES ('nhl', 'NHL 20', 'NHL', '0');
INSERT INTO games (name, display_name, abbreviation, delay) VALUES ('apex', 'Apex Legends', 'Apex', '300');
