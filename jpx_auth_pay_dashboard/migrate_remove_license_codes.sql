ALTER TABLE `accounts`
  DROP COLUMN IF EXISTS `license_code`,
  DROP COLUMN IF EXISTS `latest_license_id`;

DROP TABLE IF EXISTS `license_history`;
