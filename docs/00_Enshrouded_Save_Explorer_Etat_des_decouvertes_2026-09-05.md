Ce document est la source de vérité sur les découvertes, hypothèses validées et décisions fonctionnelles. Les fichiers source courants restent la source de vérité sur les signatures, types et implémentations exactes.

# Enshrouded Save Explorer — État des découvertes

## 1. Objectif du projet

> **Statut du document — 5 septembre 2026**  
> Référentiel de développement mis à jour après les expériences contrôlées de progression personnelle et de synchronisation multijoueur. Les hypothèses historiques devenues fausses ou inutiles ont été remplacées par les règles actuellement retenues.

L’objectif du projet est de construire un explorateur de sauvegardes Enshrouded capable de déterminer, autant que possible :

* les quêtes terminées personnellement ;
* les quêtes non terminées personnellement ;
* les quêtes `Auto` résolues mais dont l’origine personnelle ou héritée ne peut pas toujours être déterminée ;
* les sous-étapes ou sous-quêtes lorsqu’elles sont reconstructibles ;
* les collections de lore découvertes ou incomplètes ;
* les tutoriels débloqués ;
* les points d’intérêt découverts ou non ;
* à terme, éventuellement d’autres éléments de progression comme recettes, connaissances ou objets débloqués.

Le projet n’a pas vocation à reproduire intégralement le moteur logique d’Enshrouded. Le but est d’extraire suffisamment d’état persistant pour reconstruire une vue fiable et utile de la progression.

---

# 2. Ressources du jeu

Installation étudiée :

```text
E:\SteamLibrary\steamapps\common\Enshrouded
```

Fichiers principaux :

```text
enshrouded.exe
enshrouded.kfc
enshrouded.kfc_resources
enshrouded_000.dat
...
enshrouded_031.dat
enshrouded_local.json
```

Les ressources ont été extraites avec `Brabb3l/kfc-parser`.

Répertoire de travail :

```text
E:\EnshroudedSaveExplorer
```

Ressources extraites :

```text
E:\EnshroudedSaveExplorer\extracted_data
```

Répertoires particulièrement importants :

```text
GameKnowledgeResource
GameKnowledgeQueryResourceDb
GameKnowledgeQueryTriggerResource
JournalRegistryResource
DevJournalRegistryResource
ItemKnowledgeResource
RecipeRegistryResource
MapMarkerRegistryResource
GuidRegistryResource
TemplateResource
LocaTagCollectionResource
SceneEntityChunkResource
SceneResource
FbUiBundle
```

---

---

# 3. Format KSC1 des sauvegardes

Les fichiers `characters-*` utilisent un conteneur identifié par :

```text
KSC1
```

Structure observée :

```text
Offset 0x00 : char[4]  magic = "KSC1"
Offset 0x04 : uint32   BlobCount
Offset 0x08 : 16 bytes SaveID
Offset 0x18 : table des blobs
```

Chaque entrée de la table fait 12 octets :

```text
uint32 OwnerID
uint32 BlobType
uint32 CompressedSize
```

Puis viennent les blobs compressés, concaténés.

Les blobs utilisent Zstandard.

Le décompresseur est actuellement implémenté dans :

```text
uZstd.pas
```

---

---

# 4. OwnerID

Chaque personnage possède un `OwnerID`.

OwnerIDs identifiés :

```text
1B551646 = personnage avancé principal
2AF68BE4 = personnage utilisé pour les premières expériences contrôlées
A3944272 = nouveau personnage vierge utilisé pour l'expérience monde partagé
```

Le fichier `virgin_before_world\characters-9` contient notamment :

```text
Owner=A3944272  Type=F0D58EDC  Size=29
Owner=1B551646  Type=F0D58EDC  Size=19239
Owner=2AF68BE4  Type=F0D58EDC  Size=165
```

Ce qui permet d’identifier sans ambiguïté le nouveau personnage.

---

---

# 5. Blob KNOW

Le blob que nous appelons `KNOW` apparaît dans la table KSC1 comme :

```text
Type=F0D58EDC
```

La confusion initiale avec :

```text
DC8ED5F0
```

vient simplement de la représentation des quatre octets / de l’endianness.

Le blob correspond à une structure de connaissances/progression persistantes.

Structure physique décodée :

```text
offset 0  : uint32 Version
offset 4  : uint32 Unknown1
offset 8  : uint32 EntryCount
offset 12 : uint32 IDs[EntryCount]
             immédiatement suivi de
             uint32 Values[EntryCount]
```

Dans les sauvegardes étudiées :

```text
Version = 2
Unknown1 = 1
```

La taille exacte est :

```text
12 + 8 * EntryCount
```

La correspondance logique est :

```text
IDs[i] -> Values[i]
```

Important : les IDs ne sont pas nécessairement triés.

La première implémentation utilisait une recherche binaire. C’était incorrect.

