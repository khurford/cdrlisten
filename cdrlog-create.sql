# Database: cdr
# Table: 'cdrlog'
# 
CREATE TABLE `cdrlog` (
  `month` int(11) default '0',
  `day` int(11) default '0',
  `year` int(11) default '0',
  `hour` int(11) default '0',
  `minute` int(11) default '0',
  `extension` bigint(11) default '0',
  `dialednumber` bigint(11) default '0',
  `duration` int(11) default '0',
  KEY `dialednumber` (`dialednumber`),
  KEY `day` (`day`),
  KEY `year` (`year`),
  KEY `month` (`month`),
  KEY `extension` (`extension`)
) TYPE=MyISAM; 

