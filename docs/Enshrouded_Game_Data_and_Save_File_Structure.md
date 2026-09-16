# Enshrouded — Game Data and Save File Structure

> **Shareable technical document — September 16, 2026**
>
> This document summarizes the structures that were actually observed and validated during the development of **EnshroudedSaveExplorer**. It does not claim to document every internal Enshrouded file format.
>
> Information is classified into three levels:
>
> * **validated**: reproduced by a parser and tested against real data;
> * **partially understood**: sufficiently understood to extract specific information, but the full schema remains unknown;
> * **not characterized**: known to exist, but not investigated by this project.

---

## 1. Overview

A Steam installation of Enshrouded contains, among other files:

```text
Enshrouded/
├── enshrouded.exe
├── enshrouded.kfc
├── enshrouded.kfc_resources
├── enshrouded_000.dat
├── enshrouded_001.dat
├── ...
├── enshrouded_031.dat
└── enshrouded_local.json
```

Steam character saves are typically stored under:

```text
Steam/
└── userdata/
    └── <AccountID>/
        └── 1203620/
            └── remote/
                ├── characters-index
                ├── characters
                ├── characters-1
                ├── ...
                └── characters-9
```

The game installation itself may live either in Steam's primary library or in a secondary library declared in:

```text
steamapps/libraryfolders.vdf
```

Enshrouded's Steam AppID is:

```text
1203620
```

---

# 2. `enshrouded.kfc` and `enshrouded.kfc_resources`

**Status: validated for targeted resource extraction.**

The current game uses a resource index identified by:

```text
KFC3
```

The little-endian magic value is:

```text
0x3343464B
```

The two files have complementary roles:

```text
enshrouded.kfc
    resource index, keys, values and chunk metadata

enshrouded.kfc_resources
    compressed resource chunk data
```

## 2.1 KFC3 header

After the first 16 bytes, the header contains 16 structures referred to here as `KFCLocation`.

A `KFCLocation` contains:

```c
uint32 relative_offset;
uint32 count;
```

The offset is relative to **the position of the `relative_offset` field itself**:

```text
absolute_offset =
    position_of_relative_offset_field
    + relative_offset
```

The currently relevant locations are:

```text
 0 version
 1 containers
 2 unused0
 3 unused1
 4 resource_locations
 5 resource_indices
 6 content_buckets
 7 content_keys
 8 content_values
 9 resource_buckets
10 resource_keys
11 resource_values
12 resource_bundle_buckets
13 resource_bundle_keys
14 resource_bundle_values
15 resource_chunks
```

## 2.2 Resource key

An entry in `resource_keys` is 32 bytes:

```c
byte   guid[16];
uint32 type_hash;
uint32 part_index;
uint32 reserved_0;
uint32 reserved_1;
```

A resource can therefore be located using the tuple:

```text
GUID + type hash + part index
```

There is no need to hardcode its numeric index in the KFC.

## 2.3 Resource value

An entry in `resource_values` is 8 bytes:

```c
uint32 offset;
uint32 size;
```

`offset` refers to the logical **decompressed** resource address space.

## 2.4 Chunks

An entry in `resource_chunks` contains:

```c
uint32 file_offset;
uint32 size;
uint32 compressed_size;
uint32 uncompressed_offset;
uint32 uncompressed_size;
```

The chunk covering the logical range of a resource is read from:

```text
enshrouded.kfc_resources
```

and decompressed with Zstandard.

The final resource is then sliced from the decompressed chunk at:

```text
resource.offset - chunk.uncompressed_offset
```

## 2.5 JournalRegistryResource

The project directly extracts `JournalRegistryResource` using:

```text
GUID      33701b26-ec1d-423f-8e06-49f023b91b7f
type hash 0x60B5ED8A
part      0
```

The physical index and offsets observed in a specific build may change and should not be treated as stable identifiers.

---

# 3. Reflection metadata inside `enshrouded.exe`