La fonction :

```text
FindKnowledgeValue
```

dans `uKnowledge.pas` utilise désormais une recherche linéaire.

---

---

# 6. Signification générale de KNOW

`KNOW` n’est pas uniquement une table de quêtes.

On y trouve différents types d’identifiants :

* GameKnowledge ;
* IDs de quête ;
* recettes ;
* items ;
* événements ;
* marqueurs de progression ;
* potentiellement d’autres types.

Le modèle général est donc :

```text
uint32 ResourceID -> uint32 Value
```

La signification de `Value` dépend du type de ressource.

Il ne faut donc pas interpréter tous les `Value=1` comme des booléens de même nature.

---

---

# 7. SimpleBool et SimpleFlag

Deux cas importants sont déjà compris.

## SimpleBool

Pour un GameKnowledge de type booléen :

```text
0 = false
non zéro = true
```

Pour notre évaluateur, l’absence d’un `SimpleBool` dans KNOW est actuellement considérée comme :

```text
0
```

dans les cas contrôlés.

## SimpleFlag

Certains IDs utilisent des bits.

Exemple :

```text
D969A59D
```

est passé de :

```text
1 -> 3
```

lors de la fabrication / activation d’un autel.

Cela montre que la valeur est un bitfield, pas un simple booléen.

L’évaluateur utilise actuellement :

```text
(actualValue AND expectedFlag) = expectedFlag
```

pour `SimpleFlag`.

---

---

# 8. Expérience contrôlée : Cinder Vault

Personnage quasi vierge.

Avant découverte :

```text
9841FA85 = 1
```

Après découverte de Cinder Vault :

```text
A6F02193 = 1
9841FA85 = 1
```

`A6F02193` est directement un GameKnowledge.

Les ressources `RuntimeMapMarkerUnlockRequirements` utilisent cet ID pour décider de l’affichage du marqueur de carte.

Conclusion solide :

```text
A6F02193 = découverte / déblocage du POI Cinder Vault
```

Cela fournit un modèle très prometteur pour les POI :

```text
MapMarker
 -> UnlockRequirement
 -> GameKnowledge ID
 -> présence/valeur dans KNOW
```

---

---

# 9. Expérience contrôlée : Claim A Spot For Your Base

Quête étudiée :

```text
Claim A Spot For Your Base
Quest ID = B22F436D
Decimal  = 2989441901
```

Sous-entrées :

```text
D8FE67A0 = Reach The Plains
A8ED811F = Build A Flame Altar
2D48135C = Talk To The Flame
```

Important :

Le texte localisé n’est pas un identifiant fiable.

Plusieurs entrées différentes peuvent avoir le même texte, notamment :

```text
Talk To The Flame
```

L’identité d’une sous-entrée doit donc être déterminée par :

```text
entryId
```

et non par le texte affiché.

---

---

# 10. Chronologie des sauvegardes contrôlées

États :

```text
003_quest_started
004_quest_before_completed
005_quest_completed
006_quest_completed_next
007_quest_completed_next
008_after_talk_to_the_flame
```

Interprétation réelle :

```text
003
quête démarrée
première étape active

004
juste avant validation de Reach The Plains

005
Reach The Plains vient d’être terminé

006
avant activation/validation de Build A Flame Altar

007
après Build A Flame Altar

008
après Talk To The Flame
une quête suivante démarre automatiquement
```

---

---

# 11. Différences KNOW de la quête contrôlée

## 003 -> 004

Ajouts :

```text
5BC2B4BD=5
0639B6EB=1
8B63E785=1
3A639FED=1
8E24C7A6=1
2B76680F=3
88175069=3
B8F17D32=1
CF128197=1
```

## 004 -> 005

Ajout :

```text
4E7CCCFE=1
```

`4E7CCCFE` correspond à :

```text
spot_reached
```

Il constitue un lien formel avec la validation de la première étape.

## 005 -> 006

Ajouts :

```text
353DF3BA=1
25A43C2F=1
D969A59D=1
23D06EC5=1
```

## 006 -> 007

Ajouts :

```text
52A35FCF=1
EBB93C94=3
FE03C96A=1
26D580CE=1
2F6EA162=1
29199C93=1
D4F2B020=1
```

Modification :

```text
D969A59D : 1 -> 3
```

## 007 -> 008

Ajouts :

```text
0FDC3003=1
9217A4E9=1
B22F436D=1
```

---

---

# 12. Marqueur de complétion de quête

Le résultat important de l’expérience contrôlée reste :

```text
B22F436D
```

Cet ID est à la fois :

* l’`entryId` de `Claim A Spot For Your Base` ;
* un `GameKnowledgeResource` ;
* absent avant la fin de la quête ;
* présent avec valeur `1` après la fin ;
* défini comme `isPlayerKnowledge=true`.

