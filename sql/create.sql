CREATE DATABASE pool;

CREATE USER 'pool_payout'@'localhost';
CREATE USER 'pool_service'@'localhost';
CREATE USER 'pool_server'@'localhost';
CREATE USER 'pool_info'@'localhost';

CREATE TABLE pool.user (
  id           INTEGER     PRIMARY KEY NOT NULL AUTO_INCREMENT,
  address      VARCHAR(64) NOT NULL UNIQUE
);
CREATE INDEX idx_user_address ON pool.user (address);

CREATE TABLE pool.block (
  id           INTEGER    PRIMARY KEY NOT NULL AUTO_INCREMENT,
  hash         BINARY(32) NOT NULL UNIQUE,
  height       INTEGER    NOT NULL,
  main_chain   BOOLEAN    NOT NULL DEFAULT false
);
CREATE INDEX idx_block_hash ON pool.block (hash);
CREATE INDEX idx_block_height ON pool.block (height);

CREATE TABLE pool.share (
  id           INTEGER    PRIMARY KEY NOT NULL AUTO_INCREMENT,
  user         INTEGER    NOT NULL REFERENCES pool.user(id),
  device       INTEGER    UNSIGNED NOT NULL,
  datetime     BIGINT     NOT NULL,
  prev_block   INTEGER    NOT NULL REFERENCES pool.block(id),
  difficulty   DOUBLE     NOT NULL,
  hash         BINARY(32) NOT NULL UNIQUE
);

CREATE INDEX idx_share_prev ON pool.share (prev_block);
CREATE INDEX idx_share_hash ON pool.share (hash);

CREATE TABLE pool.payin (
  id           INTEGER    PRIMARY KEY NOT NULL AUTO_INCREMENT,
  user         INTEGER    NOT NULL REFERENCES pool.user(id),
  amount       DOUBLE     NOT NULL,
  datetime     BIGINT     NOT NULL,
  block        INTEGER    NOT NULL REFERENCES pool.block(id),
  UNIQUE(user, block)
);

CREATE TABLE pool.payout (
  id           INTEGER    PRIMARY KEY NOT NULL AUTO_INCREMENT,
  user         INTEGER       NOT NULL REFERENCES pool.user(id),
  amount       DOUBLE     NOT NULL,
  datetime     BIGINT     NOT NULL,
  transaction  BINARY(32)
);

CREATE TABLE pool.payout_request (
  id           INTEGER    PRIMARY KEY NOT NULL AUTO_INCREMENT,
  user         INTEGER    NOT NULL UNIQUE REFERENCES pool.user(id)
);

DELIMITER //

CREATE PROCEDURE pool.StoreUserId(IN address VARCHAR(64), OUT user_id INTEGER)
SQL SECURITY INVOKER
BEGIN
    SELECT id INTO user_id FROM user WHERE user.address = address;
    IF ISNULL(user_id) THEN
        INSERT IGNORE INTO user (address) VALUES (address);
        SELECT id INTO user_id FROM user WHERE user.address = address;
    END IF;
END //

CREATE PROCEDURE pool.GetStoreUserId(IN address VARCHAR(64))
SQL SECURITY INVOKER
BEGIN
    CALL pool.StoreUserId(address, @user_id);
    SELECT @user_id AS id;
END //

CREATE PROCEDURE pool.StoreBlockId(IN hash BINARY(32), IN height INTEGER, OUT block_id INTEGER)
SQL SECURITY INVOKER
BEGIN
    SELECT id INTO block_id FROM block WHERE block.hash = hash;
    IF ISNULL(block_id) THEN
        INSERT IGNORE INTO block (hash, height) VALUES (hash, height);
        SELECT id INTO block_id FROM block WHERE block.hash = hash;
    END IF;
END //

CREATE PROCEDURE pool.GetStoreBlockId(IN hash BINARY(32), IN height INTEGER)
SQL SECURITY INVOKER
BEGIN
    CALL pool.StoreBlockId(hash, height, @block_id);
    SELECT @block_id AS id;
END //

