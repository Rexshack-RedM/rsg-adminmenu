CREATE TABLE IF NOT EXISTS `admin_reports` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `report_type` VARCHAR(50) NOT NULL,
  `reporter_id` INT(11) NOT NULL,
  `reporter_name` VARCHAR(255) NOT NULL,
  `reporter_license` VARCHAR(255) NOT NULL,
  `reporter_discord` VARCHAR(255) DEFAULT NULL,
  `reporter_coords` VARCHAR(255) NOT NULL,
  `reported_player_id` INT(11) DEFAULT NULL,
  `reported_player_name` VARCHAR(255) DEFAULT NULL,
  `reported_player_license` VARCHAR(255) DEFAULT NULL,
  `reported_player_discord` VARCHAR(255) DEFAULT NULL,
  `title` VARCHAR(255) NOT NULL,
  `description` TEXT NOT NULL,
  `image_url` VARCHAR(500) DEFAULT NULL,
  `status` VARCHAR(50) DEFAULT 'open',
  `assigned_admin_id` INT(11) DEFAULT NULL,
  `assigned_admin_name` VARCHAR(255) DEFAULT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `admin_report_messages` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `report_id` INT(11) NOT NULL,
  `sender_type` VARCHAR(50) NOT NULL,
  `sender_id` INT(11) NOT NULL,
  `sender_name` VARCHAR(255) NOT NULL,
  `message` TEXT NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`report_id`) REFERENCES `admin_reports`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `admin_report_nearby_players` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `report_id` INT(11) NOT NULL,
  `player_id` INT(11) NOT NULL,
  `player_name` VARCHAR(255) NOT NULL,
  `player_license` VARCHAR(255) NOT NULL,
  `distance` FLOAT NOT NULL,
  PRIMARY KEY (`id`),
  FOREIGN KEY (`report_id`) REFERENCES `admin_reports`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