Sur la quête contrôlée, exécutée personnellement par le personnage `2AF68BE4` sur un monde vierge :

```text
KNOW[quest.entryId] = 1
```

apparaît exactement à la complétion finale.

L’expérience multijoueur a ensuite permis de préciser la sémantique :

* pour les `PlayerQuest` et `WorldQuest` observées, le marqueur top-level n’est **pas** injecté au personnage vierge lorsqu’il rejoint un monde avancé ;
* pour certaines quêtes `Auto`, le marqueur top-level est au contraire injecté automatiquement.

Conclusion de référence :

```text
PlayerQuest / WorldQuest:
    KNOW[quest.entryId] != 0
    -> très bon indicateur de complétion personnelle

Auto:
    KNOW[quest.entryId] != 0
    -> quête résolue pour ce personnage
    -> origine personnelle ou héritée non déterminable en général
```

Cette distinction est désormais la base fonctionnelle du futur explorateur.

---

# 13. JournalRegistry et QueryDb

Le `JournalRegistryResource` contient la structure des quêtes et autres objets de journal.

Le `GameKnowledgeQueryResourceDb` contient les conditions utilisées pour :

* débloquer des étapes ;
* tester des événements ;
* composer des conditions complexes.

Les conditions rencontrées comprennent notamment :

```text
SimpleBool
SimpleFlag
Extern
```

et des primitives runtime.

---

---

# 14. Évaluateur de queries

Le projet contient maintenant :

```text
uQueryModel.pas
uQueryEvaluator.pas
```

Résultat tri-state :

```text
erFalse
erTrue
erUnknown
```

C’est essentiel car certaines conditions ne peuvent pas être déterminées depuis le seul KNOW du personnage.

Opérations actuellement gérées :

```text
SimpleBool
SimpleFlag
Extern
AND
OR
invertResult
```

Certaines primitives runtime donnent :

```text
UNKNOWN
```

lorsqu’elles ne peuvent pas être reconstruites depuis les données persistantes disponibles.

Point important : une absence dans le KNOW personnage ne doit pas toujours être interprétée comme un état monde faux. Pour une condition non-player/world, l’absence peut simplement signifier :

```text
état monde non disponible dans cette sauvegarde personnage
```

et donc conduire conceptuellement à `UNKNOWN`.

L’évaluateur reste utile pour comprendre les dépendances et diagnostiquer une quête, mais il n’est plus le mécanisme principal de classification de la provenance personnelle des quêtes.

---

# 15. Attention à Extern

Une condition :

```text
type = Extern
compareOperator = Equals
compareValue = 0
```

ne signifie pas :

```text
NOT query
```

La négation réelle est gérée par :

```text
invertResult
```

Le `compareValue=0` semble souvent être une valeur technique par défaut pour les références de queries.

---

---

# 16. FlameAltarCount

Nous avons étudié cette primitive avant de décider qu’il n’était pas nécessaire d’en reconstruire tout le mécanisme.

ID runtime important :

```text
1E5FFB59
decimal 509606745
```

Type :

```text
FlameAltarCount
```

Noms observés :

```text
one_altar_or_more
AtleastOneFlameAltars
count_1_and_more
count_2_and_More
count_3_and_More
count_4_and_More
count_5_and_More
```

Le QueryDb contient donc explicitement plusieurs seuils de nombre d’autels.

La primitive :

```text
1E5FFB59
```

correspond à :

```text
FlameAltarCount > 0
```

Il existe par ailleurs une primitive distincte :

```text
FlameAltarLevel
```

ce qui confirme que `Count` et `Level` sont bien deux mécanismes différents.

---

---

# 17. Trigger FlameAltarCount

Query :

```text
9B73031F
decimal 2608005919
name = flameAltarCOUNT_01
```

Elle utilise :

```text
FlameAltarCount
count_1_and_more
ID 1E5FFB59
```

Cette query est référencée par un `GameKnowledgeQueryTriggerResource`.

Lorsque la condition devient vraie, le trigger écrit notamment :

```text
29199C93 = 1
2F6EA162 = 1
```

Ces deux IDs apparaissent précisément entre les sauvegardes `006` et `007`.

Les GameKnowledge correspondants sont des booléens persistants avec progression optionnelle, et existent sous formes player/non-player dans les ressources.
Le modèle est donc :

```text
runtime FlameAltarCount > 0
       |
       v
query flameAltarCOUNT_01
       |
       v
GameKnowledgeQueryTrigger
       |
       v
persistent KNOW markers
```

Conclusion importante :

Les GameKnowledge générés par ces triggers sont des **conséquences persistantes** de l’événement runtime.

Ils ne sont pas nécessairement des proxies de l’état runtime actuel.

Par exemple :

```text
avoir construit un autel puis l’avoir supprimé
```

peut laisser le marqueur persistant à `1` alors que :