CREATE PROCEDURE pool.StoreShareWithAllData(IN address VARCHAR(64), IN device INTEGER, IN datetime BIGINT, IN prev_block_hash BINARY(32), IN prev_block_height INTEGER, IN difficulty DOUBLE, IN hash BINARY(32))
SQL SECURITY INVOKER
BEGIN
    CALL pool.StoreUserId(address, @user_id);
    CALL pool.StoreBlockId(prev_block_hash, prev_block_height, @block_id);
    CALL pool.StoreShareWithAllIds(@user_id, device, datetime, @block_id, difficulty, hash);
END //

CREATE PROCEDURE pool.StoreShareWithBlockId(IN address VARCHAR(64), IN device INTEGER, IN datetime BIGINT, IN block_id INTEGER, IN difficulty DOUBLE, IN hash BINARY(32))
SQL SECURITY INVOKER
BEGIN
    CALL pool.StoreUserId(address, @user_id);
    CALL pool.StoreShareWithAllIds(@user_id, device, datetime, block_id, difficulty, hash);
END //

CREATE PROCEDURE pool.StoreShareWithUserId(IN user_id INTEGER, IN device INTEGER, IN datetime BIGINT, IN prev_block_hash BINARY(32), IN prev_block_height INTEGER, IN difficulty DOUBLE, IN hash BINARY(32))
SQL SECURITY INVOKER
BEGIN
    CALL pool.StoreBlockId(prev_block_hash, prev_block_height, @block_id);
    CALL pool.StoreShareWithAllIds(user_id, device, datetime, @block_id, difficulty, hash);
END //

CREATE PROCEDURE pool.StoreShareWithAllIds(IN user_id INTEGER, IN device INTEGER, IN datetime BIGINT, IN block_id INTEGER, IN difficulty DOUBLE, IN hash BINARY(32))
SQL SECURITY INVOKER
BEGIN
    DECLARE share_id INTEGER;
    SELECT id INTO share_id FROM share WHERE share.user_id = user_id AND share.hash = hash;
    IF ISNULL(share_id) THEN
        INSERT IGNORE INTO share (user, device, datetime, prev_block, difficulty, hash) VALUES (user_id, device, datetime, block_id, difficulty, hash);
        SELECT user_id, block_id, TRUE AS status;
    ELSE
        SELECT user_id, block_id, FALSE AS status;
    END IF;
END //

DELIMITER ;

GRANT SELECT,INSERT ON pool.user TO 'pool_server'@'localhost';
GRANT SELECT ON pool.user TO 'pool_service'@'localhost';
GRANT SELECT ON pool.user TO 'pool_payout'@'localhost';
GRANT SELECT ON pool.user TO 'pool_info'@'localhost';

GRANT SELECT,INSERT ON pool.block TO 'pool_server'@'localhost';
GRANT SELECT,INSERT,UPDATE ON pool.block TO 'pool_service'@'localhost';
GRANT SELECT ON pool.block TO 'pool_payout'@'localhost';
GRANT SELECT ON pool.block TO 'pool_info'@'localhost';

GRANT SELECT,INSERT ON pool.share TO 'pool_server'@'localhost';
GRANT SELECT ON pool.share TO 'pool_service'@'localhost';
GRANT SELECT ON pool.share TO 'pool_info'@'localhost';

GRANT SELECT ON pool.payin TO 'pool_server'@'localhost';
GRANT SELECT,INSERT,DELETE ON pool.payin TO 'pool_service'@'localhost';
GRANT SELECT ON pool.payin TO 'pool_payout'@'localhost';
GRANT SELECT ON pool.payin TO 'pool_info'@'localhost';

GRANT SELECT ON pool.payout TO 'pool_server'@'localhost';
GRANT SELECT,INSERT ON pool.payout TO 'pool_service'@'localhost';
GRANT SELECT,INSERT ON pool.payout TO 'pool_payout'@'localhost';
GRANT SELECT ON pool.payout TO 'pool_info'@'localhost';

GRANT SELECT,INSERT,DELETE ON pool.payout_request TO 'pool_server'@'localhost';
GRANT SELECT,DELETE ON pool.payout_request TO 'pool_payout'@'localhost';
GRANT SELECT ON pool.payout_request TO 'pool_info'@'localhost';

GRANT EXECUTE ON pool.* TO 'pool_server'@'localhost';
GRANT EXECUTE ON pool.* TO 'pool_service'@'localhost';
