# BetterQuestText – Project Documentation

**Last Updated:** 2025-01-03  
**Status:** Active Development  
**Target:** Classic WoW (cmangos)

# BetterQuest Development Guide

# TODO
examples:
The Alliance of Lordaeron
Historian Karnik

## System Overview

BetterQuest is a WoW 1.12.1 (Vanilla) addon that adds voice-over narration and enhanced NPC portraits to quest and gossip dialogs.

---

## Getting broadcast text

Relevant tables:
select * from creature_template where name like '%ynasha%';
+-------+------------------+---------+----------+----------+------------+------------+------------+------------+-----------------------+-----------------------+-----------------------+-----------------------+---------+-------+--------+--------------+-------------+-----------------+--------------+----------+-----------+--------------+------------+-------------------+--------------+--------------+--------------+--------------+-----------+----------+-----------+-------------+---------+-------+---------+-----------+------+------------------+-----------------+------------------+----------------+-----------------+----------------------+--------------------+-------------------+-------------------+---------------------+------------------+----------------+----------------+--------------+--------------+-------------+-------------+--------------+--------------+-------+------------------+-------------------+---------------------+----------------------+--------------+-------------+-------------+--------+------------------+----------------+-------------+-------------+--------------------+------------------+----------------+----------------+------------------+-----------------+------------------+------------------+----------------+--------------+-------------+--------------+--------------+-------------+-------------------+------------------+--------------+-----------------------+-------------+-----------+------------------+-----------+-----------+---------------------+----------+---------+------------+
| Entry | Name             | SubName | MinLevel | MaxLevel | DisplayId1 | DisplayId2 | DisplayId3 | DisplayId4 | DisplayIdProbability1 | DisplayIdProbability2 | DisplayIdProbability3 | DisplayIdProbability4 | Faction | Scale | Family | CreatureType | InhabitType | RegenerateStats | RacialLeader | NpcFlags | UnitFlags | DynamicFlags | ExtraFlags | CreatureTypeFlags | StaticFlags1 | StaticFlags2 | StaticFlags3 | StaticFlags4 | SpeedWalk | SpeedRun | Detection | CallForHelp | Pursuit | Leash | Timeout | UnitClass | Rank | HealthMultiplier | PowerMultiplier | DamageMultiplier | DamageVariance | ArmorMultiplier | ExperienceMultiplier | StrengthMultiplier | AgilityMultiplier | StaminaMultiplier | IntellectMultiplier | SpiritMultiplier | MinLevelHealth | MaxLevelHealth | MinLevelMana | MaxLevelMana | MinMeleeDmg | MaxMeleeDmg | MinRangedDmg | MaxRangedDmg | Armor | MeleeAttackPower | RangedAttackPower | MeleeBaseAttackTime | RangedBaseAttackTime | DamageSchool | MinLootGold | MaxLootGold | LootId | PickpocketLootId | SkinningLootId | KillCredit1 | KillCredit2 | MechanicImmuneMask | SchoolImmuneMask | ResistanceHoly | ResistanceFire | ResistanceNature | ResistanceFrost | ResistanceShadow | ResistanceArcane | PetSpellDataId | MovementType | TrainerType | TrainerSpell | TrainerClass | TrainerRace | TrainerTemplateId | VendorTemplateId | GossipMenuId | InteractionPauseTimer | CorpseDecay | SpellList | CharmedSpellList | StringId1 | StringId2 | EquipmentTemplateId | Civilian | AIName  | ScriptName |
+-------+------------------+---------+----------+----------+------------+------------+------------+------------+-----------------------+-----------------------+-----------------------+-----------------------+---------+-------+--------+--------------+-------------+-----------------+--------------+----------+-----------+--------------+------------+-------------------+--------------+--------------+--------------+--------------+-----------+----------+-----------+-------------+---------+-------+---------+-----------+------+------------------+-----------------+------------------+----------------+-----------------+----------------------+--------------------+-------------------+-------------------+---------------------+------------------+----------------+----------------+--------------+--------------+-------------+-------------+--------------+--------------+-------+------------------+-------------------+---------------------+----------------------+--------------+-------------+-------------+--------+------------------+----------------+-------------+-------------+--------------------+------------------+----------------+----------------+------------------+-----------------+------------------+------------------+----------------+--------------+-------------+--------------+--------------+-------------+-------------------+------------------+--------------+-----------------------+-------------+-----------+------------------+-----------+-----------+---------------------+----------+---------+------------+
| 11711 | Sentinel Aynasha | NULL    |       20 |       20 |      11663 |          0 |          0 |          0 |                   100 |                     0 |                     0 |                     0 |     231 |     0 |      0 |            7 |           3 |              14 |            0 |        2 |         0 |            0 |          0 |                 0 |            0 |            0 |            0 |            0 |         1 |  1.42857 |        18 |           0 |   15000 |     0 |       0 |         1 |    0 |                1 |               1 |                1 |              1 |               1 |                    1 |                  1 |                 1 |                 1 |                   1 |                1 |            484 |            484 |            0 |            0 |          24 |          31 |       31.856 |       43.802 |   852 |               13 |               100 |                2000 |                 2000 |            0 |           0 |           0 |      0 |                0 |              0 |           0 |           0 |                  0 |                0 |              0 |              0 |                0 |               0 |                0 |                0 |              0 |            0 |           0 |            0 |            0 |           0 |                 0 |                0 |            0 |                    -1 |           0 |         0 |                0 |         0 |         0 |               11711 |        0 | EventAI |            |
+-------+------------------+---------+----------+----------+------------+------------+------------+------------+-----------------------+-----------------------+-----------------------+-----------------------+---------+-------+--------+--------------+-------------+-----------------+--------------+----------+-----------+--------------+------------+-------------------+--------------+--------------+--------------+--------------+-----------+----------+-----------+-------------+---------+-------+---------+-----------+------+------------------+-----------------+------------------+----------------+-----------------+----------------------+--------------------+-------------------+-------------------+---------------------+------------------+----------------+----------------+--------------+--------------+-------------+-------------+--------------+--------------+-------+------------------+-------------------+---------------------+----------------------+--------------+-------------+-------------+--------+------------------+----------------+-------------+-------------+--------------------+------------------+----------------+----------------+------------------+-----------------+------------------+------------------+----------------+--------------+-------------+--------------+--------------+-------------+-------------------+------------------+--------------+-----------------------+-------------+-----------+------------------+-----------+-----------+---------------------+----------+---------+------------+
1 row in set (0.020 sec)

MariaDB [classicmangos]> 

> select * from broadcast_text where text1 like '%arrows%';
+------+-----------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------+------------+------------+-------------+----------+-------+-----------------+-----------------+----------+----------+----------+-------------+-------------+-------------+---------------+
| Id   | Text                                                                        | Text1                                                                                                    | ChatTypeID | LanguageID | ConditionID | EmotesID | Flags | SoundEntriesID1 | SoundEntriesID2 | EmoteID1 | EmoteID2 | EmoteID3 | EmoteDelay1 | EmoteDelay2 | EmoteDelay3 | VerifiedBuild |
+------+-----------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------+------------+------------+-------------+----------+-------+-----------------+-----------------+----------+----------+----------+-------------+-------------+-------------+---------------+
| 7407 | The Scourge are defeated!  Darrowshire is saved!                            | The Scourge are defeated!  Darrowshire is saved!                                                         |          0 |          0 |           0 |        0 |     1 |               0 |               0 |        0 |        0 |        0 |           0 |           0 |           0 |         31882 |
| 7368 | Horgus is slain!  Take heart, defenders of Darrowshire!                     | Horgus is slain!  Take heart, defenders of Darrowshire!                                                  |          0 |          0 |           0 |        0 |     1 |               0 |               0 |        0 |        0 |        0 |           0 |           0 |           0 |         31882 |
| 7366 | Davil Lightfire is defeated!  Darrowshire is lost!                          | Davil Lightfire is defeated!  Darrowshire is lost!                                                       |          0 |          0 |           0 |        0 |     1 |               0 |               0 |        0 |        0 |        0 |           0 |           0 |           0 |         31882 |
| 7358 | Darrowshire, to arms!  The Scourge approach!                                | Darrowshire, to arms!  The Scourge approach!                                                             |          0 |          0 |           0 |        0 |     1 |               0 |               0 |        0 |        0 |        0 |           0 |           0 |           0 |         31882 |
| 7351 | Do not give up!  Shed your blood for Darrowshire!                           | Do not give up!  Shed your blood for Darrowshire!                                                        |          0 |          0 |           0 |        0 |     1 |               0 |               0 |        0 |        0 |        0 |           0 |           0 |           0 |         31882 |
| 7347 | For Darrowshire!                                                            | For Darrowshire!                                                                                         |          0 |          0 |           0 |        0 |     1 |               0 |               0 |        0 |        0 |        0 |           0 |           0 |           0 |         31882 |
| 7207 | Oh, Darrowshire!  I would give a thousand lives for you!                    | Oh, Darrowshire!  I would give a thousand lives for you!                                                 |          0 |          0 |           0 |        0 |     1 |               0 |               0 |        0 |        0 |        0 |           0 |           0 |           0 |         31882 |
| 7199 |                                                                             | I've run out of arrows! I'm afraid if any more come you will need to take them on by yourself my friend. |          0 |          0 |           0 |        0 |     1 |               0 |               0 |        0 |        0 |        0 |           0 |           0 |           0 |         31882 |
| 6841 | If we fall, then Darrowshire is doomed!                                     | If we fall, then Darrowshire is doomed!                                                                  |          0 |          0 |           0 |        0 |     1 |               0 |               0 |        0 |        0 |        0 |           0 |           0 |           0 |         31882 |
| 6836 | Fight!  Fight for Darrowshire!                                              | Fight!  Fight for Darrowshire!                                                                           |          0 |          0 |           0 |        0 |     1 |               0 |               0 |        0 |        0 |        0 |           0 |           0 |           0 |         31882 |
| 6431 | Ah!  Please, if you see a survivor of Darrowshire, tell them I am free!     | Ah!  Please, if you see a survivor of Darrowshire, tell them I am free!                                  |          0 |          0 |           0 |        0 |     1 |               0 |               0 |        0 |        0 |        0 |           0 |           0 |           0 |         31882 |
| 6430 | Thank you!  The battle for Darrowshire doomed me, but you have set me free! | Thank you!  The battle for Darrowshire doomed me, but you have set me free!                              |          0 |          0 |           0 |        0 |     1 |               0 |               0 |        0 |        0 |        0 |           0 |           0 |           0 |         31882 |
+------+-----------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------+------------+------------+-------------+----------+-------+-----------------+-----------------+----------+----------+----------+-------------+-------------+-------------+---------------+
12 rows in set (0.021 sec)

