-- ============================================================
-- 财务管家（Finance Manager）数据库初始化脚本
-- ------------------------------------------------------------
-- 版本        : 1.0
-- 数据库      : finance_manager
-- 兼容版本    : MySQL 8.0+ / 9.x（已在 MySQL 9.7.0 实测通过）
-- 字符集      : utf8mb4 / utf8mb4_0900_ai_ci（支持中文与 Emoji）
-- 设计依据    : 财务管家PRD V1.0.1、后台管理系统PRD、
--               backend/server.js、frontend 页面
-- 执行方式    :
--   mysql --default-character-set=utf8mb4 -u root -p < init_database.sql
-- 说明        :
--   1. 脚本可重复执行，不会删除或覆盖已有业务数据；
--   2. 如需彻底重建，请先备份，再手动 DROP DATABASE finance_manager；
--   3. 系统预置数据使用固定 ID + INSERT IGNORE，重复执行不会重复插入。
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 1;

CREATE DATABASE IF NOT EXISTS `finance_manager`
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE `finance_manager`;

-- ============================================================
-- 一、用户与账本
-- ============================================================

-- ------------------------------------------------------------
-- 1. users 用户表
--    对应接口：/api/register、/api/login、/api/user
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `users` (
  `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  `username`      VARCHAR(20)     NOT NULL                COMMENT '登录用户名（3-20字符）',
  `password`      VARCHAR(255)    NOT NULL                COMMENT '密码（bcrypt 哈希，禁止明文）',
  `nickname`      VARCHAR(50)     NOT NULL DEFAULT ''     COMMENT '昵称',
  `avatar_url`    MEDIUMTEXT      NULL                    COMMENT '头像：图片URL或Base64 Data URL',
  `theme`         VARCHAR(20)     NOT NULL DEFAULT 'light' COMMENT '界面主题：light/dark',
  `last_login_at` DATETIME        NULL                    COMMENT '最后登录时间（后台管理展示用）',
  `created_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '注册时间',
  `updated_at`    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_users_username` (`username`),
  KEY `idx_users_created_at` (`created_at`),
  CONSTRAINT `chk_users_username_len` CHECK (CHAR_LENGTH(`username`) BETWEEN 3 AND 20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='用户表';

-- ------------------------------------------------------------
-- 2. ledgers 账本表
--    注册时自动创建一个默认账本；为 PRD 中“多账本”能力预留
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ledgers` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '账本ID',
  `user_id`     BIGINT UNSIGNED NOT NULL                COMMENT '所属用户ID',
  `name`        VARCHAR(50)     NOT NULL                COMMENT '账本名称',
  `description` VARCHAR(255)    NOT NULL DEFAULT ''     COMMENT '账本描述',
  `is_default`  TINYINT(1)      NOT NULL DEFAULT 0      COMMENT '是否默认账本：1是 0否',
  `created_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at`  DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_ledgers_user_default` (`user_id`, `is_default`),
  CONSTRAINT `fk_ledgers_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='账本表';

-- ============================================================
-- 二、账户
-- ============================================================

-- ------------------------------------------------------------
-- 3. account_types 账户类型表
--    对应接口：/api/account-types
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `account_types` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '账户类型ID',
  `name`       VARCHAR(30)  NOT NULL                COMMENT '类型名称',
  `icon`       VARCHAR(16)  NOT NULL DEFAULT ''     COMMENT '图标（Emoji）',
  `color`      CHAR(7)      NOT NULL DEFAULT '#FFB7C5' COMMENT '颜色（#RRGGBB）',
  `sort_order` INT          NOT NULL DEFAULT 0      COMMENT '排序号',
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_account_types_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='账户类型表';

-- ------------------------------------------------------------
-- 4. accounts 账户表
--    对应接口：/api/accounts、/api/accounts/:id
--    current_balance 由 transactions 表触发器自动维护
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `accounts` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '账户ID',
  `ledger_id`       BIGINT UNSIGNED NOT NULL                COMMENT '所属账本ID',
  `user_id`         BIGINT UNSIGNED NOT NULL                COMMENT '所属用户ID',
  `type_id`         INT UNSIGNED    NOT NULL                COMMENT '账户类型ID',
  `name`            VARCHAR(50)     NOT NULL                COMMENT '账户名称',
  `icon`            VARCHAR(16)     NOT NULL DEFAULT ''     COMMENT '图标（Emoji）',
  `color`           CHAR(7)         NOT NULL DEFAULT '#FFB7C5' COMMENT '颜色（#RRGGBB）',
  `initial_balance` DECIMAL(14,2)   NOT NULL DEFAULT 0.00   COMMENT '初始余额',
  `current_balance` DECIMAL(14,2)   NOT NULL DEFAULT 0.00   COMMENT '当前余额（触发器维护）',
  `sort_order`      INT             NOT NULL DEFAULT 0      COMMENT '排序号',
  `created_at`      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at`      DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_accounts_user_sort` (`user_id`, `sort_order`),
  KEY `idx_accounts_ledger` (`ledger_id`),
  KEY `idx_accounts_type` (`type_id`),
  CONSTRAINT `fk_accounts_ledger` FOREIGN KEY (`ledger_id`) REFERENCES `ledgers` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_accounts_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_accounts_type` FOREIGN KEY (`type_id`) REFERENCES `account_types` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='账户表';

-- ============================================================
-- 三、分类
-- ============================================================

-- ------------------------------------------------------------
-- 5. category_types 分类类型表（收入 / 支出）
--    对应接口：/api/category-types
--    name 必须为 income / expense，后端统计接口按此过滤
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `category_types` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '分类类型ID',
  `name`       VARCHAR(20)  NOT NULL                COMMENT '类型代码：income/expense',
  `label`      VARCHAR(20)  NOT NULL                COMMENT '显示名称：收入/支出',
  `sort_order` INT          NOT NULL DEFAULT 0      COMMENT '排序号',
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_category_types_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='分类类型表（收入/支出）';

-- ------------------------------------------------------------
-- 6. categories 分类表
--    对应接口：/api/categories、/api/categories/:id
--    user_id 为 NULL 且 is_system=1 表示系统预置分类（所有用户共享）
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `categories` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '分类ID',
  `user_id`    BIGINT UNSIGNED NULL                    COMMENT '所属用户；NULL=系统预置',
  `type_id`    INT UNSIGNED    NOT NULL                COMMENT '分类类型ID（支出/收入）',
  `name`       VARCHAR(30)     NOT NULL                COMMENT '分类名称',
  `icon`       VARCHAR(16)     NOT NULL DEFAULT ''     COMMENT '图标（Emoji）',
  `color`      CHAR(7)         NOT NULL DEFAULT '#FFB7C5' COMMENT '颜色（#RRGGBB）',
  `is_system`  TINYINT(1)      NOT NULL DEFAULT 0      COMMENT '是否系统预置：1是 0否',
  `sort_order` INT             NOT NULL DEFAULT 0      COMMENT '排序号',
  `created_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_categories_user_type` (`user_id`, `type_id`, `is_system`),
  KEY `idx_categories_type_sort` (`type_id`, `is_system`, `sort_order`),
  CONSTRAINT `fk_categories_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_categories_type` FOREIGN KEY (`type_id`) REFERENCES `category_types` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='分类表';

-- ============================================================
-- 四、交易记录
-- ============================================================

-- ------------------------------------------------------------
-- 7. transactions 交易记录表
--    对应接口：/api/transactions、/api/transactions/:id
--    amount 恒为正数，收入/支出方向由 type_id 决定
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `transactions` (
  `id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '交易ID',
  `ledger_id`        BIGINT UNSIGNED NOT NULL                COMMENT '所属账本ID',
  `user_id`          BIGINT UNSIGNED NOT NULL                COMMENT '所属用户ID',
  `account_id`       BIGINT UNSIGNED NOT NULL                COMMENT '账户ID',
  `category_id`      BIGINT UNSIGNED NOT NULL                COMMENT '分类ID',
  `type_id`          INT UNSIGNED    NOT NULL                COMMENT '收支类型ID（1支出 2收入）',
  `amount`           DECIMAL(14,2)   NOT NULL                COMMENT '金额（正数）',
  `remark`           VARCHAR(255)    NULL                    COMMENT '备注',
  `transaction_date` DATE            NOT NULL                COMMENT '交易日期',
  `created_at`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at`       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_tx_user_date` (`user_id`, `transaction_date`, `id`),
  KEY `idx_tx_user_type_date` (`user_id`, `type_id`, `transaction_date`),
  KEY `idx_tx_account` (`account_id`),
  KEY `idx_tx_category` (`category_id`),
  KEY `idx_tx_ledger` (`ledger_id`),
  KEY `idx_tx_created_at` (`created_at`),
  CONSTRAINT `fk_tx_ledger` FOREIGN KEY (`ledger_id`) REFERENCES `ledgers` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tx_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_tx_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_tx_category` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_tx_type` FOREIGN KEY (`type_id`) REFERENCES `category_types` (`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_tx_amount` CHECK (`amount` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='交易记录表';

-- ============================================================
-- 五、后台管理
-- ============================================================

-- ------------------------------------------------------------
-- 8. admins 管理员表
--    依据《财务管家后台管理系统PRD》5.2 节创建，仅用于后台登录
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `admins` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '管理员ID',
  `username`   VARCHAR(50)     NOT NULL                COMMENT '管理员用户名',
  `password`   VARCHAR(255)    NOT NULL                COMMENT '密码（bcrypt 哈希）',
  `nickname`   VARCHAR(50)     DEFAULT NULL            COMMENT '昵称',
  `created_at` DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_admins_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='后台管理员表';

-- ============================================================
-- 六、系统预置数据
-- ============================================================

-- 账户类型（PRD 3.2.5）
INSERT IGNORE INTO `account_types` (`id`, `name`, `icon`, `color`, `sort_order`) VALUES
  (1, '现金',     '💵', '#FFB7C5', 1),
  (2, '银行卡',   '💳', '#C9B8E8', 2),
  (3, '微信支付', '📱', '#7DD3C0', 3),
  (4, '支付宝',   '🟢', '#FF8FA3', 4),
  (5, '银行账户', '📘', '#A8D8EA', 5);

-- 分类类型（1=支出，2=收入）
INSERT IGNORE INTO `category_types` (`id`, `name`, `label`, `sort_order`) VALUES
  (1, 'expense', '支出', 1),
  (2, 'income',  '收入', 2);

-- 系统预置分类：支出 10 个（PRD 3.2.4）
INSERT IGNORE INTO `categories`
  (`id`, `user_id`, `type_id`, `name`, `icon`, `color`, `is_system`, `sort_order`) VALUES
  (1,  NULL, 1, '餐饮', '🍚', '#FFA09B', 1, 1),
  (2,  NULL, 1, '交通', '🚗', '#7DD3C0', 1, 2),
  (3,  NULL, 1, '购物', '🛒', '#FFB7C5', 1, 3),
  (4,  NULL, 1, '娱乐', '🎬', '#C9B8E8', 1, 4),
  (5,  NULL, 1, '住房', '🏠', '#A8D8EA', 1, 5),
  (6,  NULL, 1, '医疗', '💊', '#FF8FA3', 1, 6),
  (7,  NULL, 1, '通讯', '📱', '#7DD3C0', 1, 7),
  (8,  NULL, 1, '服饰', '👔', '#FFB7C5', 1, 8),
  (9,  NULL, 1, '人情', '🎁', '#C9B8E8', 1, 9),
  (10, NULL, 1, '其他', '📦', '#A8A8A8', 1, 10);

-- 系统预置分类：收入 5 个（PRD 3.2.4）
INSERT IGNORE INTO `categories`
  (`id`, `user_id`, `type_id`, `name`, `icon`, `color`, `is_system`, `sort_order`) VALUES
  (11, NULL, 2, '工资', '💰', '#7DD3C0', 1, 1),
  (12, NULL, 2, '兼职', '💵', '#A8D8EA', 1, 2),
  (13, NULL, 2, '奖金', '🎯', '#C9B8E8', 1, 3),
  (14, NULL, 2, '礼金', '🎁', '#FFB7C5', 1, 4),
  (15, NULL, 2, '其他', '📥', '#A8A8A8', 1, 5);

-- ============================================================
-- 七、触发器：自动维护账户当前余额
-- ------------------------------------------------------------
-- 新增/删除/修改交易时，按收支方向同步 accounts.current_balance。
-- 注意：MySQL 的外键级联删除不会触发触发器，因此 accounts /
--       categories 被 transactions 引用时使用 RESTRICT 删除策略。
-- ============================================================

DROP TRIGGER IF EXISTS `trg_transactions_after_insert`;
DROP TRIGGER IF EXISTS `trg_transactions_after_delete`;
DROP TRIGGER IF EXISTS `trg_transactions_after_update`;

DELIMITER $$

CREATE TRIGGER `trg_transactions_after_insert`
AFTER INSERT ON `transactions`
FOR EACH ROW
BEGIN
  UPDATE `accounts` a
    JOIN `category_types` ct ON ct.`id` = NEW.`type_id`
  SET a.`current_balance` = a.`current_balance`
      + IF(ct.`name` = 'income', NEW.`amount`, -NEW.`amount`)
  WHERE a.`id` = NEW.`account_id`;
END$$

CREATE TRIGGER `trg_transactions_after_delete`
AFTER DELETE ON `transactions`
FOR EACH ROW
BEGIN
  UPDATE `accounts` a
    JOIN `category_types` ct ON ct.`id` = OLD.`type_id`
  SET a.`current_balance` = a.`current_balance`
      - IF(ct.`name` = 'income', OLD.`amount`, -OLD.`amount`)
  WHERE a.`id` = OLD.`account_id`;
END$$

CREATE TRIGGER `trg_transactions_after_update`
AFTER UPDATE ON `transactions`
FOR EACH ROW
BEGIN
  IF NOT (OLD.`account_id` <=> NEW.`account_id`)
     OR NOT (OLD.`amount` <=> NEW.`amount`)
     OR NOT (OLD.`type_id` <=> NEW.`type_id`) THEN
    -- 冲销旧值
    UPDATE `accounts` a
      JOIN `category_types` ct ON ct.`id` = OLD.`type_id`
    SET a.`current_balance` = a.`current_balance`
        - IF(ct.`name` = 'income', OLD.`amount`, -OLD.`amount`)
    WHERE a.`id` = OLD.`account_id`;

    -- 计入新值
    UPDATE `accounts` a
      JOIN `category_types` ct ON ct.`id` = NEW.`type_id`
    SET a.`current_balance` = a.`current_balance`
        + IF(ct.`name` = 'income', NEW.`amount`, -NEW.`amount`)
    WHERE a.`id` = NEW.`account_id`;
  END IF;
END$$

DELIMITER ;

-- ============================================================
-- 八、常用视图
-- ============================================================

-- 交易明细视图：供后台管理、Excel 导出使用
CREATE OR REPLACE VIEW `v_transaction_detail` AS
SELECT
  t.`id`               AS transaction_id,
  t.`user_id`          AS user_id,
  u.`username`         AS username,
  t.`ledger_id`        AS ledger_id,
  l.`name`             AS ledger_name,
  t.`account_id`       AS account_id,
  a.`name`             AS account_name,
  a.`icon`             AS account_icon,
  t.`category_id`      AS category_id,
  c.`name`             AS category_name,
  c.`icon`             AS category_icon,
  c.`color`            AS category_color,
  ct.`name`            AS type_name,
  ct.`label`           AS type_label,
  t.`amount`           AS amount,
  IF(ct.`name` = 'income', t.`amount`, -t.`amount`) AS signed_amount,
  t.`remark`           AS remark,
  t.`transaction_date` AS transaction_date,
  t.`created_at`       AS created_at
FROM `transactions` t
JOIN `users` u          ON u.`id` = t.`user_id`
JOIN `ledgers` l        ON l.`id` = t.`ledger_id`
JOIN `accounts` a       ON a.`id` = t.`account_id`
JOIN `categories` c     ON c.`id` = t.`category_id`
JOIN `category_types` ct ON ct.`id` = t.`type_id`;

-- 用户月度收支汇总视图（供统计/后台使用）
CREATE OR REPLACE VIEW `v_user_monthly_summary` AS
SELECT
  t.`user_id` AS user_id,
  u.`username` AS username,
  DATE_FORMAT(t.`transaction_date`, '%Y-%m') AS month,
  SUM(IF(ct.`name` = 'income',  t.`amount`, 0)) AS income,
  SUM(IF(ct.`name` = 'expense', t.`amount`, 0)) AS expense,
  SUM(IF(ct.`name` = 'income',  t.`amount`, -t.`amount`)) AS balance,
  COUNT(*) AS transaction_count
FROM `transactions` t
JOIN `users` u          ON u.`id` = t.`user_id`
JOIN `category_types` ct ON ct.`id` = t.`type_id`
GROUP BY t.`user_id`, u.`username`, DATE_FORMAT(t.`transaction_date`, '%Y-%m');

-- 账户余额核对视图：对比触发器维护值与交易流水计算值
CREATE OR REPLACE VIEW `v_account_balance` AS
SELECT
  a.`id`              AS account_id,
  a.`user_id`         AS user_id,
  a.`name`            AS account_name,
  a.`initial_balance` AS initial_balance,
  COALESCE(SUM(IF(ct.`name` = 'income', t.`amount`, -t.`amount`)), 0) AS transaction_net,
  a.`initial_balance`
    + COALESCE(SUM(IF(ct.`name` = 'income', t.`amount`, -t.`amount`)), 0) AS calculated_balance,
  a.`current_balance` AS stored_balance,
  a.`current_balance`
    - (a.`initial_balance`
       + COALESCE(SUM(IF(ct.`name` = 'income', t.`amount`, -t.`amount`)), 0)) AS diff
FROM `accounts` a
LEFT JOIN `transactions` t   ON t.`account_id` = a.`id`
LEFT JOIN `category_types` ct ON ct.`id` = t.`type_id`
GROUP BY a.`id`, a.`user_id`, a.`name`, a.`initial_balance`, a.`current_balance`;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- 脚本结束
-- ============================================================
