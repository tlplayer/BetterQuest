-- MySQL dump 10.13  Distrib 5.6.51, for Linux (x86_64)
--
-- Host: localhost    Database: logs
-- ------------------------------------------------------
-- Server version	5.6.51

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `instance_creature_kills`
--

DROP TABLE IF EXISTS `instance_creature_kills`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `instance_creature_kills` (
  `mapId` int(10) unsigned NOT NULL COMMENT 'MapId to where creature exist',
  `creatureEntry` int(10) unsigned NOT NULL COMMENT 'entry of the creature who performed the kill',
  `spellEntry` int(10) NOT NULL COMMENT 'entry of spell which did the kill. 0 for melee or unknown',
  `count` int(10) unsigned NOT NULL COMMENT 'number of kills',
  PRIMARY KEY (`mapId`,`creatureEntry`,`spellEntry`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='creatures killing players statistics';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instance_creature_kills`
--

LOCK TABLES `instance_creature_kills` WRITE;
/*!40000 ALTER TABLE `instance_creature_kills` DISABLE KEYS */;
/*!40000 ALTER TABLE `instance_creature_kills` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `instance_custom_counters`
--

DROP TABLE IF EXISTS `instance_custom_counters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `instance_custom_counters` (
  `index` int(10) unsigned NOT NULL COMMENT 'index as defined in InstanceStatistics.h',
  `count` int(10) unsigned NOT NULL COMMENT 'counter',
  PRIMARY KEY (`index`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='custom counters for instance statistics';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instance_custom_counters`
--

LOCK TABLES `instance_custom_counters` WRITE;
/*!40000 ALTER TABLE `instance_custom_counters` DISABLE KEYS */;
/*!40000 ALTER TABLE `instance_custom_counters` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `instance_wipes`
--

DROP TABLE IF EXISTS `instance_wipes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `instance_wipes` (
  `mapId` int(10) unsigned NOT NULL COMMENT 'MapId to where creature exist',
  `creatureEntry` int(10) unsigned NOT NULL COMMENT 'creature which the wipe occured against',
  `count` int(10) unsigned NOT NULL COMMENT 'number of wipes',
  PRIMARY KEY (`mapId`,`creatureEntry`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='players wiping against creatures statistics';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `instance_wipes`
--

LOCK TABLES `instance_wipes` WRITE;
/*!40000 ALTER TABLE `instance_wipes` DISABLE KEYS */;
/*!40000 ALTER TABLE `instance_wipes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `logs_battleground`
--

DROP TABLE IF EXISTS `logs_battleground`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `logs_battleground` (
  `time` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `bgid` int(11) DEFAULT NULL,
  `bgtype` int(11) DEFAULT NULL,
  `bgteamcount` int(11) DEFAULT NULL,
  `bgduration` int(11) DEFAULT NULL,
  `playerGuid` int(11) DEFAULT NULL,
  `team` int(11) DEFAULT NULL,
  `deaths` int(11) DEFAULT NULL,
  `honorBonus` int(11) DEFAULT NULL,
  `honorableKills` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `logs_battleground`
--

LOCK TABLES `logs_battleground` WRITE;
/*!40000 ALTER TABLE `logs_battleground` DISABLE KEYS */;
/*!40000 ALTER TABLE `logs_battleground` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `logs_player`
--

DROP TABLE IF EXISTS `logs_player`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `logs_player` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `type` enum('Basic','WorldPacket','Chat','BG','Character','Honor','RA','DBError','DBErrorFix','ClientIds','Loot','LevelUp','Performance','MoneyTrade','GM','GMCritical','ChatSpam','Anticheat') NOT NULL,
  `subtype` varchar(20) DEFAULT NULL,
  `account` int(10) unsigned NOT NULL,
  `ip` varchar(16) DEFAULT NULL,
  `guid` int(11) DEFAULT NULL,
  `name` varchar(20) DEFAULT NULL,
  `map` int(10) unsigned DEFAULT NULL,
  `pos_x` float DEFAULT NULL,
  `pos_y` float DEFAULT NULL,
  `pos_z` float DEFAULT NULL,
  `text` varchar(512) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `account` (`account`),
  KEY `guid` (`guid`),
  KEY `name` (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC COMMENT='player and account specific log entries';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `logs_player`
--

LOCK TABLES `logs_player` WRITE;
/*!40000 ALTER TABLE `logs_player` DISABLE KEYS */;
/*!40000 ALTER TABLE `logs_player` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `logs_trade`
--

DROP TABLE IF EXISTS `logs_trade`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `logs_trade` (
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `type` enum('AuctionBid','AuctionBuyout','BuyItem','SellItem','GM','Mail','QuestMaxLevel','Quest','Loot','Trade','') NOT NULL DEFAULT '',
  `sender` int(11) unsigned NOT NULL DEFAULT '0',
  `senderType` int(11) unsigned NOT NULL DEFAULT '0',
  `senderEntry` int(11) unsigned NOT NULL DEFAULT '0',
  `receiver` int(11) unsigned NOT NULL DEFAULT '0',
  `amount` int(11) NOT NULL DEFAULT '0',
  `data` int(11) NOT NULL DEFAULT '0',
  KEY `sender` (`sender`),
  KEY `receiver` (`receiver`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `logs_trade`
--

LOCK TABLES `logs_trade` WRITE;
/*!40000 ALTER TABLE `logs_trade` DISABLE KEYS */;
/*!40000 ALTER TABLE `logs_trade` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `logs_transactions`
--

DROP TABLE IF EXISTS `logs_transactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `logs_transactions` (
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `type` enum('Bid','Buyout','PlaceAuction','Trade','Mail','MailCOD') DEFAULT NULL,
  `guid1` int(11) unsigned NOT NULL DEFAULT '0',
  `money1` int(11) unsigned NOT NULL DEFAULT '0',
  `spell1` int(11) unsigned NOT NULL DEFAULT '0',
  `items1` varchar(255) NOT NULL DEFAULT '',
  `guid2` int(11) unsigned NOT NULL DEFAULT '0',
  `money2` int(11) unsigned NOT NULL DEFAULT '0',
  `spell2` int(11) unsigned NOT NULL DEFAULT '0',
  `items2` varchar(255) NOT NULL DEFAULT '',
  KEY `guid2` (`guid2`),
  KEY `guid1` (`guid1`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `logs_transactions`
--

LOCK TABLES `logs_transactions` WRITE;
/*!40000 ALTER TABLE `logs_transactions` DISABLE KEYS */;
/*!40000 ALTER TABLE `logs_transactions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `logs_trashcharacters`
--

DROP TABLE IF EXISTS `logs_trashcharacters`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `logs_trashcharacters` (
  `guid` int(10) unsigned NOT NULL,
  `data` varchar(255) NOT NULL,
  `cluster` tinyint(3) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`guid`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `logs_trashcharacters`
--

LOCK TABLES `logs_trashcharacters` WRITE;
/*!40000 ALTER TABLE `logs_trashcharacters` DISABLE KEYS */;
/*!40000 ALTER TABLE `logs_trashcharacters` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `migrations`
--

DROP TABLE IF EXISTS `migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `migrations` (
  `id` varchar(255) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `migrations`
--

LOCK TABLES `migrations` WRITE;
/*!40000 ALTER TABLE `migrations` DISABLE KEYS */;
INSERT INTO `migrations` VALUES ('20210731110900'),('20220102005704'),('20220523001700'),('20220601082200'),('20220913193700'),('20221008210304');
/*!40000 ALTER TABLE `migrations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `smartlog_creature`
--

DROP TABLE IF EXISTS `smartlog_creature`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `smartlog_creature` (
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `type` enum('Death','LongCombat','ScriptInfo','') NOT NULL DEFAULT '',
  `entry` int(11) NOT NULL DEFAULT '0',
  `guid` int(11) NOT NULL DEFAULT '0',
  `specifier` varchar(255) NOT NULL DEFAULT '',
  `combatTime` int(11) NOT NULL DEFAULT '0',
  `content` varchar(255) NOT NULL DEFAULT '',
  KEY `entry` (`entry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `smartlog_creature`
--

LOCK TABLES `smartlog_creature` WRITE;
/*!40000 ALTER TABLE `smartlog_creature` DISABLE KEYS */;
/*!40000 ALTER TABLE `smartlog_creature` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `system_fingerprint_usage`
--

DROP TABLE IF EXISTS `system_fingerprint_usage`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `system_fingerprint_usage` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `fingerprint` int(10) unsigned NOT NULL,
  `account` int(10) unsigned NOT NULL,
  `ip` varchar(16) NOT NULL,
  `realm` int(10) unsigned NOT NULL,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `architecture` varchar(16) DEFAULT NULL,
  `cputype` varchar(64) DEFAULT NULL,
  `activecpus` int(10) unsigned DEFAULT NULL,
  `totalcpus` int(10) unsigned DEFAULT NULL,
  `pagesize` int(10) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fingerprint` (`fingerprint`),
  KEY `account` (`account`),
  KEY `ip` (`ip`)
) ENGINE=InnoDB AUTO_INCREMENT=77 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `system_fingerprint_usage`
--

LOCK TABLES `system_fingerprint_usage` WRITE;
/*!40000 ALTER TABLE `system_fingerprint_usage` DISABLE KEYS */;
/*!40000 ALTER TABLE `system_fingerprint_usage` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-01-12  0:12:19
