-- ============================================================
-- 财务管家数据库验证脚本
-- 执行：mysql --default-character-set=utf8mb4 -u root -p < verify.sql
-- 说明：本脚本只做查询与一次事务内的写入测试（最后 ROLLBACK），
--       不会留下任何测试数据。
-- ============================================================

SET NAMES utf8mb4;
USE `finance_manager`;

-- 1. 版本与当前库
SELECT VERSION() AS mysql_version, DATABASE() AS current_database;

-- 2. 表清单（预期 8 张业务表）
SELECT `table_name`, `table_rows`, `engine`, `table_collation`
FROM `information_schema`.`tables`
WHERE `table_schema` = 'finance_manager' AND `table_type` = 'BASE TABLE'
ORDER BY `table_name`;

-- 3. 预置数据数量（预期：5 / 2 / 15）
SELECT
  (SELECT COUNT(*) FROM `account_types`  WHERE `sort_order` > 0) AS account_type_count,
  (SELECT COUNT(*) FROM `category_types`)                        AS category_type_count,
  (SELECT COUNT(*) FROM `categories` WHERE `is_system` = 1)      AS system_category_count;

-- 4. 触发器（预期 3 个）
SELECT `trigger_name`, `event_manipulation`, `action_timing`
FROM `information_schema`.`triggers`
WHERE `trigger_schema` = 'finance_manager'
ORDER BY `trigger_name`;

-- 5. 视图（预期 3 个）
SELECT `table_name`
FROM `information_schema`.`views`
WHERE `table_schema` = 'finance_manager'
ORDER BY `table_name`;

-- 6. 引用完整性检查（全部应为 0）
SELECT '交易引用了不存在的账户' AS check_item, COUNT(*) AS invalid_count
FROM `transactions` t LEFT JOIN `accounts` a ON a.`id` = t.`account_id` WHERE a.`id` IS NULL
UNION ALL
SELECT '交易引用了不存在的分类', COUNT(*)
FROM `transactions` t LEFT JOIN `categories` c ON c.`id` = t.`category_id` WHERE c.`id` IS NULL
UNION ALL
SELECT '交易引用了不存在的用户', COUNT(*)
FROM `transactions` t LEFT JOIN `users` u ON u.`id` = t.`user_id` WHERE u.`id` IS NULL
UNION ALL
SELECT '账户引用了不存在的账本', COUNT(*)
FROM `accounts` a LEFT JOIN `ledgers` l ON l.`id` = a.`ledger_id` WHERE l.`id` IS NULL;

-- 7. 事务内冒烟测试：验证外键 + 余额触发器（结束自动回滚）
START TRANSACTION;

INSERT INTO `users` (`username`, `password`, `nickname`)
VALUES ('verify_user', '$2a$10$012345678901234567890u0123456789012345678901234567890', '验证用户');
SET @uid = LAST_INSERT_ID();

INSERT INTO `ledgers` (`user_id`, `name`, `description`, `is_default`)
VALUES (@uid, '验证账本', '冒烟测试账本', 1);
SET @lid = LAST_INSERT_ID();

INSERT INTO `accounts`
  (`ledger_id`, `user_id`, `type_id`, `name`, `icon`, `color`, `initial_balance`, `current_balance`)
VALUES (@lid, @uid, 1, '验证现金', '💵', '#FFB7C5', 100.00, 100.00);
SET @aid = LAST_INSERT_ID();

-- 支出 30：余额应为 70
INSERT INTO `transactions`
  (`ledger_id`, `user_id`, `account_id`, `category_id`, `type_id`, `amount`, `remark`, `transaction_date`)
VALUES (@lid, @uid, @aid, 1, 1, 30.00, '冒烟测试-支出', CURDATE());

SELECT '支出后余额（预期 70.00）' AS check_item, `current_balance` AS value
FROM `accounts` WHERE `id` = @aid;

-- 收入 50：余额应为 120
INSERT INTO `transactions`
  (`ledger_id`, `user_id`, `account_id`, `category_id`, `type_id`, `amount`, `remark`, `transaction_date`)
VALUES (@lid, @uid, @aid, 11, 2, 50.00, '冒烟测试-收入', CURDATE());

SELECT '收入后余额（预期 120.00）' AS check_item, `current_balance` AS value
FROM `accounts` WHERE `id` = @aid;

-- 余额核对视图
SELECT `account_id`, `initial_balance`, `transaction_net`, `calculated_balance`, `stored_balance`, `diff`
FROM `v_account_balance` WHERE `account_id` = @aid;

ROLLBACK;

-- 8. 回滚后确认测试数据未残留（应为 0）
SELECT '测试用户残留' AS check_item, COUNT(*) AS cnt FROM `users` WHERE `username` = 'verify_user';

-- ============================================================
-- 验证结束
-- ============================================================
