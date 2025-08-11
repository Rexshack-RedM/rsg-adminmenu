CREATE TABLE IF NOT EXISTS `reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `reporter_id` varchar(50) NOT NULL,
  `reporter_name` varchar(255) NOT NULL,
  `reported_id` varchar(50) DEFAULT NULL,
  `reported_name` varchar(255) DEFAULT NULL,
  `reason` text NOT NULL,
  `type` enum('player','bug') NOT NULL,
  `status` enum('open','closed') DEFAULT 'open',
  `closed_by` varchar(255) DEFAULT NULL,
  `closed_reason` text DEFAULT NULL,
  `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
  `closed_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;