MariaDB [classicmangos]> 


As we can see, the entry id does not match with the creature id. 

Problem we need to bridge the creature id to the broadcast_text id. 

]> select * from npc_text_broadcast_text limit 10;
+-------+-------+-------+-------+-------+-------+-------+-------+-------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+
| Id    | Prob0 | Prob1 | Prob2 | Prob3 | Prob4 | Prob5 | Prob6 | Prob7 | BroadcastTextId0 | BroadcastTextId1 | BroadcastTextId2 | BroadcastTextId3 | BroadcastTextId4 | BroadcastTextId5 | BroadcastTextId6 | BroadcastTextId7 |
+-------+-------+-------+-------+-------+-------+-------+-------+-------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+
|  7010 |     1 |     0 |     0 |     0 |     0 |     0 |     0 |     0 |             9656 |                0 |                0 |                0 |                0 |                0 |                0 |                0 |
|  7011 |     1 |     0 |     0 |     0 |     0 |     0 |     0 |     0 |             9659 |                0 |                0 |                0 |                0 |                0 |                0 |                0 |
| 60000 |     1 |     0 |     0 |     0 |     0 |     0 |     0 |     0 |             9677 |                0 |                0 |                0 |                0 |                0 |                0 |                0 |
| 60001 |     1 |     0 |     0 |     0 |     0 |     0 |     0 |     0 |             9678 |                0 |                0 |                0 |                0 |                0 |                0 |                0 |
|  4213 |     1 |     0 |     0 |     0 |     0 |     0 |     0 |     0 |             6882 |                0 |                0 |                0 |                0 |                0 |                0 |                0 |
|  8498 |     1 |     0 |     0 |     0 |     0 |     0 |     0 |     0 |            12227 |                0 |                0 |                0 |                0 |                0 |                0 |                0 |
|  8499 |     1 |     0 |     0 |     0 |     0 |     0 |     0 |     0 |            12229 |                0 |                0 |                0 |                0 |                0 |                0 |                0 |
|  8500 |     1 |     0 |     0 |     0 |     0 |     0 |     0 |     0 |            12232 |                0 |                0 |                0 |                0 |                0 |                0 |                0 |
|  8502 |     1 |     0 |     0 |     0 |     0 |     0 |     0 |     0 |            12235 |                0 |                0 |                0 |                0 |                0 |                0 |                0 |
|  8503 |     1 |     0 |     0 |     0 |     0 |     0 |     0 |     0 |            12236 |                0 |                0 |                0 |                0 |                0 |                0 |                0 |
+-------+-------+-------+-------+-------+-------+-------+-------+-------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+
10 rows in set (0.001 sec)

MariaDB [classicmangos]> 


[classicmangos]> -- 1. Check the Scripting Engines
MariaDB [classicmangos]> SELECT 'creature_ai_scripts' as tbl, id, creature_id, event_type, action1_type, action1_param1, comment FROM creature_ai_scripts WHERE creature_id IN (7918, 11711)
    -> UNION ALL
    -> SELECT 'dbscripts_on_creature_movement', id, delay, command, datalong, dataint, comments FROM dbscripts_on_creature_movement WHERE id IN (7918, 11711)
    -> UNION ALL
    -> SELECT 'dbscripts_on_event', id, delay, command, datalong, dataint, comments FROM dbscripts_on_event WHERE id IN (7918, 11711)
    -> UNION ALL
    -> SELECT 'dbscripts_on_gossip', id, delay, command, datalong, dataint, comments FROM dbscripts_on_gossip WHERE id IN (106601, 7918, 11711);
+---------------------+---------+-------------+------------+--------------+----------------+-------------------------------------------------------------------------------+
| tbl                 | id      | creature_id | event_type | action1_type | action1_param1 | comment                                                                       |
+---------------------+---------+-------------+------------+--------------+----------------+-------------------------------------------------------------------------------+
| creature_ai_scripts | 1171101 |       11711 |          4 |           57 |              2 | Sentinel Aynasha - Enable Range Mode on Aggro                                 |
| creature_ai_scripts | 1171102 |       11711 |          0 |            4 |           7339 | Sentinel Aynasha - Random Sound                                               |
| creature_ai_scripts | 1171103 |       11711 |          2 |           25 |              0 | Sentinel Aynasha - Flee at 15% HP                                             |
| creature_ai_scripts | 1171104 |       11711 |          9 |           11 |          19767 | Sentinel Aynasha - Cast Aynasha's Bow                                         |
| creature_ai_scripts |  791801 |        7918 |         11 |           11 |          11011 | Stone Watcher of Norgannon - Cast Stone Watcher of Norgannon Passive on Spawn |
| dbscripts_on_gossip |  106601 |           0 |          7 |         2954 |              0 | quest 2954 explored                                                           |
+---------------------+---------+-------------+------------+--------------+----------------+-------------------------------------------------------------------------------+
6 rows in set (0.011 sec)