```text
FlameAltarCount = 0
```

au moment présent.

---

---

# 18. Pourquoi nous avons arrêté d’approfondir FlameAltarCount

L’objectif du projet n’est pas de reproduire le moteur de progression du jeu.

Pour déterminer les quêtes manquantes, il est acceptable qu’une sous-condition reste :

```text
UNKNOWN
```

si les marqueurs persistants permettent malgré tout de déterminer :

* la quête terminée ;
* une progression minimale ;
* les sous-étapes atteintes.

Nous avons donc adopté une approche pragmatique.

---

---

# 19. Évaluation des sous-étapes

Pour la quête contrôlée, les `knowledgeRequirement` ont donné :

## 003

```text
Reach The Plains       TRUE
Build A Flame Altar    FALSE
Talk To The Flame      FALSE
```

## 005

```text
Reach The Plains       TRUE
Build A Flame Altar    TRUE
Talk To The Flame      UNKNOWN
```

## 007

```text
Reach The Plains       TRUE
Build A Flame Altar    TRUE
Talk To The Flame      UNKNOWN
```

## 008

```text
quest KNOW             = 1
```

Le problème important est donc :

```text
005 et 007 sont indistinguables
avec les seules knowledgeRequirement actuellement évaluables
```

alors que leur état réel est différent.

Nous avons donc abandonné l’heuristique :

```text
TRUE -> UNKNOWN = prochaine étape probablement active
```

car elle classait incorrectement `005`.

---

---

# 20. Modèle actuel des quêtes

Le modèle antérieur :

```text
si quest KNOW != 0 -> COMPLETED
sinon si une entry est TRUE -> IN_PROGRESS
sinon -> NOT_STARTED
```

était utile pour explorer le JournalRegistry, mais il mélangeait progression personnelle, état du monde, disponibilité logique, conditions runtime et synchronisation multijoueur.

Il ne doit plus servir de vérité fonctionnelle principale.

## `PlayerQuest` et `WorldQuest`

```text
si KNOW[quest.entryId] != 0
    COMPLETED_PERSONALLY
sinon
    NOT_COMPLETED_PERSONALLY
```

Ce modèle est fortement soutenu par l’expérience multijoueur contrôlée : aucune `PlayerQuest` ni `WorldQuest` n’a reçu son marqueur top-level lorsque le personnage vierge a simplement rejoint le monde avancé.

## `Auto`

```text
si KNOW[quest.entryId] != 0
    RESOLVED_UNKNOWN_ORIGIN
sinon
    NOT_RESOLVED
```

Pour une `Auto`, le marqueur top-level peut être acquis personnellement ou injecté/synchronisé depuis l’état du monde. La sauvegarde personnage analysée seule ne permet pas de distinguer ces deux cas de manière générale.

## Sous-étapes

Les `knowledgeRequirement`, `completionRequirement` et queries restent exploitables pour :

* expliquer pourquoi une étape est évaluée vraie/fausse/inconnue ;
* afficher une progression diagnostique ;
* comprendre les dépendances internes ;
* effectuer du reverse engineering ciblé.

Ils ne doivent plus être utilisés pour affirmer qu’une action a été personnellement réalisée.

---

# 21. Refactoring de uJournalEvaluator

La fonction `DumpJournalQuestState` était devenue trop complexe.

Elle a été restructurée autour de modèles de données séparés.

Structures principales :

```text
TJournalEntryState
TJournalEntryStates
TJournalQuestState
```

Responsabilités séparées :

```text
EvaluateJournalEntry
    -> évalue une sous-entrée

EvaluateJournalQuest
    -> construit l’état complet d’une quête

InferQuestProgress
    -> calcule le statut global

DumpJournalQuestStateResult
    -> affichage uniquement

DumpJournalQuestState
    -> orchestration minimale
```

Ce découpage permet de réutiliser l’évaluation indépendamment de l’affichage.

---

---

# 22. Inventaire global du JournalRegistry

Un mode :

```text
--journal-all
```

a permis de parcourir tous les objets ayant :

```text
entryId
entries[]
```

Résultat initial :

```text
451 objets
90 COMPLETED
163 IN_PROGRESS
198 NOT_STARTED
0 UNKNOWN
```

Mais le jeu n’affiche que :

```text
61 quêtes complétées
```

Cela a montré que les 451 objets ne sont pas tous des quêtes.

---

---

# 23. Classification des objets Journal

Un mode :

```text
--journal-inventory
```

a été ajouté pour examiner :

```text
ID
Name
type
loreCategory
isTutorial
source
EntryCount
Direct KNOW
```

Résultats :

```text
Objects              : 451
Tutorial=true        : 25
Tutorial=false       : 426
Direct KNOW present  : 90
Direct KNOW non-zero : 90
```

Types :

```text
Auto        : 136
WorldQuest  : 17
PlayerQuest : 15
(empty)     : 283
```

