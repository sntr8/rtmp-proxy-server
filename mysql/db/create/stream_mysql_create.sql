-- ============================================================================
-- RTMP Proxy Server - Unified Database Schema
-- ============================================================================
-- Last updated: 2026-03-10
-- ============================================================================

-- Drop existing tables if they exist (for clean install)
DROP TABLE IF EXISTS `streams`;
DROP TABLE IF EXISTS `games`;
DROP TABLE IF EXISTS `channels`;
DROP TABLE IF EXISTS `casters`;

-- ============================================================================
-- Table: casters
-- ============================================================================
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

-- ============================================================================
-- Table: channels
-- ============================================================================
CREATE TABLE `channels` (
    `id` bigint NOT NULL AUTO_INCREMENT,
    `name` varchar(255) NOT NULL UNIQUE,
    `platform` ENUM('twitch', 'instagram', 'facebook', 'youtube') NOT NULL DEFAULT 'twitch',
    `display_name` varchar(255),
    `access_token` varchar(255),
    `client_id` varchar(255),
    `refresh_token` varchar(255),
    `port` int NOT NULL,
    `url` varchar(255),
    PRIMARY KEY (`id`)
);

-- ============================================================================
-- Table: games
-- ============================================================================
CREATE TABLE `games` (
    `id` bigint NOT NULL AUTO_INCREMENT UNIQUE,
    `name` varchar(255) NOT NULL UNIQUE,
    `display_name` varchar(255) NOT NULL,
    `abbreviation` varchar(255) NOT NULL,
    `delay` int NOT NULL,
    PRIMARY KEY (`id`)
);

-- ============================================================================
-- Table: streams
-- ============================================================================
CREATE TABLE `streams` (
    `id` bigint NOT NULL AUTO_INCREMENT,
    `caster_id` bigint NOT NULL,
    `cocaster_id` varchar(255),
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

-- ============================================================================
-- Foreign Keys
-- ============================================================================
ALTER TABLE `streams` ADD CONSTRAINT `streams_fk0` FOREIGN KEY (`caster_id`) REFERENCES `casters`(`id`);
ALTER TABLE `streams` ADD CONSTRAINT `streams_fk1` FOREIGN KEY (`channel_id`) REFERENCES `channels`(`id`);
ALTER TABLE `streams` ADD CONSTRAINT `streams_fk2` FOREIGN KEY (`game_id`) REFERENCES `games`(`id`);

-- ============================================================================
-- Constraints
-- ============================================================================
ALTER TABLE `streams` ADD CONSTRAINT `streams_et_chk` CHECK (`end_time` > `start_time`);

-- ============================================================================
-- Default Data: Internal Casters
-- ============================================================================
INSERT INTO casters (nick, stream_key, active, internal, date_added)
VALUES ('internal_technical_user', 'streamkey', true, true, NOW());

INSERT INTO casters (nick, stream_key, active, internal, date_added)
VALUES ('vlc_viewer', 'streamkey', true, true, NOW());

INSERT INTO casters (nick, stream_key, discord_id, active, internal, date_added)
VALUES ('example-caster', 'example-key', Null, false, false, NOW());

-- ============================================================================
-- Default Data: Twitch Channels
-- ============================================================================
-- Main streaming channels (port 48001-48010)
INSERT INTO channels (name, display_name, access_token, client_id, refresh_token, access_token_expires, port, url)
VALUES ('example-channel', 'Example Channel', 'access_token', 'refresh_token', 'refresh_token',
        STR_TO_DATE('2001-01-01T00:00', '%Y-%m-%dT%H:%i'), '48001', 'https://www.twitch.tv/example-channel');

-- ============================================================================
-- Default Data: Proxy Channels
-- ============================================================================
-- Channel-specific proxy channels (port 48101-48104)
INSERT INTO channels (name, display_name, port)
VALUES ('example-channel-proxy', 'Internal Proxy Channel', '48101');

-- Generic proxy channels (port 48105-48110)
INSERT INTO channels (name, display_name, port)
VALUES ('only1-proxy', 'Internal Proxy Channel 1', '48105');

INSERT INTO channels (name, display_name, port)
VALUES ('only2-proxy', 'Internal Proxy Channel 2', '48106');

INSERT INTO channels (name, display_name, port)
VALUES ('only3-proxy', 'Internal Proxy Channel 3', '48107');

INSERT INTO channels (name, display_name, port)
VALUES ('only4-proxy', 'Internal Proxy Channel 4', '48108');

INSERT INTO channels (name, display_name, port)
VALUES ('only5-proxy', 'Internal Proxy Channel 5', '48109');

INSERT INTO channels (name, display_name, port)
VALUES ('only6-proxy', 'Internal Proxy Channel 6', '48110');

-- ============================================================================
-- Default Data: Games
-- ============================================================================
INSERT INTO games (name, display_name, abbreviation, delay)
VALUES ('example-game', 'Example Game', 'EG', '480');

-- ============================================================================
-- End of Schema
-- ============================================================================