**Status: validated for reconstructing the schemas needed by JournalRegistry; full format not documented.**

Binary KFC resources are not fully self-describing. Type metadata required to understand them was located inside `enshrouded.exe`.

A type metadata structure contains, among other fields:

```text
+00  char* name
+08  uint64 name_len
+10  char* impact_name
+18  uint64 impact_name_len
+20  char* qualified_name
+28  uint64 qualified_name_len
+30  Namespace*
+38  TypeMetadata* inner_type
+40  uint32 size
+44  uint16 alignment
+46  uint16 element_alignment
+48  uint32 field_count
+4C  uint8 primitive_type
+4D  uint8 flags
+50  uint32 qualified_hash
+54  uint32 internal_hash
+58  StructFieldMetadata* fields
+60  EnumFieldMetadata* enums
```

An observed struct field metadata entry is 48 bytes:

```text
+00  char* name
+08  uint64 name_len
+10  TypeMetadata* type
+18  uint64 data_offset
+20  Attribute* attributes
+28  uint64 attributes_count
```

These metadata structures were sufficient to derive the JournalRegistry schema below.

---

# 4. JournalRegistryResource

**Status: validated.**

The observed root structure is 32 bytes:

```text
+00 quests             BlobArray
+08 collections        BlobArray
+16 itemSetCategories  BlobArray
+24 itemSetRewards     BlobArray
```

## 4.1 BlobArray

A `BlobArray` is represented as:

```c
uint32 relative_blob_offset;
uint32 count;
```

The address of the first element is:

```text
field_position + relative_blob_offset
```

## 4.2 Common journal object

Observed size:

```text
32 bytes
```

Structure:

```text
+00 entryId
+04 loreCategory
+08 name
+12 referencedDocumentName
+16 priority
+20 isTutorial
+24 entries BlobArray
```

## 4.3 Quest

Observed size:

```text
44 bytes
```

It extends the common object with:

```text
+32 source
+33 type
+34 unlockForAllPlayers
+35 padding
+36 rewards BlobArray
```

Observed quest types:

```text
0 Auto
1 WorldQuest
2 PlayerQuest
```

Observed quest sources:

```text
0  None
1  Flame
2  Blacksmith
3  Alchemist
4  Huntress
5  Farmer
6  Carpenter
7  CryptKeeper
8  Bard
9  ChineseNewYearTrader
10 Barber
11 Fisher
12 AncientResearcher
13 Grassland
14 Deepforest
15 Steppes
16 Desert
17 ColdHeights
18 Wetlands
```

## 4.4 Journal entry

Observed size:

```text
72 bytes
```

Structure:

```text
+00 entryId
+04 name
+08 text
+12 mapMarkerReference
+16 knowledgeRequirement        12 bytes
+28 completionRequirement       12 bytes
+40 progressStepsRequirement    BlobArray
+48 voiceover
+64 itemIconId
+68 recommendedLevel
```

## 4.5 Requirement

Size:

```text
12 bytes
```

Structure:

```text
+00 uint32 knowledgeOrQueryId
+04 uint32 compareValue
+08 uint8  compareOperator
+09 uint8  type
+10 bool   isExplicitPlayerKnowledgeQuery
+11 padding
```

Observed enums:

```text
compareOperator
0 GreaterThan
1 LessThan
2 Equals

type
0 Extern
1 SimpleBool
2 SimpleCount
3 SimpleFlag
```

---

# 5. `enshrouded_XXX.dat` files

**Status: partially understood.**

Multiple files exist:

```text
enshrouded_000.dat
...
enshrouded_031.dat
```

The project has validated two important facts:

1. the numeric suffix **does not identify the purpose of the file**;
2. at least one of these files contains a usable localization table.

A strategy that simply selected the highest suffix picked the wrong file. Therefore `.dat` files must be identified by **content**, not by their number.

## 5.1 Localization table

A localization table was validated around a known seed offset in the studied build:

```text
0x3F95ABE0
```

Each entry is 24 bytes:

```c
struct LocaEntry {
    uint32 id;
    uint32 relative_offset;
    uint32 length;
    uint32 unknown_0C;
    uint32 unknown_10;
    uint32 unknown_14;
};
```

The string address is:

```text
record_offset + 4 + relative_offset
```

An entry is considered plausible when:

* `id != 0`;
* `length != 0`;
* the length remains within reasonable bounds;
* the string stays within file bounds;
* the content is valid UTF-8.

The table is reconstructed by walking backward and forward in 24-byte steps while entries remain plausible and IDs stay strictly increasing.

The program currently tests every:

```text
enshrouded_*.dat
```

and keeps the candidate that yields the largest valid table.

### Limitation

The seed offset is a reverse-engineered constant from the studied build. It may need to be revalidated after a major game update.

## 5.2 Other `.dat` contents

**Not characterized by this project.**

The fact that a `.dat` file does not contain the localization table at the known seed does not establish what that file actually contains.

---

# 6. Character saves: `characters-index`

**Status: validated.**

`characters-index` is a small JSON file used to select the active generation of the rolling save.

It contains, among other data:

```json
{
  "latest": 7
}
```

The observed value range is:

```text
0 to 9
```

Resolution:

```text
latest = 0
    -> characters

latest = 1
    -> characters-1

...

latest = 9
    -> characters-9
```

A tool must therefore not assume that the unsuffixed `characters` file is always the newest save.

---

# 7. `characters` / `characters-N` files

**Status: KSC1 container validated.**

These files begin with:

```text
KSC1
```

## 7.1 Header

Structure:

```c
char   magic[4];      // "KSC1"
uint32 blob_count;
byte   save_id[16];
```

Equivalent layout:

```text
offset 0x00  "KSC1"
offset 0x04  BlobCount
offset 0x08  SaveID[16]
offset 0x18  beginning of blob table
```

## 7.2 Blob entry

Each table entry is 12 bytes:

```c
uint32 owner_id;
byte   blob_type[4];
uint32 compressed_size;
```

The full table is followed by the compressed blob payloads concatenated in the same order.

Position of the first blob:

```text
sizeof(header) + BlobCount * 12
```

The next blob begins after adding the previous blob's `compressed_size`.

## 7.3 Compression

Blob payloads are compressed with:

```text
Zstandard
```

The project can decompress them independently.

---

# 8. OwnerID and characters

**Status: validated as an association mechanism.**

Blobs belonging to the same character share an:

```text
OwnerID
```

A single `characters-N` file can therefore contain data for multiple characters.

KNOW blobs are used to enumerate relevant character OwnerIDs; CHAR blobs carrying the same OwnerID can then be used to retrieve the associated character data.

---

# 9. KNOW blob

**Status: validated.**

The blob type is physically represented by the bytes:

```text
DC 8E D5 F0
```

Interpreted as a little-endian integer, this is:

```text
0xF0D58EDC
```

Decompressed structure:

```c
uint32 version;
uint32 unknown1;
uint32 entry_count;
uint32 ids[entry_count];
uint32 values[entry_count];
```

In the studied saves:

```text
version  = 2
unknown1 = 1
```

Total size:

```text
12 + 8 * entry_count
```

Logical association:

```text
ids[i] -> values[i]
```

Important:

```text
IDs are not necessarily sorted
```

A binary search is therefore unsafe unless the data is sorted first.

## 9.1 Meaning

KNOW is a generic persistent knowledge/progression table. It is not limited to quests.

It contains IDs associated with, among other things:

```text
GameKnowledge
quests
recipes
items
events
progress markers
```

The value must be interpreted according to the associated resource.

Validated examples:

```text
SimpleBool
    0 = false
    non-zero = true

SimpleFlag
    value is a bit field
```

For an expected flag:

```text
(actual_value AND expected_flag) = expected_flag
```

---

# 10. CHAR blob

**Status: partially understood.**

The blob type is:

```text
CHAR
```