`loreCategory` :

```text
(empty) : 451
```

---

---

# 24. Classification provisoire très solide

Les données indiquent désormais :

## Quêtes

```text
type = Auto
type = WorldQuest
type = PlayerQuest
```

Total :

```text
168
```

## Tutoriels

```text
type = ""
isTutorial = true
```

Total :

```text
25
```

Exemples :

```text
The Flameborn
The Shroud
The Flame
Landscaping
Building
Combat
Character Skills
Gear
The Glider
The Grappling Hook
Fishing
```

## Lore

```text
type = ""
isTutorial = false
```

Total :

```text
258
```

Exemples :

```text
Captain's Journal
Ancient Obelisk I
Ancient Obelisk II
Tavern Stories
Hunter's Notes
Kennel Notes
The Barber's Salons
...
```

Cette classification n’est pas encore codée comme vérité définitive mais elle est suffisamment forte pour servir de base.

---

---

# 25. `loreCategory`

Dans la version étudiée :

```text
loreCategory = ""
```

pour les 451 objets.

Ce champ ne semble donc actuellement pas utile pour distinguer les familles.

---

---

# 26. `source`

Les objets de quête typés possèdent généralement un `source`.

Exemples :

```text
Alchemist
Blacksmith
Bard
Carpenter
Huntress
Farmer
CryptKeeper
ChineseNewYearTrader
Fisher
Flame
Grassland
Deepforest
Steppes
Desert
ColdHeights
Wetlands
Barber
None
```

Les 283 objets de type vide ont également :

```text
source=""
```

dans l’inventaire global.

Le champ `source` constitue donc un discriminant supplémentaire très utile entre :

```text
QUEST
```

et :

```text
LORE / TUTORIAL
```

---

---

# 27. Les marqueurs directs de quête et l’écart avec l’interface

Sur le personnage avancé, de nombreux objets de quête possèdent :

```text
KNOW[quest.entryId] != 0
```

Le comptage historique donnait :

```text
90 marqueurs directs
```

alors que l’interface du jeu affichait environ :

```text
61 quêtes complétées
```

Cet écart ne doit plus être utilisé comme cible à reproduire exactement.

Nous savons maintenant qu’au moins plusieurs mécanismes peuvent l’expliquer :

* quêtes `Auto` synchronisées depuis le monde ;
* variantes internes / doublons fonctionnels ;
* filtres et regroupements propres à l’interface ;
* quêtes masquées, manquées ou représentées différemment ;
* objets internes ayant un rôle de journal mais pas nécessairement une ligne visible indépendante.

L’objectif du projet n’est donc pas de reproduire le compteur de l’interface, mais de reconstruire une classification fiable à partir de l’état persistant.

---

# 28. Doublons / variantes de quêtes

Certaines quêtes possèdent plusieurs objets distincts avec le même nom.

Exemples :

```text
The Alchemist's Mortar

$77E74BE5
entries=1
KNOW=1

$093F8375
entries=5
KNOW=1
```

Autre exemple :

```text
Black Cauldron

$F0303CB8
entries=1
KNOW=1

$7F9D2CDE
entries=4
KNOW=absent
```

Il existe donc manifestement :

* des variantes ;
* des sous-objets ;
* ou plusieurs représentations internes liées à la même quête visible.

Mais les doublons de nom identifiés ne suffisent pas, à eux seuls, à expliquer les 29 entrées supplémentaires.

---

---

# 29. GameKnowledge player et world

Une découverte structurante est qu’un même identifiant logique de GameKnowledge peut exister sous plusieurs définitions dans `GameKnowledgeResource`.

On observe notamment des variantes :

```text
isPlayerKnowledge = false
```

et :

```text
isPlayerKnowledge = true
```

pour un même ID.

Exemples observés pendant l’étude de `Claim A Spot For Your Base` :

```text
4E7CCCFE
0FDC3003
9217A4E9
```

possèdent des variantes world/non-player et player dans les ressources, avec souvent :

```text
hasOptionalPlayerProgression = true
```

Cette architecture est compatible avec le modèle suivant :

```text
même Knowledge logique
    |
    +-- état monde
    |
    +-- état de progression du joueur
```

Le moteur de jeu peut utiliser l’état monde pour sa logique fonctionnelle tout en conservant une progression liée au joueur.

Important : le blob KNOW extrait d’un `characters-*` est ici utilisé comme **état du personnage**. La présence d’un ID dans ce blob ne signifie pas que l’état monde correspondant est également connu ou disponible.

Le champ `hasOptionalPlayerProgression` est un indice fort de cette dualité, mais sa sémantique exacte n’a pas besoin d’être reproduite pour le fonctionnement principal de l’outil.

---

# 30. Expérience multijoueur contrôlée — résultats

Un nouveau personnage :

```text
OwnerID = A3944272
```

