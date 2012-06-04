CREATE TABLE `pick` (
    `uuid`        BIGINT UNSIGNED NOT NULL,
    `user_id`     BIGINT UNSIGNED NOT NULL,
    `description` TEXT NOT NULL DEFAULT '',
    `created`     TIMESTAMP NOT NULL DEFAULT '0000-00-00 00:00:00',
    `modified`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    KEY `user` (`user_id`, `created`),
    KEY `created` (`created`),
    KEY `modified` (`modified`),
    PRIMARY KEY (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=binary;

CREATE TABLE `user` (
    `uuid`        BIGINT UNSIGNED NOT NULL,
    `github_id`   INTEGER UNSIGNED NOT NULL,
    `name`        VARCHAR(128) NOT NULL,
    `sk`          VARCHAR(255) NOT NULL,
    `sk_expires`  TIMESTAMP NOT NULL,
    `struct`      TEXT NOT NULL DEFAULT '',

    UNIQUE KEY (`github_id`),
    UNIQUE KEY (`sk`),
    UNIQUE KEY (`name`),
    PRIMARY KEY (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=binary;
