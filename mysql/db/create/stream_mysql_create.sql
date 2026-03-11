-- ============================================================================
-- RTMP Proxy Server - Unified Database Schema
-- ============================================================================
-- Last updated: 2026-03-10
-- ============================================================================

-- Drop existing tables if they exist (for clean install)
DROP TABLE IF EXISTS `streams`;
DROP TABLE IF EXISTS `broadcast_channels`;
DROP TABLE IF EXISTS `broadcasts`;
DROP TABLE IF EXISTS `channels`;
DROP TABLE IF EXISTS `games`;
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
-- Table: channels (platform destinations - reusable)
-- ============================================================================
CREATE TABLE `channels` (
    `id` bigint NOT NULL AUTO_INCREMENT,
    `name` varchar(255) NOT NULL UNIQUE,
    `platform` ENUM('twitch', 'instagram', 'facebook', 'youtube') NOT NULL,
    `stream_url` varchar(255) NOT NULL,
    `stream_key` varchar(255),
    `display_name` varchar(255),
    `access_token` varchar(255),
    `client_id` varchar(255),
    `refresh_token` varchar(255),
    PRIMARY KEY (`id`)
);

-- ============================================================================
-- Table: broadcasts (RTMP ingress points with ports)
-- ============================================================================
CREATE TABLE `broadcasts` (
    `id` bigint NOT NULL AUTO_INCREMENT,
    `name` varchar(255) NOT NULL UNIQUE,
    `display_name` varchar(255),
    `port` int NOT NULL UNIQUE,
    PRIMARY KEY (`id`)
);

-- ============================================================================
-- Table: broadcast_channels (many-to-many relationship)
-- ============================================================================
CREATE TABLE `broadcast_channels` (
    `id` bigint NOT NULL AUTO_INCREMENT,
    `broadcast_id` bigint NOT NULL,
    `channel_id` bigint NOT NULL,
    `enabled` BOOLEAN NOT NULL DEFAULT TRUE,
    `priority` int NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `unique_broadcast_channel` (`broadcast_id`, `channel_id`),
    FOREIGN KEY (`broadcast_id`) REFERENCES `broadcasts`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`channel_id`) REFERENCES `channels`(`id`) ON DELETE CASCADE
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
    `broadcast_id` bigint NOT NULL,
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
ALTER TABLE `streams` ADD CONSTRAINT `streams_fk1` FOREIGN KEY (`broadcast_id`) REFERENCES `broadcasts`(`id`);
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
-- Default Data: Example Channels
-- ============================================================================
INSERT INTO channels (name, platform, stream_url, stream_key, display_name, access_token, client_id, refresh_token)
VALUES ('example-twitch', 'twitch', 'rtmp://live.twitch.tv/app', 'stream_key', 'Example Twitch Channel',
        'access_token', 'client_id', 'refresh_token');

-- ============================================================================
-- Default Data: Example Broadcasts
-- ============================================================================
-- Main broadcast (port 48001)
INSERT INTO broadcasts (name, display_name, port)
VALUES ('example-broadcast', 'Example Broadcast', 48001);

-- Link example channel to example broadcast
INSERT INTO broadcast_channels (broadcast_id, channel_id, enabled, priority)
VALUES (1, 1, true, 0);

-- Proxy broadcasts (port 48101-48110)
INSERT INTO broadcasts (name, display_name, port)
VALUES ('example-broadcast-proxy', 'Example Proxy Broadcast', 48101);

INSERT INTO broadcasts (name, display_name, port)
VALUES ('only1-proxy', 'Internal Proxy 1', 48105);

INSERT INTO broadcasts (name, display_name, port)
VALUES ('only2-proxy', 'Internal Proxy 2', 48106);

INSERT INTO broadcasts (name, display_name, port)
VALUES ('only3-proxy', 'Internal Proxy 3', 48107);

INSERT INTO broadcasts (name, display_name, port)
VALUES ('only4-proxy', 'Internal Proxy 4', 48108);

INSERT INTO broadcasts (name, display_name, port)
VALUES ('only5-proxy', 'Internal Proxy 5', 48109);

INSERT INTO broadcasts (name, display_name, port)
VALUES ('only6-proxy', 'Internal Proxy 6', 48110);

-- ============================================================================
-- Default Data: Games
-- ============================================================================
INSERT INTO games (name, display_name, abbreviation, delay)
VALUES ('example-game', 'Example Game', 'EG', '480');

-- ============================================================================
-- End of Schema
-- ============================================================================