a été utilisé dans trois états :

```text
A = virgin_before_world
B = virgin_after_joining_shared_world
C = virgin_after_joining_and_talking_to_flame
```

## A — personnage vierge sur monde vierge

Le KNOW contient seulement :

```text
9841FA85 = 1
```

## A -> B — arrivée dans le monde avancé sans action volontaire

Le KNOW passe de 1 entrée à 61 entrées, soit :

```text
+60 IDs
```

Ce diff prouve qu’un monde avancé injecte/synchronise automatiquement des connaissances vers un personnage neuf.

Parmi ces 60 IDs, exactement 10 correspondent directement à des `quest.entryId` :

```text
019F1A5E  Hunter Needs Shelter
14CF4B94  Flame Altar And Base Improvements
203D9E24  Barber Needs Shelter
33918DF7  Farmer Needs Shelter
41D55510  Carpenter Needs Shelter
5D25DBE1  Bard Needs Shelter
8755C335  Alchemist Needs Shelter
CB5D2C1F  Flame Altar And Base Improvements
E26BD571  The Blacksmith Needs A Shop
FC8E9374  Collector Needs Shelter
```

Point crucial :

```text
les 10 sont de type Auto
```

Aucune `PlayerQuest` ni `WorldQuest` n’a reçu de marqueur top-level dans cette expérience.

Le mode `--journal-quests` confirme :

```text
168 objets de quête
10 RESOLVED
0 IN_PROGRESS
158 NOT_STARTED
```

et les 10 `RESOLVED` sont précisément ces quêtes `Auto`.

Le champ :

```text
unlockForAllPlayers
```

est `false` pour ces quêtes et n’explique donc pas le phénomène.

## B -> C — interaction avec la Flamme

Six nouveaux IDs apparaissent :

```text
D40E6C24
A1600A31
D049BA3D
8532B5D3
4F13E37B
0FDC474E
```

Aucun n’est un `quest.entryId` top-level.

Il existe donc plusieurs mécanismes de synchronisation, mais l’arrivée dans le monde suffit déjà à démontrer l’héritage de certaines `Auto`.

---

# 31. Sémantique des types de quête

Les trois types de quête doivent désormais être traités différemment.

## `PlayerQuest`

Observation actuelle :

```text
marqueur top-level non propagé au personnage vierge
```

Interprétation de référence :

```text
KNOW[quest.entryId] != 0
-> quête terminée personnellement
```

## `WorldQuest`

Observation actuelle :

```text
marqueur top-level non propagé au personnage vierge
```

Le cas contrôlé `Claim A Spot For Your Base` confirme qu’un marqueur top-level apparaît lorsque le personnage termine réellement la quête.

Interprétation de référence :

```text
KNOW[quest.entryId] != 0
-> quête terminée personnellement
```

Une `WorldQuest` peut toutefois contenir des conditions purement monde. Exemple :

```text
Veilwater Basin Flame Upgrade
```

dont l’unique étape observe essentiellement un état d’amélioration de la Flamme. Les requirements de cette étape ne doivent donc pas être confondus avec une preuve d’action personnelle.

## `Auto`

Certaines peuvent être jouées normalement et laisser une progression détaillée. Exemple étudié :

```text
Slaying The Corrupted Beast
```

Le personnage avancé possède notamment :

```text
5CD1A409  _started
F01CB7F9  _reached
3C4F22C0  fire_01
E6F39FB3  fire_02
1EDBF50E  fire_03
950FFB67  fire_04
483CF72C  fire_05
D228B53D  fire_06
64397A19  fire_07
872EE24B  fire_08
2B1F9FC8  boss_killed
BBBE8AD9  quest completed
```

Le personnage vierge n’en possède aucun.

Cependant cela ne suffit pas à faire de ces marqueurs une preuve générale de provenance personnelle, car d’autres `Auto` sont entièrement synchronisées depuis le monde.

Conclusion :

```text
Auto + quest.entryId absent
    -> NOT_RESOLVED

Auto + quest.entryId présent
    -> RESOLVED_UNKNOWN_ORIGIN
```

---

# 32. Outils actuels

## EnshroudedDump

Usage :

```text
EnshroudedDump --dump <characters-file> <OwnerID> [max entries]
EnshroudedDump --dump-keys <characters-file> <OwnerID> <output.txt>
EnshroudedDump --diff <file1> <file2> <OwnerID>
```

Exemples :

```text
EnshroudedDump --dump .\samples\characters-3 1B551646 30
EnshroudedDump --dump-keys .\samples\characters-3 1B551646 know_keys.txt
EnshroudedDump --diff .\samples\before\characters-5 .\samples\after\characters-6 2AF68BE4
```

Il n’existe pas de :

```text
--dump-know
```

La génération de dumps KNOW appartient à `EnshroudedDump.exe`.