The blob uses a BDB structure that is substantially more complex than KNOW.

The project can currently extract, reproducibly:

* character name;
* `lastPlayTime`.

This is sufficient, among other things, to automatically select the most recently played character.

The full BDB format, including its tables and pointer structures, has not yet been documented generically. The currently known fields should therefore not be treated as a complete CHAR specification.

---

# 11. Quest progress from KNOW

**Status: functional model validated through controlled experiments in the project.**

For `PlayerQuest` and `WorldQuest`:

```text
KNOW[quest.entryId] != 0
    -> strong indicator of personal completion
```

For `Auto` quests:

```text
KNOW[quest.entryId] != 0
    -> quest resolved for the character
    -> personal vs inherited/world origin cannot generally be determined
```

Internal journal requirements are useful for diagnostics and reverse engineering, but a logically satisfied condition does not necessarily prove that the player personally performed the action.

---

# 12. Lore progress from KNOW

**Status: validated for the currently studied collections.**

Lore entries mainly use requirements of the form:

```text
SimpleBool
Equals 1
```

An entry is considered discovered when its requirement ID has a non-zero value in KNOW.

A collection status can then be derived from its discovered-entry count:

```text
0 / N     -> Undiscovered
1..N-1/N  -> Partial
N / N     -> Complete
```

---

# 13. Automatic Steam discovery

**Status: validated on Windows with Steam.**

The Steam installation path is searched in the Windows registry, including:

```text
HKEY_CURRENT_USER\Software\Valve\Steam
HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Valve\Steam
HKEY_LOCAL_MACHINE\SOFTWARE\Valve\Steam
```

For save discovery, the project reads:

```text
Steam/config/loginusers.vdf
```

and prefers the account marked:

```text
"MostRecent" "1"
```

The SteamID64 is converted into an AccountID using Steam's standard base value, after which the expected save path is built under:

```text
userdata/<AccountID>/1203620/remote
```

Current fallbacks:

* automatically use the only Steam account that has an Enshrouded save;
* search for a local `characters-index` under `Saved Games/Enshrouded`.

---

# 14. What is not yet documented

The following areas should not be considered specified by this document:

* full BDB / CHAR format;
* exact purpose of every `enshrouded_XXX.dat` file;
* full world-save format;
* every possible KSC1 blob type;
* every possible KFC3 resource type;
* complete runtime logic of GameKnowledge queries;
* long-term stability of offsets and hashes across future game updates.

---

# 15. Recommendations for third-party tools

A tool reading these files should:

1. discover the Steam installation rather than assume a fixed path;
2. use `characters-index` to determine the active rolling save;
3. verify `KFC3` / `KSC1` magic values before parsing;
4. treat offsets and sizes as untrusted until checked against file bounds;
5. not assume KNOW IDs are sorted;
6. not assume a `.dat` suffix indicates its purpose;
7. locate KFC resources by resource key rather than by build-specific index;
8. tolerate build changes and fail explicitly when a reverse-engineered constant no longer matches;
9. distinguish persistent save-state facts from runtime/non-persistent conditions;
10. never infer personal origin for an `Auto` quest from its top-level marker alone.

---

# 16. Knowledge status summary

| Element | Status |
|---|---|
| `KFC3` header / resource keys / values / chunks | Validated |
| KFC chunk decompression | Validated |
| Targeted extraction of `JournalRegistryResource` | Validated |
| Required `JournalRegistryResource` schema | Validated |
| Reflection table inside `enshrouded.exe` | Partially documented, used successfully |
| Exact role of all `.dat` files | Unknown |
| Localization table inside a `.dat` | Validated |
| Selecting a `.dat` by numeric suffix | Incorrect / should not be done |
| `characters-index` | Validated |
| KSC1 | Validated |
| KNOW | Validated |
| Full CHAR / BDB format | Partially understood |
| Character name inside CHAR | Validated |
| `lastPlayTime` inside CHAR | Validated for the current extraction method |
| World saves | Not characterized here |
