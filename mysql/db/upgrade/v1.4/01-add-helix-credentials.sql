ALTER TABLE channels ADD UNIQUE (name);
ALTER TABLE channels ADD `access_token` varchar(255) NOT NULL AFTER `display_name`;
ALTER TABLE channels ADD `client_id` varchar(255) NOT NULL AFTER `access_token`;
ALTER TABLE channels ADD `refresh_token` varchar(255) NOT NULL AFTER `client_id`;
ALTER TABLE channels ADD `access_token_expires` DATETIME AFTER `refresh_token`;
ALTER TABLE channels DROP `stream_key`;

UPDATE channels SET name = 'kanaliigatv', access_token = 'ypobkzyfuttavufhuhacsb620bb7eb', client_id = 'gp762nuuoqcoxypju8c569th9wz7q5', refresh_token = 'og13n1xtr2rx9j3jm4qtbctgcv33605nl3teie8tk2me9r88px', access_token_expires = STR_TO_DATE('2021-06-17T21:25', '%Y-%m-%dT%H:%i') WHERE name = 'tv1';
UPDATE channels SET name = 'kanaliigatv2', access_token = 'ozb4s3kfny6i5e6vjcrxjtej4183qk', client_id = 'gp762nuuoqcoxypju8c569th9wz7q5', refresh_token = 'ozhg7ho70ic2g8n9itko601sijir0czr7wsqnw0oqm1q9eatkn', access_token_expires = STR_TO_DATE('2021-06-17T21:26', '%Y-%m-%dT%H:%i') WHERE name = 'tv2';
UPDATE channels SET name = 'kanaliigatv3', access_token = 'q2qg1g4dzvfae806zvpsuka5cugwqg', client_id = 'gp762nuuoqcoxypju8c569th9wz7q5', refresh_token = '41l7vvwg3flrc9zgo4cnz2vbio96t9dg1s968xreiryw02okvy', access_token_expires = STR_TO_DATE('2021-06-17T21:40', '%Y-%m-%dT%H:%i') WHERE name = 'tv3';
UPDATE channels SET name = 'kanaliigabot', access_token = 'sy5f0jyuq2ay29hs80u5g8addu37ns', client_id = 'gp762nuuoqcoxypju8c569th9wz7q5', refresh_token = 'fz7xjhhuex3s2blqc6t8eml0h4f9uvm7xmqcxda5ysyortl4ql', access_token_expires = STR_TO_DATE('2021-06-15T14:25', '%Y-%m-%dT%H:%i'), url = 'https://www.twitch.tv/kanaliigabot' WHERE name = 'test';

ALTER TABLE channels MODIFY `access_token_expires` DATETIME NOT NULL;