## EnshroudedKnowledgeGraph

Modes utilisés :

```text
--query
--eval-query
--eval-query-trace
--journal-state
--journal-all
--journal-inventory
--journal-quests
--journal-quest-inventory
```

Syntaxe confirmée de `--journal-state` :

```text
EnshroudedKnowledgeGraph --journal-state <Journal.json> <QueryDb.json> <know_keys.txt> <QuestID>
```

---

# 33. Localisation

Les fichiers DAT contiennent les chaînes localisées.

Structure identifiée d’un record de localisation :

```text
+00 uint32 LocalizationID
+04 uint32 RelativeStringOffset
+08 uint32 StringLength
+0C uint32 Unknown0C
+10 uint32 Unknown10
+14 uint32 Unknown14
```

Adresse de la chaîne :

```text
(RecordOffset + 4) + RelativeStringOffset
```

Table anglaise identifiée dans :

```text
enshrouded_016.dat
```

Paramètres observés :

```text
Seed  = 0x3F95ABE0
Start = 0x3F91A008
End   = 0x3F96D768
```

Nombre d’entrées :

```text
14245
```

`uLocalization.pas` charge ces entrées et permet une recherche par ID.

Exemples :

```text
C6CDFD78 = Claim A Spot For Your Base
C83817CF = Reach The Plains
A8360EC4 = Build A Flame Altar
6AD30566 = Talk To The Flame
```

---

---

# 34. Architecture actuelle du code

Répertoire :

```text
src\
```

Fichiers :

```text
EnshroudedKnowledgeGraph.lpr
EnshroudedLocaDump.lpr
EnshroudedDump.lpr

uLocalization.pas
uZstd.pas
uKnowledge.pas
uQueryModel.pas
uQueryEvaluator.pas
uJournalEvaluator.pas
```

Principe architectural retenu :

```text
parsing
   séparé de
évaluation
   séparée de
présentation
```

Ce principe est important pour la future interface Lazarus.

---

---

# 35. Direction fonctionnelle du projet

Le projet évolue maintenant vers un :

```text
Enshrouded Progress Explorer
```

plutôt qu’un simple lecteur de quêtes.

Les familles pertinentes sont :

```text
QUEST
LORE
TUTORIAL
POI
```

et potentiellement plus tard :

```text
RECIPES
ITEM KNOWLEDGE
CRAFTING UNLOCKS
ACHIEVEMENTS / EVENTS
```

---

---

# 36. Modèle fonctionnel par famille

## QUEST

La classification primaire doit porter sur la **progression personnelle**, et non sur la disponibilité actuelle de la quête.

États recommandés :

```text
COMPLETED_PERSONALLY
NOT_COMPLETED_PERSONALLY
RESOLVED_UNKNOWN_ORIGIN
NOT_RESOLVED
```

Règles :

```text
PlayerQuest / WorldQuest:
    quest KNOW != 0 -> COMPLETED_PERSONALLY
    sinon           -> NOT_COMPLETED_PERSONALLY

Auto:
    quest KNOW != 0 -> RESOLVED_UNKNOWN_ORIGIN
    sinon           -> NOT_RESOLVED
```

Les états `IN_PROGRESS` calculés à partir des requirements ne sont plus nécessaires à la fonctionnalité principale. Ils peuvent rester disponibles comme information diagnostique secondaire.

## LORE

États visés :

```text
UNDISCOVERED
PARTIAL
COMPLETE
```

avec :

```text
X / N entries discovered
```

Le stockage exact des sous-entries reste à déterminer.

## TUTORIAL

États visés :

```text
LOCKED
UNLOCKED
```

ou progression par sous-pages si les marqueurs permettent de la reconstruire.

## POI

États :

```text
UNDISCOVERED
DISCOVERED
```

à partir des `MapMarkerUnlockRequirements` et GameKnowledge associés.

Le cas Cinder Vault constitue déjà une preuve de faisabilité.

---

# 37. Points encore non résolus

La partie **classification principale des quêtes** est désormais considérée comme suffisamment comprise pour être implémentée.

Les questions encore ouvertes concernent principalement les autres familles et les détails secondaires.

### 1. Provenance exacte des quêtes `Auto`

Pour une `Auto` avec :

```text
KNOW[quest.entryId] = 1
```

il n’est pas possible, à partir de la seule sauvegarde personnage testée, de distinguer de manière générale :

```text
faite personnellement
```

de :

```text
synchronisée / héritée du monde
```

Les expériences sur `Alchemist Needs Shelter` et les deux `Flame Altar And Base Improvements` montrent qu’un personnage vierge peut obtenir un état fonctionnel entièrement indistinguable d’une quête complétée.

Ce point n’est plus bloquant : l’état `RESOLVED_UNKNOWN_ORIGIN` est la représentation correcte.

### 2. Doublons et variantes internes