!mysql
mysql -u mangos -p classicmangos
Enter password: 
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 243
Server version: 10.11.13-MariaDB-0ubuntu0.24.04.1 Ubuntu 24.04

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- FINDING THE ELUSIVE "I've run out of arrows!" (broadcast_text 7199)
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- First, confirm the text exists
MariaDB [classicmangos]> SELECT * FROM broadcast_text WHERE Id = 7199;
+------+------+----------------------------------------------------------------------------------------------------------+------------+------------+-------------+----------+-------+-----------------+-----------------+----------+----------+----------+-------------+-------------+-------------+---------------+
| Id   | Text | Text1                                                                                                    | ChatTypeID | LanguageID | ConditionID | EmotesID | Flags | SoundEntriesID1 | SoundEntriesID2 | EmoteID1 | EmoteID2 | EmoteID3 | EmoteDelay1 | EmoteDelay2 | EmoteDelay3 | VerifiedBuild |
+------+------+----------------------------------------------------------------------------------------------------------+------------+------------+-------------+----------+-------+-----------------+-----------------+----------+----------+----------+-------------+-------------+-------------+---------------+
| 7199 |      | I've run out of arrows! I'm afraid if any more come you will need to take them on by yourself my friend. |          0 |          0 |           0 |        0 |     1 |               0 |               0 |        0 |        0 |        0 |           0 |           0 |           0 |         31882 |
+------+------+----------------------------------------------------------------------------------------------------------+------------+------------+-------------+----------+-------+-----------------+-----------------+----------+----------+----------+-------------+-------------+-------------+---------------+
1 row in set (0.000 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- QUERY 1: Check ALL script tables for this broadcast_text
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- Check creature_ai_scripts (all action slots)
MariaDB [classicmangos]> SELECT 'creature_ai_scripts' AS source, creature_id, id, event_type, 
    ->        action1_type, action1_param1, action2_type, action2_param2, action3_type, action3_param3, comment
    -> FROM creature_ai_scripts 
    -> WHERE action1_param1 = 7199 OR action1_param2 = 7199 OR action1_param3 = 7199
    ->    OR action2_param1 = 7199 OR action2_param2 = 7199 OR action2_param3 = 7199
    ->    OR action3_param1 = 7199 OR action3_param2 = 7199 OR action3_param3 = 7199;
Empty set (0.003 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- Check dbscripts_on_creature_movement
MariaDB [classicmangos]> SELECT 'dbscripts_on_creature_movement' AS source, id, delay, command, datalong, dataint, comments
    -> FROM dbscripts_on_creature_movement 
    -> WHERE dataint = 7199 OR datalong = 7199;
Empty set (0.001 sec)

MariaDB [classicmangos]> 
eMariaDB [classicmangos]> -- Check dbscripts_on_event
MariaDB [classicmangos]> SELECT 'dbscripts_on_event' AS source, id, delay, command, datalong, dataint, comments
    -> FROM dbscripts_on_event 
    -> WHERE dataint = 7199 OR datalong = 7199;
Empty set (0.000 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> y-- Check dbscripts_on_gossip
MariaDB [classicmangos]> SELECT 'dbscripts_on_gossip' AS source, id, delay, command, datalong, dataint, comments
    -> FROM dbscripts_on_gossip 
    -> WHERE dataint = 7199 OR datalong = 7199;
Empty set (0.000 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- Check dbscripts_on_quest_start
MariaDB [classicmangos]> SELECT 'dbscripts_on_quest_start' AS source, id, delay, command, datalong, dataint, comments
    -> FROM dbscripts_on_quest_start 
    -> WHERE dataint = 7199 OR datalong = 7199;
+--------------------------+------+-------+---------+----------+---------+---------------+
| source                   | id   | delay | command | datalong | dataint | comments      |
+--------------------------+------+-------+---------+----------+---------+---------------+
| dbscripts_on_quest_start | 5713 | 75000 |       0 |        0 |    7199 | say_protect_2 |
+--------------------------+------+-------+---------+----------+---------+---------------+
1 row in set (0.001 sec)

MariaDB [classicmangos]> 
=MariaDB [classicmangos]> -- Check dbscripts_on_quest_end
MariaDB [classicmangos]> SELECT 'dbscripts_on_quest_end' AS source, id, delay, command, datalong, dataint, comments
    -> FROM dbscripts_on_quest_end 
    -> WHERE dataint = 7199 OR datalong = 7199;
Empty set (0.002 sec)

MariaDB [classicmangos]> 
sMariaDB [classicmangos]> -- Check dbscripts_on_spell
MariaDB [classicmangos]> SELECT 'dbscripts_on_spell' AS source, id, delay, command, datalong, dataint, comments
    -> FROM dbscripts_on_spell 
    -> WHERE dataint = 7199 OR datalong = 7199;
Empty set (0.000 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- Check dbscripts_on_go_use
MariaDB [classicmangos]> SELECT 'dbscripts_on_go_use' AS source, id, delay, command, datalong, dataint, comments
    -> FROM dbscripts_on_go_use 
    -> WHERE dataint = 7199 OR datalong = 7199;
Empty set (0.000 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- Check dbscripts_on_go_template_use
MariaDB [classicmangos]> SELECT 'dbscripts_on_go_template_use' AS source, id, delay, command, datalong, dataint, comments
    -> FROM dbscripts_on_go_template_use 
    -> WHERE dataint = 7199 OR datalong = 7199;
Empty set (0.000 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- QUERY 2: Check if it's in npc_text_broadcast_text (gossip)
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> SELECT * FROM npc_text_broadcast_text 
    -> WHERE BroadcastTextId0 = 7199 OR BroadcastTextId1 = 7199 OR BroadcastTextId2 = 7199
    ->    OR BroadcastTextId3 = 7199 OR BroadcastTextId4 = 7199 OR BroadcastTextId5 = 7199
    ->    OR BroadcastTextId6 = 7199 OR BroadcastTextId7 = 7199;
Empty set (0.001 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- QUERY 3: Search for Darrowshire-related content (context from your search)
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- The "arrows" text was in a search about Darrowshire, so let's find that event
MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- Find all Darrowshire NPCs
MariaDB [classicmangos]> SELECT Entry, Name FROM creature_template WHERE Name LIKE '%Darrow%';
+-------+-------------------------+
| Entry | Name                    |
+-------+-------------------------+
| 10947 | Darrowshire Betrayer    |
| 10948 | Darrowshire Defender    |
| 11064 | Darrowshire Spirit      |
| 11277 | Caer Darrow Citizen     |
| 11279 | Caer Darrow Guardsman   |
| 11280 | Caer Darrow Cannoneer   |
| 11281 | Caer Darrow Horseman    |
| 11296 | Darrowshire Poltergeist |
+-------+-------------------------+
8 rows in set (0.004 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- Find Darrowshire quests
MariaDB [classicmangos]> SELECT entry, Title FROM quest_template WHERE Title LIKE '%Darrow%';
+-------+---------------------------+
| entry | Title                     |
+-------+---------------------------+
|  5154 | The Annals of Darrowshire |
|  5168 | Heroes of Darrowshire     |
|  5181 | Villains of Darrowshire   |
|  5206 | Marauders of Darrowshire  |
|  5211 | Defenders of Darrowshire  |
|  5721 | The Battle of Darrowshire |
+-------+---------------------------+
6 rows in set (0.004 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- Find Darrowshire events
MariaDB [classicmangos]> SELECT * FROM game_event WHERE description LIKE '%Darrow%';
Empty set (0.000 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- QUERY 4: Check game_event_scripts (special events)
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> SELECT 'game_event_creature_data' AS source, guid, entry_id 
    -> FROM game_event_creature_data 
    -> WHERE entry_id IN (
    ->     SELECT creature_id FROM creature_ai_scripts 
    ->     WHERE action1_param1 = 7199 OR action2_param1 = 7199 OR action3_param1 = 7199
    -> );
Empty set (0.004 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- QUERY 5: Search for event-based broadcast_text
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- Some texts only appear during special events
MariaDB [classicmangos]> SELECT DISTINCT bt.Id, bt.Text, bt.Text1, ct.Entry, ct.Name
    -> FROM broadcast_text bt
    -> LEFT JOIN creature_ai_scripts cas ON (
    ->     bt.Id = cas.action1_param1 OR bt.Id = cas.action2_param1 OR bt.Id = cas.action3_param1
    -> )
    -> LEFT JOIN creature_template ct ON ct.Entry = cas.creature_id
    -> WHERE bt.Id BETWEEN 7190 AND 7210  -- Range around 7199
    -> ORDER BY bt.Id;
+------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------+-------+------+
| Id   | Text                                                                                                                                                            | Text1                                                                                                                                              | Entry | Name |
+------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------+-------+------+
| 7190 | We await a batch of black dragon eggs from the Burning Steppes.  We believe that, through their study, we will advance our knowledge dramatically.              |                                                                                                                                                    |  NULL | NULL |
| 7191 | Our oldest clutch of dragons are still far from maturity, but with patience and study, we are confident the dragonflight will soon be ready.                    |                                                                                                                                                    |  NULL | NULL |
| 7192 | From yesterday's field trip, Marduk showed us that the dragons will tolerate the meat of recently killed humanoids, but only if they died slowly and painfully. |                                                                                                                                                    |  NULL | NULL |
| 7193 | Tomorrow we will begin training of our promising dragons, so don't forget your chew toys.                                                                       |                                                                                                                                                    |  NULL | NULL |
| 7194 | The Lich King's forces are building.  It is imperative that our timetable supports his plans.                                                                   |                                                                                                                                                    |  NULL | NULL |
| 7195 | When preparing the dragon's meal, be sure to torture the prisoner in view of the dragon.  It responds well to pre-meal entertainment.                           |                                                                                                                                                    |  NULL | NULL |
| 7196 | This kodo sure looks nothing like the beast I originally lured!  I wonder if the kombobulator can be used on me.                                                | This kodo sure looks nothing like the beast I originally lured!  I wonder if the kombobulator can be used on me.                                   |  NULL | NULL |
| 7197 |                                                                                                                                                                 | The plaguelands are an excellent place to strike against the Scourge!                                                                              |  NULL | NULL |
| 7198 | May I have another Dawn's Gambit, Betina?  I want to test it again...                                                                                           | May I have another Dawn's Gambit, Betina?  I want to test it again...                                                                              |  NULL | NULL |
| 7199 |                                                                                                                                                                 | I've run out of arrows! I'm afraid if any more come you will need to take them on by yourself my friend.                                           |  NULL | NULL |
| 7200 |                                                                                                                                                                 | Wait... did you hear that? Something approaches from the west!                                                                                     |  NULL | NULL |
| 7201 |                                                                                                                                                                 | Praise Elune! I don't know if I could have survived the day without you, friend.                                                                   |  NULL | NULL |
| 7202 |                                                                                                                                                                 | My leg feels much better now, the remedy must be working. If you will excuse me, I must go report to my superiors about what has transpired here.
 |  NULL | NULL |
| 7203 | Who dares to challenge me in my domain?!                                                                                                                        |                                                                                                                                                    |  NULL | NULL |
| 7204 |                                                                                                                                                                 | I just fired an arrow.                                                                                                                             |  NULL | NULL |
| 7205 | End our suffering!                                                                                                                                              | End our suffering!                                                                                                                                 |  NULL | NULL |
| 7206 | You must save him!                                                                                                                                              | You must save him!                                                                                                                                 |  NULL | NULL |
| 7207 | Oh, Darrowshire!  I would give a thousand lives for you!                                                                                                        | Oh, Darrowshire!  I would give a thousand lives for you!                                                                                           |  NULL | NULL |
| 7208 | Do not fail us!                                                                                                                                                 | Do not fail us!                                                                                                                                    |  NULL | NULL |
| 7209 | The Light must prevail!                                                                                                                                         | The Light must prevail!                                                                                                                            |  NULL | NULL |
| 7210 | Beware Marduk!  Beware, or your strength will wither.                                                                                                           | Beware Marduk!  Beware, or your strength will wither.                                                                                              |  NULL | NULL |
+------+-----------------------------------------------------------------------------------------------------------------------------------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------+-------+------+
21 rows in set (0.042 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- QUERY 6: Check if Sentinel Aynasha has multiple AI script entries
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- Maybe she has a different AI script during a special event
MariaDB [classicmangos]> SELECT * FROM creature_ai_scripts WHERE creature_id = 11711;
+---------+-------------+------------+--------------------------+--------------+-------------+--------------+--------------+--------------+--------------+--------------+--------------+--------------+----------------+----------------+----------------+--------------+----------------+----------------+----------------+--------------+----------------+----------------+----------------+-----------------------------------------------+
| id      | creature_id | event_type | event_inverse_phase_mask | event_chance | event_flags | event_param1 | event_param2 | event_param3 | event_param4 | event_param5 | event_param6 | action1_type | action1_param1 | action1_param2 | action1_param3 | action2_type | action2_param1 | action2_param2 | action2_param3 | action3_type | action3_param1 | action3_param2 | action3_param3 | comment                                       |
+---------+-------------+------------+--------------------------+--------------+-------------+--------------+--------------+--------------+--------------+--------------+--------------+--------------+----------------+----------------+----------------+--------------+----------------+----------------+----------------+--------------+----------------+----------------+----------------+-----------------------------------------------+
| 1171101 |       11711 |          4 |                        0 |          100 |           0 |            0 |            0 |            0 |            0 |            0 |            0 |           57 |              2 |             25 |              0 |            0 |              0 |              0 |              0 |            0 |              0 |              0 |              0 | Sentinel Aynasha - Enable Range Mode on Aggro |
| 1171102 |       11711 |          0 |                        0 |           30 |        1025 |        15000 |        30000 |        30000 |        60000 |            0 |            0 |            4 |           7339 |              0 |              0 |            0 |              0 |              0 |              0 |            0 |              0 |              0 |              0 | Sentinel Aynasha - Random Sound               |
| 1171103 |       11711 |          2 |                        0 |          100 |        1024 |           15 |            0 |            0 |            0 |            0 |            0 |           25 |              0 |              0 |              0 |            1 |           1150 |              0 |              0 |            0 |              0 |              0 |              0 | Sentinel Aynasha - Flee at 15% HP             |
| 1171104 |       11711 |          9 |                        0 |          100 |        1025 |            0 |           30 |         2300 |         3900 |            0 |            0 |           11 |          19767 |              1 |            256 |            0 |              0 |              0 |              0 |            0 |              0 |              0 |              0 | Sentinel Aynasha - Cast Aynasha's Bow         |
+---------+-------------+------------+--------------------------+--------------+-------------+--------------+--------------+--------------+--------------+--------------+--------------+--------------+----------------+----------------+----------------+--------------+----------------+----------------+----------------+--------------+----------------+----------------+----------------+-----------------------------------------------+
4 rows in set (0.003 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- QUERY 7: Check for conditional AI scripts
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- Some NPCs use different scripts based on conditions
MariaDB [classicmangos]> SELECT 
    ->     ct.Entry, 
    ->     ct.Name, 
    ->     ct.AIName,
    ->     cas.*
    -> FROM creature_template ct
    -> LEFT JOIN creature_ai_scripts cas ON cas.creature_id = ct.Entry
    -> WHERE ct.Entry = 11711;
+-------+------------------+---------+---------+-------------+------------+--------------------------+--------------+-------------+--------------+--------------+--------------+--------------+--------------+--------------+--------------+----------------+----------------+----------------+--------------+----------------+----------------+----------------+--------------+----------------+----------------+----------------+-----------------------------------------------+
| Entry | Name             | AIName  | id      | creature_id | event_type | event_inverse_phase_mask | event_chance | event_flags | event_param1 | event_param2 | event_param3 | event_param4 | event_param5 | event_param6 | action1_type | action1_param1 | action1_param2 | action1_param3 | action2_type | action2_param1 | action2_param2 | action2_param3 | action3_type | action3_param1 | action3_param2 | action3_param3 | comment                                       |
+-------+------------------+---------+---------+-------------+------------+--------------------------+--------------+-------------+--------------+--------------+--------------+--------------+--------------+--------------+--------------+----------------+----------------+----------------+--------------+----------------+----------------+----------------+--------------+----------------+----------------+----------------+-----------------------------------------------+
| 11711 | Sentinel Aynasha | EventAI | 1171101 |       11711 |          4 |                        0 |          100 |           0 |            0 |            0 |            0 |            0 |            0 |            0 |           57 |              2 |             25 |              0 |            0 |              0 |              0 |              0 |            0 |              0 |              0 |              0 | Sentinel Aynasha - Enable Range Mode on Aggro |
| 11711 | Sentinel Aynasha | EventAI | 1171102 |       11711 |          0 |                        0 |           30 |        1025 |        15000 |        30000 |        30000 |        60000 |            0 |            0 |            4 |           7339 |              0 |              0 |            0 |              0 |              0 |              0 |            0 |              0 |              0 |              0 | Sentinel Aynasha - Random Sound               |
| 11711 | Sentinel Aynasha | EventAI | 1171103 |       11711 |          2 |                        0 |          100 |        1024 |           15 |            0 |            0 |            0 |            0 |            0 |           25 |              0 |              0 |              0 |            1 |           1150 |              0 |              0 |            0 |              0 |              0 |              0 | Sentinel Aynasha - Flee at 15% HP             |
| 11711 | Sentinel Aynasha | EventAI | 1171104 |       11711 |          9 |                        0 |          100 |        1025 |            0 |           30 |         2300 |         3900 |            0 |            0 |           11 |          19767 |              1 |            256 |            0 |              0 |              0 |              0 |            0 |              0 |              0 |              0 | Sentinel Aynasha - Cast Aynasha's Bow         |
+-------+------------------+---------+---------+-------------+------------+--------------------------+--------------+-------------+--------------+--------------+--------------+--------------+--------------+--------------+--------------+----------------+----------------+----------------+--------------+----------------+----------------+----------------+--------------+----------------+----------------+----------------+-----------------------------------------------+
4 rows in set (0.003 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- QUERY 8: Check creature spawns for this NPC
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- Maybe different spawns use different scripts
MariaDB [classicmangos]> SELECT * FROM creature WHERE id = 11711;
+-------+-------+-----+-----------+---------------------------+--------------------------+-------------------------+------------------------+------------------+------------------+-----------+--------------+
| guid  | id    | map | spawnMask | position_x                | position_y               | position_z              | orientation            | spawntimesecsmin | spawntimesecsmax | spawndist | MovementType |
+-------+-------+-----+-----------+---------------------------+--------------------------+-------------------------+------------------------+------------------+------------------+-----------+--------------+
| 38663 | 11711 |   1 |         1 | 4390.68017578125000000000 | -67.31199645996094000000 | 86.71769714355469000000 | 2.32129001617431640000 |              275 |              275 |         0 |            0 |
+-------+-------+-----+-----------+---------------------------+--------------------------+-------------------------+------------------------+------------------+------------------+-----------+--------------+
1 row in set (0.001 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> -- QUERY 9: Full text search for "arrows" in all script comments
MariaDB [classicmangos]> -- =============================================================================
MariaDB [classicmangos]> SELECT 'creature_ai_scripts' AS source, creature_id, comment
    -> FROM creature_ai_scripts 
    -> WHERE comment LIKE '%arrow%'
    -> UNION ALL
    -> SELECT 'dbscripts_on_creature_movement', id, comments
    -> FROM dbscripts_on_creature_movement 
    -> WHERE comments LIKE '%arrow%'
    -> UNION ALL
    -> SELECT 'dbscripts_on_event', id, comments
    -> FROM dbscripts_on_event 
    -> WHERE comments LIKE '%arrow%';
+---------------------+-------------+-----------------------------------------------------------------------------------------------------------------------+
| source              | creature_id | comment                                                                                                               |
+---------------------+-------------+-----------------------------------------------------------------------------------------------------------------------+
| creature_ai_scripts |        8530 | Cannibal Ghoul - Cast Summon Darrowshire Spirit on Death                                                              |
| creature_ai_scripts |        8531 | Gibbering Ghoul - Cast Summon Darrowshire Spirit on Death                                                             |
| creature_ai_scripts |        8532 | Diseased Flayer - Cast Summon Darrowshire Spirit on Death                                                             |
| creature_ai_scripts |       10947 | Darrowshire Betrayer - Cast Wither Strike                                                                             |
| creature_ai_scripts |       10948 | Darrowshire Defender - Cast Strike                                                                                    |
| creature_ai_scripts |       10948 | Darrowshire Defender - Cast Shield Block                                                                              |
| creature_ai_scripts |       11064 | Darrowshire Spirit - Cast Spirit Spawn-in, Spirit Particles on Spawn                                                  |
| creature_ai_scripts |       11277 | Caer Darrow Citizen - Cast Shroud of Death, Caer Darrow Ghosts on Spawn                                               |
| creature_ai_scripts |       11278 | Magnus Frostwake - Cast Shroud of Death, Caer Darrow Ghosts on Spawn                                                  |
| creature_ai_scripts |       11279 | Caer Darrow Guardsman - Cast Shroud of Death, Caer Darrow Ghosts on Spawn                                             |
| creature_ai_scripts |       11280 | Caer Darrow Cannoneer - Cast Shroud of Death, Caer Darrow Ghosts on Spawn                                             |
| creature_ai_scripts |       11281 | Caer Darrow Horseman - Cast Caer Darrow Ghosts on Spawn                                                               |
| creature_ai_scripts |       11282 | Melia - Cast Shroud of Death, Caer Darrow Ghosts on Spawn                                                             |
| creature_ai_scripts |       11283 | Sammy - Cast Shroud of Death, Caer Darrow Ghosts on Spawn                                                             |
| creature_ai_scripts |       11285 | Rory - Cast Shroud of Death, Caer Darrow Ghosts on Spawn                                                              |
| creature_ai_scripts |       11286 | Magistrate Marduke - Cast Shroud of Death, Caer Darrow Ghosts on Spawn                                                |
| creature_ai_scripts |       11287 | Baker Masterson - Cast Shroud of Death, Caer Darrow Ghosts on Spawn                                                   |
| creature_ai_scripts |       11296 | Darrowshire Poltergeist - Cast Spirit Particles, Poltergeist Periodic Schedule, Poltergeist Despawn Schedule on Spawn |
| creature_ai_scripts |       11296 | Darrowshire Poltergeist - Set Passive State and Random Say on Spawn                                                   |
| creature_ai_scripts |       11316 | Joseph Dirte - Cast Shroud of Death, Caer Darrow Ghosts on Spawn                                                      |
| creature_ai_scripts |        7999 | Tyrande Whisperwind - Cast Searing Arrow                                                                              |
| creature_ai_scripts |       14695 | Lord Blackwood - Cast Black Arrow                                                                                     |
+---------------------+-------------+-----------------------------------------------------------------------------------------------------------------------+
22 rows in set (0.008 sec)

MariaDB [classicmangos]> 

> SELECT 
    ->     qt.entry AS quest_id,
    ->     qt.Title AS quest_title,
    ->     cqr.id AS quest_giver_npc_id,
    ->     ct.Name AS quest_giver_name
    -> FROM quest_template qt
    -> LEFT JOIN creature_questrelation cqr ON cqr.quest = qt.entry
    -> LEFT JOIN creature_template ct ON ct.Entry = cqr.id
    -> WHERE qt.entry = 5713;
+----------+---------------------+--------------------+------------------+
| quest_id | quest_title         | quest_giver_npc_id | quest_giver_name |
+----------+---------------------+--------------------+------------------+
|     5713 | One Shot. One Kill. |              11711 | Sentinel Aynasha |
+----------+---------------------+--------------------+------------------+
1 row in set (0.001 sec)

MariaDB [classicmangos]> 
MariaDB [classicmangos]> -- Also check the full quest start script
MariaDB [classicmangos]> SELECT * FROM dbscripts_on_quest_start WHERE id = 5713 ORDER BY delay;
+------+--------+----------+---------+----------+-----------+-----------+-------------+---------------+------------+---------+----------+----------+----------+-----------+---------+---------+-------+---+-------+--------------+-----------------------------------------------+
| id   | delay  | priority | command | datalong | datalong2 | datalong3 | buddy_entry | search_radius | data_flags | dataint | dataint2 | dataint3 | dataint4 | datafloat | x       | y       | z     | o | speed | condition_id | comments                                      |
+------+--------+----------+---------+----------+-----------+-----------+-------------+---------------+------------+---------+----------+----------+----------+-----------+---------+---------+-------+---+-------+--------------+-----------------------------------------------+
| 5713 |      0 |        0 |       0 |        0 |         0 |         0 |           0 |             0 |          0 |    7200 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | say_protect_1                                 |
| 5713 |   5000 |        0 |      10 |    11713 |     60000 |         0 |           0 |             0 |          0 |       0 |        0 |        0 |        0 |         0 | 4371.17 | -11.965 | 67.64 | 0 |     0 |            0 | summon first wave                             |
| 5713 |   5000 |        0 |      10 |    11713 |     60000 |         0 |           0 |             0 |          0 |       0 |        0 |        0 |        0 |         0 | 4368.29 | -13.418 | 67.81 | 0 |     0 |            0 | summon first wave                             |
| 5713 |  50000 |        0 |      34 |      317 |      5713 |         0 |           0 |             0 |          0 |       0 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | Stop script if player is dead or out of range |
| 5713 |  50000 |        0 |      34 |      318 |      5713 |         0 |           0 |             0 |          0 |       0 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | Stop script if npc is dead                    |
| 5713 |  55000 |        0 |      10 |    11713 |     60000 |         0 |           0 |             0 |          0 |       0 |        0 |        0 |        0 |         0 | 4368.86 | -15.438 | 68.36 | 0 |     0 |            0 | summon second wave                            |
| 5713 |  55000 |        0 |      10 |    11713 |     60000 |         0 |           0 |             0 |          0 |       0 |        0 |        0 |        0 |         0 | 4368.29 | -13.418 | 67.81 | 0 |     0 |            0 | summon second wave                            |
| 5713 |  55000 |        0 |      10 |    11713 |     60000 |         0 |           0 |             0 |          0 |       0 |        0 |        0 |        0 |         0 | 4371.17 | -11.965 | 67.64 | 0 |     0 |            0 | summon second wave                            |
| 5713 |  70000 |        0 |      34 |      317 |      5713 |         0 |           0 |             0 |          0 |       0 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | Stop script if player is dead or out of range |
| 5713 |  70000 |        0 |      34 |      318 |      5713 |         0 |           0 |             0 |          0 |       0 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | Stop script if npc is dead                    |
| 5713 |  75000 |        0 |      10 |    11714 |     60000 |         0 |           0 |             0 |          0 |       0 |        0 |        0 |        0 |         0 | 4371.17 | -11.965 | 67.64 | 0 |     0 |            0 | summon third wave                             |
| 5713 |  75000 |        0 |       0 |        0 |         0 |         0 |           0 |             0 |          0 |    7199 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | say_protect_2                                 |
| 5713 | 160000 |        0 |      34 |      317 |      5713 |         0 |           0 |             0 |          0 |       0 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | Stop script if player is dead or out of range |
| 5713 | 160000 |        0 |      34 |      318 |      5713 |         0 |           0 |             0 |          0 |       0 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | Stop script if npc is dead                    |
| 5713 | 165000 |        0 |       7 |     5713 |         0 |         0 |           0 |             0 |          0 |       0 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | quest complete                                |
| 5713 | 168000 |        0 |       0 |        0 |         0 |         0 |           0 |             0 |          0 |    7201 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | say_protect_3                                 |
| 5713 | 170000 |        0 |       0 |        0 |         0 |         0 |           0 |             0 |          0 |    7202 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | say_protect_4                                 |
| 5713 | 173000 |        0 |       0 |        0 |         0 |         0 |           0 |             0 |          0 |    7328 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | say_protect_5                                 |
| 5713 | 175000 |        0 |      25 |        1 |         0 |         0 |           0 |             0 |          4 |       0 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | set run on                                    |
| 5713 | 175000 |        0 |      20 |        2 |         0 |         0 |           0 |             0 |          4 |       0 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | start wp move                                 |
| 5713 | 175000 |        0 |      18 |    20000 |         0 |         0 |           0 |             0 |          4 |       0 |        0 |        0 |        0 |         0 |       0 |       0 |     0 | 0 |     0 |            0 | despawn on timer                              |
+------+--------+----------+---------+----------+-----------+-----------+-------------+---------------+------------+---------+----------+----------+----------+-----------+---------+---------+-------+---+-------+--------------+-----------------------------------------------+
21 rows in set (0.001 sec)

MariaDB [classicmangos]> 
select * from db_CreatureDisplayInfo            |
    -> ^C
MariaDB [classicmangos]> select * from db_CreatureDisplayInfo  limit 1;  
+----+---------+---------+-----------------------+--------------------+--------------------+--------------------+--------------------+--------------------+---------------------+------------+---------+------------+-----------------+--------------------+-----------------------+
| ID | ModelID | SoundID | ExtendedDisplayInfoID | CreatureModelScale | CreatureModelAlpha | TextureVariation_1 | TextureVariation_2 | TextureVariation_3 | PortraitTextureName | BloodLevel | BloodID | NPCSoundID | ParticleColorID | CreatureGeosetData | ObjectEffectPackageID |
+----+---------+---------+-----------------------+--------------------+--------------------+--------------------+--------------------+--------------------+---------------------+------------+---------+------------+-----------------+--------------------+-----------------------+
|  4 |       4 |       0 |                     0 |                  1 |                255 |                    |                    |                    |                     |          1 |       0 |          0 |               0 |                  0 |                     0 |
+----+---------+---------+-----------------------+--------------------+--------------------+--------------------+--------------------+--------------------+---------------------+------------+---------+------------+-----------------+--------------------+-----------------------+
1 row in set (0.001 sec)

MariaDB [classicmangos]> select count(*) from db_CreatureDisplayInfo  limit 1;
+----------+
| count(*) |
+----------+
|    24262 |
+----------+
1 row in set (0.000 sec)

MariaDB [classicmangos]> select count(*) from db_CreatureDisplayInfoExtra  limit 1;
+----------+
| count(*) |
+----------+
|    15475 |
+----------+
1 row in set (0.000 sec)

MariaDB [classicmangos]> select * from db_CreatureDisplayInfoExtra  limit 1;
+----+---------------+--------------+--------+--------+-------------+-------------+--------------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+-------------------+-------------------+-------+--------------------------------------+
| ID | DisplayRaceID | DisplaySexID | SkinID | FaceID | HairStyleID | HairColorID | FacialHairID | NPCItemDisplay_1 | NPCItemDisplay_2 | NPCItemDisplay_3 | NPCItemDisplay_4 | NPCItemDisplay_5 | NPCItemDisplay_6 | NPCItemDisplay_7 | NPCItemDisplay_8 | NPCItemDisplay_9 | NPCItemDisplay_10 | NPCItemDisplay_11 | Flags | BakeName                             |
+----+---------------+--------------+--------+--------+-------------+-------------+--------------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+-------------------+-------------------+-------+--------------------------------------+
| 23 |             3 |            0 |      1 |      1 |           6 |           3 |            2 |             8815 |             8815 |             3900 |                0 |             8328 |             5848 |             8816 |                0 |             3052 |                 0 |                 0 |     0 | 973e54e79012eea3f2658f2897e681d9.blp |
+----+---------------+--------------+--------+--------+-------------+-------------+--------------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+------------------+-------------------+-------------------+-------+--------------------------------------+
1 row in set (0.001 sec)

MariaDB [classicmangos]> 

> SELECT   ct.Entry,   ct.Name,   d.id AS script_id,   d.command,   d.dataint AS broadcast_id,   b.Text FROM dbscripts_on_creature_movement d JOIN creature_template ct ON ct.Entry = FLOOR(d.id / 100) LEFT JOIN broadcast_text b ON b.Id = d.dataint WHERE d.command IN (0,1,2,6,7,15) ORDER BY ct.Name;
+-------+------------------------------+-----------+---------+--------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Entry | Name                         | script_id | command | broadcast_id | Text                                                                                                                                                                                                                                                                                                                                                                     |
+-------+------------------------------+-----------+---------+--------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|  1478 | Aedis Brom                   |    147801 |       0 |          431 | Hey Reese, give me an' Christoph another round.                                                                                                                                                                                                                                                                                                                          |
|  1478 | Aedis Brom                   |    147802 |       0 |          432 | A warm tavern and a cold ale. What more could we ask for?                                                                                                                                                                                                                                                                                                                |
| 11056 | Alchemist Arbington          |   1105601 |       0 |         7279 | It's done $N, and I think you'll be satisfied with the results.                                                                                                                                                                                                                                                                                                          |
| 15381 | Anachronos the Ancient       |   1538101 |       1 |            0 | NULL                                                                                                                                                                                                                                                                                                                                                                     |
| 15381 | Anachronos the Ancient       |   1538101 |       1 |            0 | NULL                                                                                                                                                                                                                                                                                                                                                                     |
| 15381 | Anachronos the Ancient       |   1538101 |       1 |            0 | NULL                                                                                                                                                                                                                                                                                                                                                                     |
| 15381 | Anachronos the Ancient       |   1538101 |       0 |        10909 | We must act quickly or all shall be lost!                                                                                                                                                                                                                                                                                                                                |
| 15381 | Anachronos the Ancient       |   1538101 |       1 |            0 | NULL                                                                                                                                                                                                                                                                                                                                                                     |
| 15381 | Anachronos the Ancient       |   1538101 |       1 |            0 | NULL                                                                                                                                                                                                                                                                                                                                                                     |
| 15381 | Anachronos the Ancient       |   1538101 |       1 |            0 | NULL                                                                                                                                                                                                                                                                                                                                                                     |
| 15381 | Anachronos the Ancient       |   1538101 |       1 |            0 | NULL                                                                                                                                                                                                                                                                                                                                                                     |
| 15381 | Anachronos the Ancient       |   1538101 |       0 |        10910 | My forces cannot overcome the Qiraji defenses. We will not be able to get close enough to place your precious barrier, dragon. 

## Core Components

### 1. **QuestFrame.lua** - Quest Dialog Handler
**Purpose:** Handles all quest-related UI interactions

**Responsibilities:**
1. Format quest window layout and styling
2. Look up NPC portrait and call PortraitManager to display it
3. Extract NPC name and dialog text
4. Call SoundQueue to play voice-over audio for quest dialog

**Entry Points:**
- `QUEST_GREETING` - Quest giver shows available quests
- `QUEST_DETAIL` - Player views quest details before accepting
- `QUEST_PROGRESS` - Player returns with incomplete quest
- `QUEST_COMPLETE` - Player turns in completed quest

---

### 2. **GossipFrame.lua** - Gossip Dialog Handler
**Purpose:** Handles NPC gossip/conversation UI

**Responsibilities:**
1. Format gossip window layout and styling
2. Look up NPC portrait and call PortraitManager to display it
3. Extract NPC name and gossip text
4. Call SoundQueue to play voice-over audio for gossip dialog

**Entry Points:**
- `GOSSIP_SHOW` - NPC gossip window opens

---

### 3. **Book.lua** - Item Dialog Handler
**Purpose:** Handles readable item/book UI (letters, notes, books)

**Responsibilities:**
1. Format item reading window layout and styling
2. Look up NPC portrait (if applicable) and call PortraitManager to display it
3. Extract item name and text content
4. Call SoundQueue to play voice-over audio for item text

**Entry Points:**
- Item use events for readable objects

---

### 4. **PortraitManager.lua** - Portrait Display System
**Purpose:** Central portrait management and rendering

**Responsibilities:**
1. Load portrait configuration from `portrait_config.lua`
2. Map NPC names to portrait file paths
3. Provide `FindNPCPortraitByKey(npcName)` function
4. Return portrait texture path or default fallback
5. Handle missing/invalid portraits gracefully

**Key Function:**
```lua
FindNPCPortraitByKey(key) → returns texture path
```

**Data Sources:**
- `data/portrait_config.lua` - Portrait file mappings
- `portraits/` directory - Actual portrait image files

---

### 5. **SoundQueue.lua** - Audio Playback System
**Purpose:** Manage voice-over audio playback

**Responsibilities:**
1. Accept `(npcName, dialogText)` from UI handlers
2. Look up sound file path in `npc_dialog_map.lua`
3. Play audio file using WoW's `PlaySoundFile()` API
4. Handle sound not found gracefully (silent fallback)
5. Manage currently playing sound state

**Key Function:**
```lua
AddSound(npcName, dialogText) → looks up and plays sound
```

**Data Sources:**
- `data/npc_dialog_map.lua` - Maps (NPC + text) to sound file paths
- `sounds/` directory - Actual audio files (.ogg format)

**Current Issues (BROKEN):**
- Sound lookup from `npc_dialog_map.lua` is not functioning
- Text normalization may not match dictionary keys correctly
- Sound playback may fail silently

---

## Data Files

### 6. **data/npc_dialog_map.lua**
**Purpose:** Dictionary mapping dialog to sound files

**Format:**
```lua
NPC_DIALOG_MAP = {
    ["npc_name + normalized_text_hash"] = "sounds/path/to/file.ogg"
}
```

**Usage:** SoundQueue uses this to find audio files

---

### 7. **data/npc_data.lua**
**Purpose:** NPC metadata storage

**Contains:**
- NPC names
- Portrait references
- Quest associations
- Other NPC-specific data

---

### 8. **data/portrait_config.lua**
**Purpose:** Portrait file path mappings

**Format:**
```lua
PORTRAIT_CONFIG = {
    NPC_PORTRAITS = {
        ["npc_key"] = "Interface\\AddOns\\BetterQuest\\portraits\\npc.tga",
        ...
    },
    DEFAULT_NPC = "Interface\\Icons\\INV_Misc_QuestionMark"
}
```

---

## System Flow

### Quest Dialog Flow
1. Player talks to quest NPC
2. WoW fires `QUEST_DETAIL` event
3. **QuestFrame.lua** captures event:
   - Extracts NPC name via `UnitName("npc")`
   - Extracts quest text via `GetQuestText()`
   - Calls `PortraitManager:FindNPCPortraitByKey(npcName)`
   - Displays portrait in UI
   - Calls `SoundQueue:AddSound(npcName, questText)`
4. **SoundQueue.lua** processes:
   - Normalizes dialog text
   - Looks up `npcName + normalizedText` in `npc_dialog_map.lua`
   - Plays sound file if found

### Gossip Dialog Flow
(Same as Quest, but triggered by `GOSSIP_SHOW` event and uses `GetGossipText()`)

### Item Dialog Flow
(Same pattern, but for readable items)

---

## Simplification Plan

### Problems with Current Architecture
1. **Utils.lua** - Utility functions scattered, adds complexity
2. **SoundQueueUI.lua** - UI layer too early, complicates debugging
3. **VOIntegration.lua** - Extra abstraction layer, not needed

### Recommended Simplification

**SoundQueue.lua should be self-contained:**
```lua
-- SoundQueue.lua (simplified)
SoundQueue = {}

function SoundQueue:AddSound(npcName, dialogText)
    -- 1. Normalize text
    local normalizedText = self:NormalizeText(dialogText)
    
    -- 2. Create lookup key
    local key = npcName .. "_" .. normalizedText
    
    -- 3. Find sound file in NPC_DIALOG_MAP
    local soundPath = NPC_DIALOG_MAP[key]
    
    -- 4. Play sound if found
    if soundPath then
        PlaySoundFile(soundPath, "Dialog")
    end
end

function SoundQueue:NormalizeText(text)
    -- Remove WoW tokens, punctuation, normalize whitespace
    -- Return lowercase normalized string
end
```

**Remove these files:**
- `Utils.lua` - Move needed functions into SoundQueue
- `SoundQueueUI.lua` - Add UI later once core works
- `VOIntegration.lua` - Event handling already in Frame files

---

## Current Status

### Working ✅
- Quest window formatting
- Gossip window formatting
- Portrait display system
- Portrait file loading

### Broken ❌
- Sound file lookup in `npc_dialog_map.lua`
- Audio playback from sound queue
- Text normalization matching

### Not Implemented ⏸️
- Sound queue UI
- Pause/resume functionality
- Multiple sound queuing

---

## Development Priorities

1. **Fix sound lookup** - Ensure `npc_dialog_map.lua` keys match normalized text
2. **Simplify SoundQueue** - Remove dependencies on Utils/UI/VOIntegration
3. **Debug audio playback** - Add logging to track file paths and playback success
4. **Add UI later** - Once core audio works, add visual queue display

---

## Debugging Tips

### Check if sound files exist:
```lua
print("Sound path: " .. soundPath)
local exists = PlaySoundFile(soundPath, "Dialog")
print("Play success: " .. tostring(exists))
```

### Verify npc_dialog_map lookup:
```lua
print("Looking up key: " .. key)
print("Found path: " .. tostring(NPC_DIALOG_MAP[key]))
```

### Test text normalization:
```lua
local original = GetQuestText()
local normalized = SoundQueue:NormalizeText(original)
print("Original: " .. original)
print("Normalized: " .. normalized)
```

---

## File Structure
```
BetterQuest/
├── BetterQuest.toc          # Addon manifest
├── BetterQuest.xml          # UI XML definitions
├── Config.lua               # Addon configuration
├── QuestFrame.lua           # Quest dialog handler ⭐
├── GossipFrame.lua          # Gossip dialog handler ⭐
├── Book.lua                 # Item dialog handler ⭐
├── PortraitManager.lua      # Portrait system ⭐
├── SoundQueue.lua           # Audio playback system ⭐
├── data/
│   ├── npc_dialog_map.lua   # Sound file lookup table
│   ├── npc_data.lua         # NPC metadata
│   └── portrait_config.lua  # Portrait file paths
├── portraits/               # Portrait images
└── sounds/                  # Voice-over audio files
```

⭐ = Core component

---

## Next Steps

1. Simplify `SoundQueue.lua` - remove all dependencies
2. Add debug logging to track sound lookup
3. Verify `npc_dialog_map.lua` key format matches normalized text
4. Test with single NPC/quest to confirm audio plays
5. Once working, re-add UI components

## High Level Design

#TODO:

human: done
dwarf: done
gnome: done
night_elf: done
orc: done
troll: done
tauren: done
undead: done
goblin: done
blood_elf: done
dragon: done
mechanical: done
spirit: done
elemental: done
centaur: centaur
qiraji: done
naga: done
ogre: done
demon: done
wisp: done
furbolg: 
animal: done
construct: done
object: done


### Gossip Frame

Current issues
padding between the portrait and the npc icon is too big



### Extraction Compoennt:

Pulls data from cmangos linking 
For NPCs
NPC Name, sex, quests, objectives text, gossip, progress, and completion text 
as well as model display information for generic NPCs alliance guard could be male, human dwarf etc. 

Optional (will fill in later) race

For items
item description, item name, 

Example:
npc_id,npc_name,race_mask,sex,model_id,dialog_type,quest_id,text
240,Marshal Dughan,,0,1985,gossip,,"Ach, it's hard enough keeping order around here without all these new troubles popping up!  I hope you have good news, $n..."
item_18708,Petrified Bark,,,,item_text,0,Simone the Seductress:$B$BYou will find Simone befouling Un'Goro Crater. Do not be fooled by her disguise. Approach her with caution and challenge her to battle.

### Processing component
Using llm roughly fill out missing information in a manner to help assign narrator to generator and lookup in game
Strings should be easy to combine into the information below and not too much context window 

name:Marshal Dughan
race: "human"
sex: "male"
dialog_type: gossip
text: "foobar"
zone: "Elwyn Forest"
narrator: "default"
portrait: "human" //optional could be fine tuned/generic at first guard, king, wizard etc. 

name:King of Stormwind
race: "human"
sex: "male"
dialog_type: gossip
text: "foobar"
narrator: "sean bean"
model id or guid if needed

etc.


This is also mirrored in lua for in game lookup based on name to find voice file location

### Generator

Objectives:
- given NPC, generate a voice that is stored in an easily lookable table
- given cli command, regenerate/generate for the first time based on condition
- uses neurtts to generate the 


Two lua components:

## Voice Over

Config.lua
Houses all numeric constant values which are magic numbers and should be the source of truth for all 
variable assignments (numbers,strings, etc)

SoundQueue.lua
push/pop audio with frame to skip and show mini portrait of speaker

QuestFrame.lua 

Better quest frame with portrait of speaker central, wide, already implemented in better quest text 
Get voice over and add it to the voice queue

GossipFrame.lua
Same as questframe but for gossip

Book.lua 
Same for quest frame but for book/openable quest text

db/*.lua
lookup tables for name-> portrait, voice over information

BetterQuest.xml stores load order and all files loaded in addon

---

## 📋 Quick Reference

### Project Type
- Classic WoW addon + Python TTS toolchain
- Extract data from cmangos database for gossip, quest text, objective, progress, completion, and item descriptionns
- Analysis on extracted data (model id inference, name+chatgpt prompts etc. ) to get NPC name, sex, race, faction
- Offline audio generation -> database of npc name (optioal sex, race) → runtime playback
- No realtime synthesis

### Core Mission
> Voice only the text the player actually sees in the UI — no guessing, no hallucinations, no ambient speech.

### Tech Stack
- **Backend:** Python 3.x, cmangos MySQL database
- **TTS Engine:** neutts-air (local)
- **Audio Processing:** speechbrain (MetricGAN+, Mimic)
- **Runtime:** Lua 5.1 (WoW 1.12 API)

---

## 🎯 Project Scope

### ✅ IN SCOPE
- Quest accept/progress/complete text
- Gossip dialog (npc_text)
- Quest greetings
- Quest-starting item descriptions
- NPC metadata (race, sex, name)

### ❌ OUT OF SCOPE
- NPC barks / ambient chatter
- broadcast_text table
- Emotes / yells / combat speech
- Dynamic TTS (all audio pre-generated)
- Multiplayer sync (client-side only)

### Hard Rule
**If the player cannot see the text in the quest/gossip UI, it does not exist for this project.**

---

## 📊 Data Model

### NPCDialog (Canonical Python Object)

```python
@dataclass
class NPCDialog:
    npc_id: int              # creature_template.entry
    npc_name: str            # creature_template.name
    race_mask: int | None    # creature_model_race.racemask
    sex: int | None          # 0=male, 1=female, 2=none
    dialog_type: str         # See Dialog Types table
    quest_id: int | None     # quest_template.entry (if applicable)
    text: str                # Actual dialog content
```
cmangos Dialog-Relevant Database Schema

This section documents the exact database columns and relationships used for extracting player-visible NPC dialog from a Classic cmangos database.

Only columns present in the database schema are referenced.

creature_template

Primary definition table for NPCs.

Relevant Columns
Column	Type	Description
Entry	mediumint unsigned (PK)	Unique NPC identifier
Name	char(100)	NPC display name
SubName	char(100), nullable	NPC title (optional)
MinLevel	tinyint unsigned	Minimum NPC level
MaxLevel	tinyint unsigned	Maximum NPC level
DisplayId1	mediumint unsigned	Primary model ID
DisplayId2–4	mediumint unsigned	Alternate model IDs
DisplayIdProbability1–4	smallint unsigned	Model selection weights
NpcFlags	int unsigned	Determines gossip / quest interaction availability
GossipMenuId	mediumint unsigned	Links NPC to gossip_menu
Relationships

creature_template.Entry

→ creature_questrelation.id

→ creature_involvedrelation.id

→ questgiver_greeting.Entry

creature_template.GossipMenuId

→ gossip_menu.entry

creature_template.DisplayId1

→ creature_model_info.modelid

→ creature_model_race.modelid

creature_model_info

Defines model-level attributes, including gender.

Relevant Columns
Column	Type	Description
modelid	mediumint unsigned (PK)	Model identifier
gender	tinyint unsigned	Model gender
Relationships

creature_template.DisplayId1

→ creature_model_info.modelid

creature_model_race

Maps models to race masks.

Relevant Columns
Column	Type	Description
modelid	mediumint unsigned (PK)	Model identifier
racemask	mediumint unsigned (PK)	Bitmask of playable races
creature_entry	mediumint unsigned	Optional direct NPC mapping
modelid_racial	mediumint unsigned	Alternate racial model
Relationships

creature_template.DisplayId1

→ creature_model_race.modelid

gossip_menu

Connects NPCs to gossip text entries.

Relevant Columns
Column	Type	Description
entry	smallint unsigned (PK)	Gossip menu ID
text_id	mediumint unsigned (PK)	Links to npc_text.ID
script_id	mediumint unsigned (PK)	Script hook (not dialog text)
condition_id	mediumint unsigned	Conditional display
Relationships

creature_template.GossipMenuId

→ gossip_menu.entry

gossip_menu.text_id

→ npc_text.ID

npc_text

Stores all gossip dialog text variants.

Relevant Columns
Column	Type	Description
ID	mediumint unsigned (PK)	Text group identifier
text0_0 … text7_1	longtext, nullable	Player-visible dialog strings
lang0 … lang7	tinyint unsigned	Language per text group
prob0 … prob7	float	Selection probability
em*_0 … em*_5	smallint unsigned	Emotes (non-text metadata)
Notes

Only textX_Y columns contain dialog text.

Each row may contain up to 16 independent dialog strings.

creature_questrelation

Defines which NPCs can start quests.

Columns
Column	Type	Description
id	mediumint unsigned (PK)	NPC Entry
quest	mediumint unsigned (PK)	Quest ID
Relationships

creature_questrelation.id

→ creature_template.Entry

creature_questrelation.quest

→ quest_template.entry

creature_involvedrelation

Defines which NPCs can complete quests.

Columns
Column	Type	Description
id	mediumint unsigned (PK)	NPC Entry
quest	mediumint unsigned (PK)	Quest ID
Relationships

creature_involvedrelation.id

→ creature_template.Entry

creature_involvedrelation.quest

→ quest_template.entry

quest_template

Primary quest definition table.

Dialog-Relevant Columns
Column	Type	Description
entry	mediumint unsigned (PK)	Quest ID
Title	text, nullable	Quest title
Details	text, nullable	Quest acceptance dialog
Objectives	text, nullable	Objective description
RequestItemsText	text, nullable	Progress dialog
OfferRewardText	text, nullable	Completion dialog
EndText	text, nullable	Final quest text
ObjectiveText1–4	text, nullable	Per-objective UI text
Relationships

Referenced by:

creature_questrelation.quest

creature_involvedrelation.quest

item_template.startquest

questgiver_greeting

Defines greeting text shown when interacting with quest NPCs.

Columns
Column	Type	Description
Entry	int unsigned (PK)	NPC Entry
Type	int unsigned (PK)	Greeting type
Text	longtext, nullable	Greeting dialog
EmoteId	int unsigned	Associated emote
EmoteDelay	int unsigned	Emote delay
Relationships

questgiver_greeting.Entry

→ creature_template.Entry

item_template

Defines items that can present dialog (e.g. readable items, quest starters).

Dialog-Relevant Columns
Column	Type	Description
entry	mediumint unsigned (PK)	Item ID
name	varchar(255)	Item name
description	varchar(255)	Item tooltip text
PageText	mediumint unsigned	Links to page_text
startquest	mediumint unsigned	Quest started by item
LanguageID	tinyint unsigned	Language used
Relationships

item_template.startquest

→ quest_template.entry

Summary of Proven Relationships
creature_template.Entry
 ├─ creature_questrelation.id
 ├─ creature_involvedrelation.id
 ├─ questgiver_greeting.Entry

creature_template.GossipMenuId
 └─ gossip_menu.entry
     └─ gossip_menu.text_id → npc_text.ID

creature_template.DisplayId1
 ├─ creature_model_info.modelid
 └─ creature_model_race.modelid

quest_template.entry
 ├─ creature_questrelation.quest
 ├─ creature_involvedrelation.quest
 └─ item_template.startquest


## SQL relationships

NPC identity (name, entry)

Dialog category (gossip / quest accept / progress / complete / greeting)

Optional quest context

Optional model metadata (race / gender / model)

No runtime guessing

No use of non-UI or script text

1. Root Entity: NPC (creature_template)

Everything starts from creature_template.Entry.

This gives us:

Field	Source	Notes
npc_id	creature_template.Entry	Stable primary key
npc_name	creature_template.Name	Spoken name
gossip_menu_id	creature_template.GossipMenuId	Optional
model_id	creature_template.DisplayId1	Primary model
npc_flags	creature_template.NpcFlags	Interaction capability

This is the only required table for an NPC to exist.

2. Dialog Categories (Exact Sources)

Each dialog category has one and only one valid source.

2.1 Gossip Dialog

Purpose: NPC text shown in the gossip window.

Link path:

creature_template.GossipMenuId
 → gossip_menu.entry
   → gossip_menu.text_id
     → npc_text.ID


Extracted data:

Field	Source
text	npc_text.textX_Y
dialog_type	constant = gossip
quest_id	null

Notes:

Each npc_text row expands into up to 16 dialog rows

Probabilities and emotes are ignored (non-text metadata)

2.2 Quest Accept Text

Purpose: Text shown when a quest is accepted.

Link path:

creature_template.Entry
 → creature_questrelation.id
   → quest_template.entry


Extracted data:

Field	Source
text	quest_template.Details
dialog_type	quest_accept
quest_id	quest_template.entry
2.3 Quest Progress Text

Purpose: Text shown when returning to NPC before completion.

Same link path as accept.

Extracted data:

Field	Source
text	quest_template.RequestItemsText
dialog_type	quest_progress
quest_id	quest_template.entry
2.4 Quest Completion Text

Purpose: Text shown when completing a quest.

Link path:

creature_template.Entry
 → creature_involvedrelation.id
   → quest_template.entry


Extracted data:

Field	Source
text	quest_template.OfferRewardText
dialog_type	quest_complete
quest_id	quest_template.entry
2.5 Quest Greeting Text

Purpose: Greeting shown when interacting with a quest NPC.

Link path:

creature_template.Entry
 → questgiver_greeting.Entry


Extracted data:

Field	Source
text	questgiver_greeting.Text
dialog_type	quest_greeting
quest_id	null
3. Voice-Relevant Metadata (Optional, Non-Blocking)

These fields are never required but are used to assign voices.

3.1 Gender

Link path:

creature_template.DisplayId1
 → creature_model_info.modelid

Field	Source	Values
sex	creature_model_info.gender	0=male, 1=female

Fallback: narrator

3.2 Race Mask

Link path:

creature_template.DisplayId1
 → creature_model_race.modelid

Field	Source	Notes
race_mask	creature_model_race.racemask	Bitmask

Fallback: narrator

3.3 Model ID (Voice Flavor / Overrides)
Field	Source
model_id	creature_template.DisplayId1

Uses:

per-NPC overrides

special voices (dragons, demons, etc.)

portrait selection

4. Canonical Output Row (NPCDialog)

Every dialog line collapses to:

npc_id
npc_name
dialog_type
text
quest_id (nullable)
model_id (optional)
race_mask (optional)
sex (optional)


This structure is lossless relative to the database.

5. Deterministic Rules (Non-Negotiable)

Dialog text only comes from UI tables

Same text string = same audio

No script tables

No broadcast_text

Missing metadata never blocks dialog

Every dialog row must trace back to exactly one table path

6. Voice Assignment Strategy (Schema-Driven)

Priority order (all optional):

NPC-specific override (by npc_id)

Model-based override (DisplayId1)

Race + gender (race_mask + sex)

Gender only

Narrator


## 🔄 Pipeline Overview

```
┌─────────────────┐
│  cmangos DB     │
│  (MySQL)        │
└────────┬────────┘
         │
         │ extraction/*.py
         ▼
┌─────────────────┐
│  NPCDialog CSV  │
│  (normalized)   │
└────────┬────────┘
         │
         │ generation/generator.py
         ▼
┌─────────────────┐
│  Audio Files    │
│  sounds/*.wav   │
└────────┬────────┘
         │
         │ Runtime lookup
         ▼
┌─────────────────┐
│  Lua Addon      │
│  (in-game)      │
└─────────────────┘
```

---

## 📁 File Structure

### Python Backend
```
extraction/
  ├── extract_gossip.py       # Extracts npc_text → NPCDialog
  ├── extract_wow_dialog.py   # Extracts quest text → NPCDialog
  └── db_config.py            # MySQL connection settings

datamodels/
  └── data_models.py          # NPCDialog class definition

generation/
  ├── generator.py            # Main TTS orchestrator
  └── audio.py                # Audio enhancement pipeline
```

### Lua Addon
```
BetterQuestText.lua           # Core addon logic
QuestFrame.lua                # Quest UI hooks
Book.lua                      # Gossip UI hooks
Config.lua                    # User settings
PortraitManager.lua           # NPC portrait display

db/
  ├── bookdb.lua              # Quest text → audio mappings
  ├── modeldb.lua             # NPC → model/race/sex lookup
  └── portraitdb.lua          # NPC → portrait texture paths
```

### Assets
```
sounds/                       # Generated audio (not in repo)
samples/audio/                # Reference voices per race/sex
samples/text/                 # Training transcripts
portraits/npcs/               # NPC portrait images
```

### TTS Engine
```
neutts-air/                   # TTS inference engine
checkpoints/                  # Model weights
pretrained_models/            # Audio enhancement models
```

---

## 🎤 Voice Assignment System

### Race/Sex → Voice Mapping
- Voices stored in: `samples/audio/{race}_{sex?}/`
- Example: `samples/audio/dwarf_female/*.wav`
- Fallback chain: specific NPC → race/sex → narrator

### Supported Race/Sex Combinations
```
human, human_female
dwarf, dwarf_female
elf, elf_female (Night Elf)
gnome, gnome_female
orc, orc_female
tauren, tauren_female
troll, troll_female
undead, undead_female
narrator (fallback)
```

---

## ✅ TODO Tracker

### Phase 1: Extraction (70% complete)
- [x] Gossip extraction (npc_text)
- [x] Quest accept text
- [x] Quest progress text
- [x] Quest completion text
- [x] Quest greeting extraction
- [ ] Item quest descriptions
- [ ] Edge case: multi-option gossip menus
- [ ] Edge case: locale support (future)

### Phase 2: Generation (60% complete)
- [x] TTS pipeline setup
- [x] Audio enhancement integration
- [x] Reference voice encoding
- [ ] Batch generation script
- [ ] Per-NPC voice overrides
- [ ] Volume normalization
- [ ] Silence trimming

### Phase 3: Lua Runtime (80% complete)
- [x] Quest frame hooks
- [x] Gossip frame hooks
- [x] Audio playback queue
- [x] NPC portrait display
- [ ] Deduplication (same text → same audio)
- [ ] User config panel
- [ ] Error handling (missing audio)
- [ ] Performance optimization (large databases)

### Phase 4: Polish (0% complete)
- [ ] Automated build pipeline
- [ ] Unit tests (Python)
- [ ] Integration tests (Lua)
- [ ] Documentation for contributors
- [ ] Sample audio pack (demo)

---

## 🧪 Development Workflow

### Adding New Dialog Type
1. Identify cmangos source table
2. Add extraction logic to `extraction/`
3. Verify NPCDialog output
4. Generate audio via `generation/generator.py`
5. Add Lua hooks for UI event
6. Update `db/bookdb.lua` mappings

### Testing Extraction
```bash
cd extraction/
python extract_gossip.py > output.csv
# Verify columns: npc_id, npc_name, dialog_type, text, quest_id, race_mask, sex
```

### Testing TTS Generation
```bash
cd generation/
python generator.py --input ../extracted_dialog.csv --output ../sounds/
```

### Testing In-Game
1. Copy `BetterQuestText/` to `Interface/AddOns/`
2. Restart WoW client
3. `/reload` to refresh addon
4. Talk to NPC → verify audio plays

---

## 🚨 Known Issues & Workarounds

### Issue: Some NPCs have no race_mask
**Cause:** Generic creature models  
**Workaround:** Use narrator voice

## Structure lua to be more modular
1. Frame code isolated but pulls from join config file 
2. Portrait code isolated 
3. Book code isolated 
4. Soundqueue file for adding/removing quests like wow voiceover
5. sound queue frame/portrait like wow voiceover but using portraits instead of models

## Reverb in VO 
lilts and robotic sound in vo tried tradition fft on audio but it's a subtle sound that needs ML to fix
Needs STO models to fix imo so we'll see about a metric for identifying/fixing them with post processing later. 

### Issue: Multiple gossip texts for same NPC
**Cause:** Conditional gossip (quest state, class, etc.)  
**Workaround:** Extract all, generate all, Lua picks at runtime
**ideal** create UI button with exclamation to flag incorrectly picking VO and this can be copy pasted into github for overriding but quickly cycles though VOs. 


### Issue: Lua memory usage with 10k+ audio files
**Cause:** Large db tables loaded at startup  
**Workaround:** Lazy loading (future optimization)

---

## 📚 AI Agent Hints

### When Asked About Extraction
- Always reference `datamodels/data_models.py` for schema
- Never invent new dialog_types
- Check cmangos table structure first
- Output must be CSV-compatible

### When Asked About TTS Generation
- Voices are pre-encoded in `samples/audio/`
- Use neutts-air API, not external services
- Enhancement is optional but recommended
- Target: 16-bit 24kHz WAV

### When Asked About Lua Code
- WoW 1.12 API only (no modern Lua features)
- Use `PlaySoundFile()` for audio
- Hook events, don't poll frames
- Avoid global namespace pollution

### When Asked About Database Schema
- Refer to cmangos GitHub for authoritative schema
- ClassicDB.ch is a good reference for data
- Never use `broadcast_text` table
- Always validate against actual DB

---

## 🔗 External Resources

### Code References
- cmangos Classic: https://github.com/cmangos/mangos-classic
- Voiceover Inspiration: https://github.com/mrthinger/wow-voiceover

### API Documentation
- WoW 1.12 API: https://wowpedia.fandom.com/wiki/World_of_Warcraft_API
- pfUI Reference: https://github.com/shagu/pfUI
- CreatureDisplayID: https://wowpedia.fandom.com/wiki/CreatureDisplayID

### Databases
- Classic DB: https://classicdb.ch
- cmangos World DB: https://github.com/cmangos/classic-db

---

## 🎓 Design Principles

1. **Deterministic over Smart** — Same text = same audio, always
2. **Database-Driven** — If it's not in cmangos, it doesn't exist
3. **Offline-First** — No runtime TTS, no network calls
4. **UI-Visible Only** — Player must see the text to voice it
5. **Fail Gracefully** — Missing audio = silent, not broken

---

## 🔧 Quick Commands

### Extract All Dialog
```bash
python extraction/extract_wow_dialog.py > all_dialog.csv
python extraction/extract_gossip.py >> all_dialog.csv
```

### Generate Audio for Specific NPC
```bash
python generation/generator.py 
```

### Rebuild Lua DB Files
```bash
# (Manual for now — automation TODO)
# Convert CSV → Lua table format
```


---

## 📝 Notes for Future Development

### Planned Features
- Enhance generation 
- Queue for sounds
- Portrait for books 

### Technical Debt
- No incremental updates (full rebuild required)
- Voice selection is rule-based, not ML

### Community Requests
- Skip/replay controls

---

**End of Document**  
For specific implementation details, see individual module docstrings.