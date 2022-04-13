ALTER TABLE channels ADD UNIQUE (name);
ALTER TABLE channels ADD `access_token` varchar(255) NOT NULL AFTER `display_name`;
ALTER TABLE channels ADD `client_id` varchar(255) NOT NULL AFTER `access_token`;
ALTER TABLE channels ADD `refresh_token` varchar(255) NOT NULL AFTER `client_id`;
ALTER TABLE channels ADD `access_token_expires` DATETIME AFTER `refresh_token`;
ALTER TABLE channels DROP `stream_key`;

ALTER TABLE channels MODIFY `access_token_expires` DATETIME NOT NULL;
