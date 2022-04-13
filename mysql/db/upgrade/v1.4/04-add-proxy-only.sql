ALTER TABLE channels MODIFY `display_name` varchar(255);
ALTER TABLE channels MODIFY `access_token` varchar(255);
ALTER TABLE channels MODIFY `client_id` varchar(255);
ALTER TABLE channels MODIFY `refresh_token` varchar(255);
ALTER TABLE channels MODIFY `access_token_expires` DATETIME;
ALTER TABLE channels MODIFY `url` varchar(255);
ALTER TABLE streams MODIFY `game_id` bigint;
ALTER TABLE streams MODIFY `title` varchar(255);

INSERT INTO channels (name, display_name, port) VALUES ('proxy-only', 'Internal Proxy Channel', '48005');
