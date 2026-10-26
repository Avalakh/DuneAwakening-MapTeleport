# Каталог регионов установленной игры

Снимок 2026-10-25: 44 записи CDT_MapsInfo, данные CartographyMapSettings и DuneGlobalDataCacheSubsystem. Столбец «Прогресс» — штатные условия видимости карты (завершение journey и GameplayTagQuery); окончательные требования путешествия проверяет игра при запросе. true здесь не означает, что любой выход допускает путешествие. Технические карты и Overland не попадают в список регионов. Неизвестная карта не считается отсутствующей.

| regionId / mapId | Название | worldPath | destinationName | Местная карта | Прогресс | Категория |
|---|---|---|---|---|---|---|
| HaggaBasin | Котловина Хагга | /Game/Dune/Maps/Arrakis/SOC_1/Survival_1.Survival_1 | Travel_To_HaggaBasin_TheAnvil | present | true | region |
| HarkoVillage | Деревня Харко | /Game/Dune/Maps/SocialHubs/HarkoVillage/SH_HarkoVillage.SH_HarkoVillage | Travel_To_Harko | present | true | region |
| DeepDesert | Сердце пустыни | /Game/Dune/Maps/Arrakis/DeepDesert_1/DeepDesert_1.DeepDesert_1 | Overland_to_DeepDesert1_S1 | present | true | region |
| Overland | Обзорная карта | /Game/Dune/Systems/Overmap/Overmap.Overmap | Harko_to_Overland_N | present | true | overview |
| Arrakeen | Арракин | /Game/Dune/Maps/SocialHubs/Arrakeen/SH_Arrakeen.SH_Arrakeen | Travel_To_Arrakeen | present | true | region |
| WreckOfHephaestus | Обломки «Гефеста» | /Game/Dune/Maps/OverlandMaps_Story/WreckOfTheHephaestus/CB_Story_Hephaestus/CB_Story_Hephaestus.CB_Story_Hephaestus | Overland_to_Hephaestus | absent | false | region |
| BeneathCarthag | Руины Старого Карфага | /Game/Dune/Maps/OverlandMaps_Story/BeneathOldCarthag/CB_Story_Ecolab_Carthag/CB_Story_Ecolab_Carthag.CB_Story_Ecolab_Carthag | Travel_To_StoryMap_OldCarthag | absent | false | region |
| Station15 | Станция 15 | /Game/Dune/Maps/Survival_Challenge_Maps/Survival_Challenge_Station_15/CB_SurvivalChallenge_Station_15/CB_SurvivalChallenge_Station_15.CB_SurvivalChallenge_Station_15 | Overland_to_Station15 | unknown | false | region |
| WaterFat | Особняк водоторговца | /Game/Dune/Maps/OverlandMaps_Story/WaterFatManor/CB_Story_WaterFatManor.CB_Story_WaterFatManor | Overland_to_WaterFat | absent | false | region |
| MainMenu | MainMenu | /Game/Dune/Maps/MainMenu.MainMenu |  | unknown | false | technical |
| CombatGym_01 | CombatGym_01 | /Game/Dune/Maps/CombatGym/CombatGym_01.CombatGym_01 |  | unknown | false | technical |
| CombatGym_Camps | CombatGym_Camps | /Game/Dune/Maps/Gyms/CombatGym_Camps/CombatGym_Camps.CombatGym_Camps |  | unknown | false | technical |
| NPE | NPE | /Game/Dune/Maps/NPE2/Levels/NPE2_Main.NPE2_Main |  | unknown | false | region |
| ProcesVerbal | эта комната | /Game/Dune/Maps/MainStory_Chapter2/ProcesVerbal/ProcesVerbalMap/Story_ProcesVerbal.Story_ProcesVerbal | Story_ProcesVerbal_BarMurder | absent | true | region |
| FallenLight | Павший свет | /Game/Dune/Maps/SocialHubs/FallenLight/SH_FallenLight.SH_FallenLight |  | unknown | false | region |
| LostHarvest | Забытая испытательная станция | /Game/DLC/B1C2/Maps/DLC_Story_LostHarvest/DLC_Story_LostHarvest_Map/DLC_Story_LostHarvest.DLC_Story_LostHarvest |  | absent | true | region |
| LostHarvest_EcolabA | Забытая испытательная станция | /Game/DLC/B1C2/Maps/DLC_Story_LostHarvest/DLC_Story_LostHarvest_EcolabA/DLC_Story_LostHarvest_EcolabA.DLC_Story_LostHarvest_EcolabA | DLC_LostHarvest_EcolabA_OwnServer | absent | true | region |
| LostHarvest_EcolabB | Забытая испытательная станция | /Game/DLC/B1C2/Maps/DLC_Story_LostHarvest/DLC_Story_LostHarvest_EcolabB/DLC_Story_LostHarvest_EcolabB.DLC_Story_LostHarvest_EcolabB | DLC_LostHarvest_EcolabB_OwnServer | absent | true | region |
| LostHarvest_ForgottenLab | Забытая испытательная станция | /Game/DLC/B1C2/Maps/DLC_Story_LostHarvest/DLC_Story_LostHarvest_ForgottenLab/DLC_Story_LostHarvest_ForgottenLab.DLC_Story_LostHarvest_ForgottenLab | DLC_LostHarvest_ForgottenLab_OwnServer | absent | true | region |
| ArtOfKanly | Арена Нового Карфага | /Game/DLC/B1C3/Maps/MainStory_Chapter3/ArtOfKanly/Story_ArtOfKanly.Story_ArtOfKanly | Story_ArtOfKanly_DuelingRing_Lobby | absent | false | region |
| WreckOfHephaestusDungeon | Обломки «Гефеста» | /Game/DLC/B1C3/Maps/MainStory_Chapter3/HephaestusRevisit/CB_Dungeon_Hephaestus/CB_Dungeon_Hephaestus.CB_Dungeon_Hephaestus | Overland_to_HephaestusDungeon | absent | true | region |
| OldCarthagDungeon | Руины Старого Карфага | /Game/DLC/B1C3/Maps/MainStory_Chapter3/OldCarthagRevisit/CB_Dungeon_OldCarthag/CB_Dungeon_OldCarthag.CB_Dungeon_OldCarthag | Overland_to_CarthagDungeon | absent | true | region |
| HeighlinerDungeon | Павший свет | /Game/DLC/B1C3/Maps/MainStory_Chapter3/FallenLight_HighlinerDungeon/Story_HeighlinerDungeon.Story_HeighlinerDungeon | Overland_to_FallenHeighliner | absent | false | region |
| SandfliesFortress | Улей | /Game/Dune/Maps/OverlandMaps_Story/BanditFortress01/CB_Story_BanditFortress01.CB_Story_BanditFortress01 | Overland_To_SandflyFortress | absent | true | region |
| ClosedOffTestingStationIsland | <MISSING STRING TABLE ENTRY> | /Game/Dune/Maps/OverlandMaps/Overland_S_05/CB_Overland_S_05.CB_Overland_S_05 | CB_Overland_S_05_To_Overland | absent | true | region |
| GroundVehicleTimeTrialIsland | Гонка контрабандистов | /Game/Dune/Maps/OverlandMaps/Overland_S_06/CB_Overland_S_06.CB_Overland_S_06 | Overland_To_CB_Overland_S_06 | absent | true | region |
| ErythriteCaveIsland | Алеющие пещеры | /Game/Dune/Maps/OverlandMaps/Overland_S_04/CB_Overland_S_04.CB_Overland_S_04 | Overland_To_CB_Overland_S_04 | absent | true | region |
| RadioactiveShipwreck | Место крушения «Тихе» | /Game/Dune/Maps/OverlandMaps/Overland_S_01/CB_Overland_M_01.CB_Overland_M_01 | Overland_To_CB_Overland_M_01 | absent | true | region |
| Story_Faction_Outpost_Hark | Арсунский гарнизон | /Game/DLC/B1C3/Maps/Story_Faction_Outpost_Hark/Story_Faction_Outpost_Hark.Story_Faction_Outpost_Hark | Overland_to_FactionOutpostHark | absent | false | region |
| Story_Faction_Outpost_Atre | Арсунский гарнизон | /Game/DLC/B1C3/Maps/Story_Faction_Outpost_Atre/Story_Faction_Outpost_Atre.Story_Faction_Outpost_Atre | Overland_to_FactionOutpostAtre | absent | false | region |
| RadiationDungeon | Имперская испытательная станция № 89 | /Game/Dune/Maps/Dungeons/Ecolabs/Bronze/Greenhouse/Ecolab_Bronze_Green_089/CB_Ecolab_Bronze_Green_089.CB_Ecolab_Bronze_Green_089 | Overland_to_Ecolab089 | absent | true | region |
| ElectricityDungeon | Имперская испытательная станция № 152 | /Game/Dune/Maps/Dungeons/Ecolabs/Bronze/Greenhouse/Ecolab_Bronze_Green_152/CB_Ecolab_Bronze_Green_152.CB_Ecolab_Bronze_Green_152 | Overland_to_Ecolab152 | absent | true | region |
| PoisonDungeon | Имперская испытательная станция № 195 | /Game/Dune/Maps/Dungeons/Ecolabs/Bronze/Greenhouse/Ecolab_Bronze_Green_195/CB_Ecolab_Bronze_Green_195.CB_Ecolab_Bronze_Green_195 | Overland_To_Ecolab195 | absent | true | region |
| DarknessDungeon | Имперская испытательная станция № 24 | /Game/Dune/Maps/Dungeons/Ecolabs/Bronze/Greenhouse/Ecolab_Bronze_Green_024/CB_Ecolab_Bronze_Green_024.CB_Ecolab_Bronze_Green_024 | Overland_to_Ecolab024 | absent | true | region |
| FireDungeon | Имперская испытательная станция № 136 | /Game/Dune/Maps/Dungeons/Ecolabs/Bronze/Greenhouse/Ecolab_Bronze_Green_136/CB_Ecolab_Bronze_Green_136.CB_Ecolab_Bronze_Green_136 | Overland_to_Ecolab136 | absent | true | region |
| DestroyedZanovar | Космопорт Арракина | /Game/DLC/B1C4/Maps/MainStory_Chapter4/Zanovar/CB_Story_DestroyedZanovar.CB_Story_DestroyedZanovar | Story_Zanovar_Start | absent | false | region |
| OrbitalMonitor | Орбитальная станция сардаукаров | /Game/DLC/B1C4/Maps/MainStory_Chapter4/OrbitalMonitor/CB_Story_OrbitalMonitor.CB_Story_OrbitalMonitor | Story_FourtyFears_Start | absent | true | region |
| OrbitalMonitor_TheRescue | Орбитальная станция сардаукаров | /Game/DLC/B1C4/Maps/MainStory_Chapter4/TheRescue/Standalone_Story_TheRescue.Standalone_Story_TheRescue |  | absent | true | region |
| PitDungeon | Старый карьер | /Game/Dune/Maps/Dungeons/Dungeon_ThePit/CB_Dungeon_ThePit.CB_Dungeon_ThePit | Overland_to_OldQuarry | unknown | true | region |
| TheRuinsOfTsimpo | Руины Цимпо | /Game/Dune/Maps/OverlandMaps/Overland_S_07/CB_Overland_S_07.CB_Overland_S_07 | Overland_to_RuinsOfTsimpo | absent | true | region |
| WindPass | Ветровой перевал | /Game/Dune/Maps/OverlandMaps/CB_Overland_S_08/CB_Overland_S_08.CB_Overland_S_08 | Overland_to_WindPass | unknown | false | region |
| SietchTalab | Сиетч Та'лаб | /Game/Dune/Maps/Journey_Sietch/CB_Arrakis_Generic_Sietch_Room.CB_Arrakis_Generic_Sietch_Room | HaggaBasin_to_Sietch | absent | true | region |
| ParanoidRoom | Место созерцания | /Game/Dune/Maps/Journey_Suvival1_StoryCBs/Paranoid/Levels/CB_Arrakis_Story_Paranoid_PrayerRoom.CB_Arrakis_Story_Paranoid_PrayerRoom | HaggaBasin_To_ParanoidRoom | absent | false | region |
| GluttonRoom | Обеденный зал | /Game/Dune/Maps/Journey_Suvival1_StoryCBs/Glutton/Levels/CB_Arrakis_Story_Glutton_DiningRoom.CB_Arrakis_Story_Glutton_DiningRoom | HaggaBasin_To_GluttonRoom | absent | false | region |