Plusieurs objets peuvent partager le même nom ou représenter différentes variantes fonctionnelles.

L’identité doit toujours rester :

```text
entryId
```

et jamais le texte localisé.

Une future couche de regroupement UI pourra utiliser `priority`, `source`, le nombre d’entries et les relations entre objets, mais elle ne doit pas fusionner automatiquement des objets sur le seul nom.

### 3. Progression du lore

Les objets lore n’ont généralement pas :

```text
KNOW[lore.entryId]
```

dans le personnage avancé. Il faut encore déterminer les marqueurs de découverte de leurs sous-entries.

### 4. Progression des tutoriels

Même problème : le `entryId` du tutoriel n’apparaît pas directement comme marqueur top-level exploitable. Les sous-conditions devront être étudiées.

### 5. Disponibilité réelle des quêtes

La disponibilité actuelle dépend parfois du monde, de primitives runtime, d’objets présents, de NPC ou de compteurs comme `FlameAltarCount`.

Cette information n’est pas nécessaire pour le premier objectif de l’outil et ne doit pas bloquer le développement.

---

# 38. Conclusions solides à ce stade

Les points suivants constituent désormais le référentiel de développement.

```text
1. Le format KSC1 est compris.

2. Les blobs KNOW peuvent être extraits et décodés.

3. KNOW est une table générique uint32 -> uint32.

4. Les valeurs KNOW peuvent être booléennes ou bitfields.

5. Les IDs du KNOW ne sont pas garantis triés.

6. Les conditions du QueryDb peuvent être évaluées partiellement.

7. Certaines conditions sont runtime ou world-only et doivent rester UNKNOWN.

8. Un entryId est l’identité fiable d’un objet Journal.
   Le texte localisé ne doit jamais servir d’identifiant.

9. JournalRegistry contient plusieurs familles d’objets.

10. type=Auto / WorldQuest / PlayerQuest correspond aux quêtes.

11. type="" + isTutorial=true correspond aux tutoriels.

12. type="" + isTutorial=false correspond très probablement au lore.

13. Le cas Cinder Vault démontre qu’un POI peut être relié à un
    GameKnowledge persistant via ses unlock requirements.

14. Sur Claim A Spot For Your Base, le marqueur top-level B22F436D
    apparaît exactement à la complétion personnelle.

15. Un personnage vierge rejoignant un monde avancé reçoit de nombreux
    KNOW automatiquement.

16. Parmi les quest.entryId hérités observés dans cette expérience,
    tous sont de type Auto.

17. Aucune PlayerQuest ni WorldQuest n’a reçu son marqueur top-level
    dans cette expérience.

18. Pour PlayerQuest et WorldQuest :
        quest KNOW != 0
        est retenu comme indicateur de complétion personnelle.

19. Pour Auto :
        quest KNOW != 0
        signifie seulement "résolue pour ce personnage",
        avec origine personnelle ou héritée indéterminable.

20. Les requirements de sous-étapes décrivent un état logique actuel
    et ne constituent pas une preuve de provenance personnelle.

21. Une Auto héritée peut avoir exactement le même état de journal
    qu’une Auto réellement accomplie.

22. Il n’est donc pas nécessaire de reconstruire le world KNOW ou
    toutes les primitives runtime pour implémenter la partie quêtes.

23. L’objectif n’est pas de reproduire exactement les compteurs de
    l’interface du jeu mais de fournir un état persistant explicable
    et fiable.
```

---

# 39. Prochaine étape prévue

Le reverse engineering principal de la partie **quêtes** est considéré comme suffisant.

La prochaine étape est de reprendre `uJournalEvaluator` et le modèle métier autour des règles stabilisées.

Priorités :

```text
1. Introduire un statut de progression personnelle explicite.

2. Classer les PlayerQuest et WorldQuest via leur marqueur top-level.

3. Classer les Auto séparément avec RESOLVED_UNKNOWN_ORIGIN.

4. Ne plus utiliser InferQuestProgress / availability comme vérité
   principale pour la provenance personnelle.

5. Conserver l’évaluation des requirements comme couche diagnostique
   secondaire.

6. Produire une API de données propre, indépendante du dump console,
   utilisable ensuite par l’interface Lazarus.

7. Après stabilisation des quêtes, passer au lore, aux tutoriels puis
   aux POI.
```

Modèle métier recommandé :

```text
TQuestPersonalStatus
    qpsNotCompleted
    qpsCompletedPersonally
    qpsResolvedUnknownOrigin
```

Interprétation :

```text
PlayerQuest / WorldQuest:
    absent  -> qpsNotCompleted
    présent -> qpsCompletedPersonally

Auto:
    absent  -> qpsNotCompleted
    présent -> qpsResolvedUnknownOrigin
```

Le détail des sous-étapes peut continuer à être exposé séparément, sans modifier cette classification primaire.

---

