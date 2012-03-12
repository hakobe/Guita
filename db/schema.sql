CREATE TABLE `pick` (
    `uuid`        BIGINT UNSIGNED NOT NULL,
    `user_id`     VARCHAR(255) NOT NULL,
    `description` TEXT NOT NULL DEFAULT '',
    `created`     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    KEY `user` (`user_id`, `created`),
    PRIMARY KEY (`uuid`)
);

CREATE TABLE `user` (
    `uuid`        BIGINT UNSIGNED NOT NULL,
    `github_id`   INTEGER UNSIGNED NOT NULL,
    `sk`          VARCHAR(255) NOT NULL,
    `sk_expires`  TIMESTAMP NOT NULL,
    `struct`      TEXT NOT NULL DEFAULT '',

    UNIQUE KEY (`github_id`),
    UNIQUE KEY (`sk`),
    PRIMARY KEY (`uuid`)
);