Четыре отдельных местных слоя: HaggaBasin, DeepDesert, Arrakeen, HarkoVillage. Для них определены разные физические профили. Прочие строки с GlobalOnly-картографией используют штатную точку прибытия; unknown не запускает прямое путешествие. Legacy FullscreenMapDataAsset сам по себе не является доказательством активной местной карты.

Дубликаты выходов объединены по native mapId. Измерение сервера не является регионом. Сюжетные выходы не предпочитаются обычному Travel_To; сторонние NBS-направления исключены. Текущий регион не требует повторного путешествия.

Доказательства: work/evidence/probe-263-map-profiles.txt, probe-237-catalog-live.txt, probe-264-assets.txt; region_catalog.lua и region_catalog_test.lua. Снимок не заменяет живую проверку всех доступных направлений.

## Актуальная доступность при полностью загруженном кеше

Probe-413/430: 44 исходных записи, 24 прошли native прогресс и разрешение маршрута. Дополнительно к раннему снимку доступны RadioactiveShipwreck, WreckOfHephaestusDungeon, OrbitalMonitor, OldCarthagDungeon, TheRuinsOfTsimpo, DeepDesert, SietchTalab, PitDungeon (unknown map), SandfliesFortress, ProcesVerbal. Кеш/доступность не фиксируются на момент старта; снимок пересчитывается для актуальных pc/pawn. Это не утверждение, что окончательные требования каждого travel-запроса выполнены. Направление с unknown картой видно с ограничением, подтверждение запрещено. WreckOfHephaestus из ранней таблицы и WreckOfHephaestusDungeon — разные native mapId; первый не разблокирован этим модом.

Пересчёт после реальных смен HarkoVillage → Arrakeen → ErythriteCaveIsland → Arrakeen → HarkoVillage каждый раз выделял новый текущий регион и не запускал повторное путешествие для местного этапа. Технические строки/Overland отсутствуют в итоговом списке. Полный снимок: work/evidence/probe-430-catalog-current.txt. Отсутствие маршрута в частично заполненном прежнем кеше не считается постоянной блокировкой региона.

Статус оставшихся направлений: **PENDING_USER_PLAYTEST**. Физически проверены Arrakeen, HarkoVillage, HaggaBasin и DeepDesert (близкая/дальняя местная точка), а также ErythriteCaveIsland без местной карты. Для остальных строк наличие в каталоге и прохождение фильтра не означают пройденного путешествия. Многоуровневые точки четырёх карт и штатный Overland-переход на орнитоптере также не объявлены полностью проверенными.
