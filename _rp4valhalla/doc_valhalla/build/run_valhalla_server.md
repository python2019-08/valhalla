# Build from Source
[¶](https://valhalla.github.io/valhalla/start/building/#build-from-source) 

<!-- 略 -->

## Running Valhalla server on Unix 

The following script should be enough to make some routing data and
start a server using it.
 
Tip 
> Instructions for [running an **elevation lookup service**](https://valhalla.github.io/valhalla/concepts/elevation/) with Valhalla.



```sh
# download some data and make tiles out of it
# NOTE: you can feed multiple extracts into pbfgraphbuilder
wget https://download.geofabrik.de/europe/switzerland-latest.osm.pbf https://download.geofabrik.de/europe/liechtenstein-latest.osm.pbf

# get the config and setup
mkdir -p valhalla_tiles
valhalla_build_config --mjolnir-tile-dir ${PWD}/valhalla_tiles --mjolnir-tile-extract ${PWD}/valhalla_tiles.tar --mjolnir-timezone ${PWD}/valhalla_tiles/timezones.sqlite --mjolnir-admin ${PWD}/valhalla_tiles/admins.sqlite > valhalla.json

# build timezones.sqlite to support time-dependent routing
valhalla_build_timezones > valhalla_tiles/timezones.sqlite

# build admins.sqlite to support admin-related properties such as access restrictions, driving side, ISO codes etc
valhalla_build_admins -c valhalla.json switzerland-latest.osm.pbf liechtenstein-latest.osm.pbf

# build routing tiles
valhalla_build_tiles -c valhalla.json switzerland-latest.osm.pbf liechtenstein-latest.osm.pbf

# tar it up for running the server
# either run this to build a tile index for faster graph loading times
valhalla_build_extract -c valhalla.json -v

# or simply tar up the tiles
find valhalla_tiles | sort -n | tar cf valhalla_tiles.tar --no-recursion -T -

# grab the demos repo and open up the point and click routing sample
git clone --depth=1 --recurse-submodules --single-branch --branch=gh-pages https://github.com/valhalla/demos.git
firefox demos/routing/index-internal.html &
# NOTE: set the environment pulldown to 'localhost' to point it at your own server

# start up the server
valhalla_service valhalla.json 1

# curl it directly if you like:
curl http://localhost:8002/route --data '{"locations":[{"lat":47.365109,"lon":8.546824,"type":"break","city":"Zürich","state":"Altstadt"},{"lat":47.108878,"lon":8.394801,"type":"break","city":"6037 Root","state":"Untere Waldstrasse"}],"costing":"auto","directions_options":{"units":"miles"}}' | jq '.' 
``` 


## my steps^-^

```sh
REPO_Path=/mnt/a2disk/a2/zdev/nv/osrm/valhalla
bdExePath=${REPO_Path}/build_vcpkg
bdDatPath=${REPO_Path}/_databd
rawDatPath=${REPO_Path}/_data

# (1) download raw data
# download some data and make tiles out of it
# NOTE: you can feed multiple extracts into pbfgraphbuilder
cd ${rawDatPath}
wget https://download.geofabrik.de/europe/switzerland-latest.osm.pbf https://download.geofabrik.de/europe/liechtenstein-latest.osm.pbf

# (2)get the config and setup
mkdir -p ${bdDatPath}/valhalla_tiles

${bdExePath}/valhalla_build_config \
  --mjolnir-tile-dir     ${bdDatPath}/valhalla_tiles \
  --mjolnir-tile-extract ${bdDatPath}/valhalla_tiles.tar \
  --mjolnir-timezone     ${bdDatPath}/valhalla_tiles/timezones.sqlite \
  --mjolnir-admin        ${bdDatPath}/valhalla_tiles/admins.sqlite > ${bdDatPath}/valhalla.json

# (3)valhalla_build_timezones
# build timezones.sqlite to support time-dependent routing
${bdExePath}/valhalla_build_timezones > ${bdDatPath}/valhalla_tiles/timezones.sqlite

# (4)build admins.sqlite
# build admins.sqlite to support admin-related properties such as access restrictions, driving side, ISO codes etc
${bdExePath}/valhalla_build_admins -c ${bdDatPath}/valhalla.json ${rawDatPath}/switzerland-latest.osm.pbf  ${rawDatPath}/liechtenstein-latest.osm.pbf

# (5)build routing tiles
${bdExePath}/valhalla_build_tiles -c ${bdDatPath}/valhalla.json ${rawDatPath}/switzerland-latest.osm.pbf ${rawDatPath}/liechtenstein-latest.osm.pbf

# (6)tar it up for running the server
# either run this to build a tile index for faster graph loading times
${bdExePath}/valhalla_build_extract -c ${bdDatPath}/valhalla.json -v

# or simply tar up the tiles
find ${bdDatPath}/valhalla_tiles | sort -n | tar cf valhalla_tiles_onlytar.tar --no-recursion -T -

# (7) 
# grab the demos repo and open up the point and click routing sample
git clone --depth=1 --recurse-submodules --single-branch --branch=gh-pages https://github.com/valhalla/demos.git
firefox demos/routing/index-internal.html &
# NOTE: set the environment pulldown to 'localhost' to point it at your own server

# start up the server
${bdExePath}/valhalla_service ${bdDatPath}/valhalla.json 1

# curl it directly if you like:
curl http://localhost:8002/route --data '{"locations":[{"lat":47.365109,"lon":8.546824,"type":"break","city":"Zürich","state":"Altstadt"},{"lat":47.108878,"lon":8.394801,"type":"break","city":"6037 Root","state":"Untere Waldstrasse"}],"costing":"auto","directions_options":{"units":"miles"}}' | jq '.' 
``` 

### step3.valhalla_build_timezones

```sh
(base) a@a-X:~/valhalla$ ${bdExePath}/valhalla_build_timezones > ${bdDatPath}/valhalla_tiles/timezones.sqlite

downloading timezone polygon file.
Archive:  ./timezones-with-oceans-1970.shapefile.zip
  inflating: combined-shapefile-with-oceans-1970.dbf  
  inflating: combined-shapefile-with-oceans-1970.prj  
  inflating: combined-shapefile-with-oceans-1970.shp  
  inflating: combined-shapefile-with-oceans-1970.shx  
SQLite version: 3.45.1
SpatiaLite version: 5.1.0
Inserted 304 rows into 'tz_world' from './combined-shapefile-with-oceans-1970.shp'
SpatiaLite version ..: 5.1.0	Supported Extensions:
	- 'VirtualShape'	[direct Shapefile access]
	- 'VirtualDbf'		[direct DBF access]
	- 'VirtualText'		[direct CSV/TXT access]
	- 'VirtualGeoJSON'		[direct GeoJSON access]
	- 'VirtualXL'		[direct XLS access]
	- 'VirtualNetwork'	[Dijkstra shortest path - obsolete]
	- 'RTree'		[Spatial Index - R*Tree]
	- 'MbrCache'		[Spatial Index - MBR cache]
	- 'VirtualFDO'		[FDO-OGR interoperability]
	- 'VirtualBBox'		[BoundingBox tables]
	- 'VirtualSpatialIndex'	[R*Tree metahandler]
	- 'VirtualElementary'	[ElemGeoms metahandler]
	- 'VirtualRouting'	[Dijkstra shortest path - advanced]
	- 'VirtualKNN2'	[K-Nearest Neighbors metahandler]
	- 'VirtualGPKG'	[OGC GeoPackage interoperability]
	- 'VirtualXPath'	[XML Path Language - XPath]
	- 'SpatiaLite'		[Spatial SQL - OGC]
PROJ version ........: Rel. 9.4.0, March 1st, 2024
GEOS version ........: 3.12.1-CAPI-1.18.1
RTTOPO version ......: 1.1.0
TARGET CPU ..........: x86_64-linux-gnu
1
SpatiaLite version ..: 5.1.0	Supported Extensions:
	- 'VirtualShape'	[direct Shapefile access]
	- 'VirtualDbf'		[direct DBF access]
	- 'VirtualText'		[direct CSV/TXT access]
	- 'VirtualGeoJSON'		[direct GeoJSON access]
	- 'VirtualXL'		[direct XLS access]
	- 'VirtualNetwork'	[Dijkstra shortest path - obsolete]
	- 'RTree'		[Spatial Index - R*Tree]
	- 'MbrCache'		[Spatial Index - MBR cache]
	- 'VirtualFDO'		[FDO-OGR interoperability]
	- 'VirtualBBox'		[BoundingBox tables]
	- 'VirtualSpatialIndex'	[R*Tree metahandler]
	- 'VirtualElementary'	[ElemGeoms metahandler]
	- 'VirtualRouting'	[Dijkstra shortest path - advanced]
	- 'VirtualKNN2'	[K-Nearest Neighbors metahandler]
	- 'VirtualGPKG'	[OGC GeoPackage interoperability]
	- 'VirtualXPath'	[XML Path Language - XPath]
	- 'SpatiaLite'		[Spatial SQL - OGC]
PROJ version ........: Rel. 9.4.0, March 1st, 2024
GEOS version ........: 3.12.1-CAPI-1.18.1
RTTOPO version ......: 1.1.0
TARGET CPU ..........: x86_64-linux-gnu
SpatiaLite version ..: 5.1.0	Supported Extensions:
	- 'VirtualShape'	[direct Shapefile access]
	- 'VirtualDbf'		[direct DBF access]
	- 'VirtualText'		[direct CSV/TXT access]
	- 'VirtualGeoJSON'		[direct GeoJSON access]
	- 'VirtualXL'		[direct XLS access]
	- 'VirtualNetwork'	[Dijkstra shortest path - obsolete]
	- 'RTree'		[Spatial Index - R*Tree]
	- 'MbrCache'		[Spatial Index - MBR cache]
	- 'VirtualFDO'		[FDO-OGR interoperability]
	- 'VirtualBBox'		[BoundingBox tables]
	- 'VirtualSpatialIndex'	[R*Tree metahandler]
	- 'VirtualElementary'	[ElemGeoms metahandler]
	- 'VirtualRouting'	[Dijkstra shortest path - advanced]
	- 'VirtualKNN2'	[K-Nearest Neighbors metahandler]
	- 'VirtualGPKG'	[OGC GeoPackage interoperability]
	- 'VirtualXPath'	[XML Path Language - XPath]
	- 'SpatiaLite'		[Spatial SQL - OGC]
PROJ version ........: Rel. 9.4.0, March 1st, 2024
GEOS version ........: 3.12.1-CAPI-1.18.1
RTTOPO version ......: 1.1.0
TARGET CPU ..........: x86_64-linux-gnu

(base) a@a-X:~/valhalla$ 
```

### step4.valhalla_build_admins

```sh
(base) a@a-X:~/valhalla$ ${bdExePath}/valhalla_build_admins -c ${bdDatPath}/valhalla.json ${rawDatPath}/switzerland-latest.osm.pbf  ${rawDatPath}/liechtenstein-latest.osm.pbf
2026-11-08 07:36:05.812942677 [INFO] Parsing files: /mnt/a2disk/a2/zdev/nv/osrm/valhalla/_data/switzerland-latest.osm.pbf, /mnt/a2disk/a2/zdev/nv/osrm/valhalla/_data/liechtenstein-latest.osm.pbf
2026-11-08 07:36:05.812986105 [INFO] Parsing relations...
2026-11-08 07:36:08.117629416 [INFO] Finished with 69 admin polygons comprised of 16472 ways
2026-11-08 07:36:08.117662271 [INFO] Parsing ways...
2026-11-08 07:36:10.772047511 [INFO] Finished with 1875 ways comprised of 148526 nodes
2026-11-08 07:36:10.772078527 [INFO] Parsing nodes...
2026-11-08 07:36:18.835779744 [INFO] Finished with 146576 nodes
2026-11-08 07:36:19.003713407 [INFO] Created admin table.
2026-11-08 07:36:19.003894560 [INFO] Created admin access table.
2026-11-08 07:36:19.003912664 [INFO] Start populating admin tables.
2026-11-08 07:36:19.004219615 [WARN] Österreich (16239) is missing way member 193640488
2026-11-08 07:36:19.004240491 [WARN] Österreich (16239) is degenerate and will be skipped
2026-11-08 07:36:19.006272775 [WARN] Piemonte (44874) is missing way member 137876950
2026-11-08 07:36:19.006296095 [WARN] Piemonte (44874) is degenerate and will be skipped
2026-11-08 07:36:19.006310208 [WARN] Lombardia (44879) is missing way member 910528213
2026-11-08 07:36:19.006322044 [WARN] Lombardia (44879) is degenerate and will be skipped
2026-11-08 07:36:19.006455893 [WARN] Valle d'Aosta / Vallée d'Aoste (45155) is missing way member 448510880
2026-11-08 07:36:19.006470567 [WARN] Valle d'Aosta / Vallée d'Aoste (45155) is degenerate and will be skipped
2026-11-08 07:36:19.006483859 [WARN] Trentino-Alto Adige/Südtirol (45757) is missing way member 1346787545
2026-11-08 07:36:19.006495313 [WARN] Trentino-Alto Adige/Südtirol (45757) is degenerate and will be skipped
2026-11-08 07:36:19.006507441 [WARN] Bolzano - Bozen (47046) is missing way member 53190195
2026-11-08 07:36:19.006518984 [WARN] Bolzano - Bozen (47046) is degenerate and will be skipped
2026-11-08 07:36:19.006531168 [WARN] Deutschland (51477) is missing way member 195725410
2026-11-08 07:36:19.006561072 [WARN] Deutschland (51477) is degenerate and will be skipped
2026-11-08 07:36:22.490386615 [WARN] Tirol (52343) is missing way member 1455183301
2026-11-08 07:36:22.490437612 [WARN] Tirol (52343) is degenerate and will be skipped
2026-11-08 07:36:22.490451923 [WARN] Baden-Württemberg (62611) is missing way member 1418376316
2026-11-08 07:36:22.490464517 [WARN] Baden-Württemberg (62611) is degenerate and will be skipped
2026-11-08 07:36:22.490476608 [WARN] Vorarlberg (74942) is missing way member 364679043
2026-11-08 07:36:22.490487285 [WARN] Vorarlberg (74942) is degenerate and will be skipped
2026-11-08 07:36:22.490521262 [WARN] Italia (365331) is missing way member 1337725280
2026-11-08 07:36:22.490551349 [WARN] Italia (365331) is degenerate and will be skipped
2026-11-08 07:36:22.512493308 [WARN] France (1403916) is missing way member 1455114032
2026-11-08 07:36:22.512519503 [WARN] France (1403916) is degenerate and will be skipped
RTTOPO warning: Self-intersection at or near point 8.8319039999999998 47.549509999999998

RTTOPO warning: Self-intersection at or near point 8.8318770000000004 47.549509999999998

2026-11-08 07:36:27.619133845 [WARN] Bayern (2145268) is missing way member 1418376316
2026-11-08 07:36:27.619167720 [WARN] Bayern (2145268) is degenerate and will be skipped
2026-11-08 07:36:27.631009293 [WARN] Grand Est (3792876) is missing way member 860310556
2026-11-08 07:36:27.631044011 [WARN] Grand Est (3792876) is degenerate and will be skipped
2026-11-08 07:36:27.631057519 [WARN] Auvergne-Rhône-Alpes (3792877) is missing way member 1305406191
2026-11-08 07:36:27.631069733 [WARN] Auvergne-Rhône-Alpes (3792877) is degenerate and will be skipped
2026-11-08 07:36:27.632291432 [WARN] Bourgogne-Franche-Comté (3792878) is missing way member 48565263
2026-11-08 07:36:27.632340120 [WARN] Bourgogne-Franche-Comté (3792878) is degenerate and will be skipped
2026-11-08 07:36:28.046839625 [WARN] Österreich (16239) is missing way member 193640488
2026-11-08 07:36:28.046871428 [WARN] Österreich (16239) is degenerate and will be skipped
2026-11-08 07:36:31.520449022 [WARN] Vorarlberg (74942) is missing way member 364679043
2026-11-08 07:36:31.520481608 [WARN] Vorarlberg (74942) is degenerate and will be skipped
2026-11-08 07:36:32.673969396 [INFO] Inserted 51 admin areas
2026-11-08 07:36:32.677628465 [INFO] Created spatial index
2026-11-08 07:36:32.677801714 [INFO] Created Level index
2026-11-08 07:36:34.475960089 [INFO] Done updating parent admin
2026-11-08 07:36:34.477626346 [INFO] Done updating drive on right column.
2026-11-08 07:36:34.477831022 [INFO] Created Drive On Right index
2026-11-08 07:36:34.479068221 [INFO] Done updating allow intersection names column.
2026-11-08 07:36:34.479295458 [INFO] Created allow intersection names index
2026-11-08 07:36:34.479605869 [INFO] Done updating supported languages
2026-11-08 07:36:34.479767954 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Cymru / Wales
2026-11-08 07:36:34.479864960 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for United States
2026-11-08 07:36:34.479997429 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Türkiye
2026-11-08 07:36:34.480061819 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Greece
2026-11-08 07:36:34.480125320 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Finland
2026-11-08 07:36:34.480203842 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for France
2026-11-08 07:36:34.480305264 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for England
2026-11-08 07:36:34.480407420 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Russia
2026-11-08 07:36:34.480504613 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Belarus
2026-11-08 07:36:34.480641344 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Hungary
2026-11-08 07:36:34.480704644 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Belgium
2026-11-08 07:36:34.480767869 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for United Kingdom
2026-11-08 07:36:34.480868358 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Iceland
2026-11-08 07:36:34.480948361 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Austria
2026-11-08 07:36:34.481010165 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Brazil
2026-11-08 07:36:34.481072160 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Denmark
2026-11-08 07:36:34.481134200 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for China
2026-11-08 07:36:34.481222726 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Spain
2026-11-08 07:36:34.481301286 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Australia
2026-11-08 07:36:34.481363518 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Ireland
2026-11-08 07:36:34.481426520 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Netherlands
2026-11-08 07:36:34.481489607 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Norway
2026-11-08 07:36:34.481552254 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Italy
2026-11-08 07:36:34.481614332 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Alba / Scotland
2026-11-08 07:36:34.481676507 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Sweden
2026-11-08 07:36:34.481738651 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Northern Ireland
2026-11-08 07:36:34.481801608 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Oman
2026-11-08 07:36:34.481863707 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Slovakia
2026-11-08 07:36:34.481925761 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Philippines
2026-11-08 07:36:34.481987826 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Poland
2026-11-08 07:36:34.482049651 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for ประเทศไทย
2026-11-08 07:36:34.482111598 [ERROR] sqlite3_step() error: NOT NULL constraint failed: admin_access.admin_id.  Ignore if not using a planet extract or check if there was a name change for Romania
2026-11-08 07:36:34.482133512 [INFO] Writing database to disk.
2026-11-08 07:36:34.529002095 [INFO] Finished.
```

### step5.valhalla_build_tiles

```sh
(base) a@a-X:~/valhalla$ ${bdExePath}/valhalla_build_tiles -c ${bdDatPath}/valhalla.json ${rawDatPath}/switzerland-latest.osm.pbf ${rawDatPath}/liechtenstein-latest.osm.pbf
2026-11-08 08:43:36.988911100 [INFO] Running valhalla_build_tiles with 20 thread(s).
2026-11-08 08:43:36.988954351 [INFO] Start stage = initialize End stage = cleanup
2026-11-08 08:43:36.989001911 [WARN] Tile building using more than one osm.pbf extract is discouraged. Consider merging the extracts into one file. See this issue for more info: https://github.com/valhalla/valhalla/issues/3925 
2026-11-08 08:43:36.996321202 [INFO] Parsing files for ways: /mnt/a2disk/a2/zdev/nv/osrm/valhalla/_data/switzerland-latest.osm.pbf, /mnt/a2disk/a2/zdev/nv/osrm/valhalla/_data/liechtenstein-latest.osm.pbf
2026-11-08 08:43:36.996652258 [INFO] Parsing ways...
2026-11-08 08:46:27.741716615 [INFO] Clarifying and fixing cul-de-sacs...
2026-11-08 08:46:29.960885639 [INFO] Added 453 culdesac roundabouts from 668 candidates.
2026-11-08 08:46:29.960922088 [TIMING] src/mjolnir/pbfgraphparser.cc::clarify_and_fix took 2s
2026-11-08 08:46:29.960939263 [INFO] Finished with 2030956 routable ways containing 19728430 nodes
2026-11-08 08:46:29.975780650 [INFO] Sorting osm access tags by way id...
2026-11-08 08:46:30.718726496 [INFO] Finished
2026-11-08 08:46:30.722338439 [TIMING] src/mjolnir/pbfgraphparser.cc::ParseWays took 173s
2026-11-08 08:46:30.722386828 [WARN] [parseways] 1 ways with speed clamped to max
2026-11-08 08:46:30.722402337 [WARN] [parseways] 1 ways with speed limit clamped to max
2026-11-08 08:46:30.722416444 [WARN] [parseways] 141 OSM time range conditions that could not be parsed
2026-11-08 08:46:30.722429044 [WARN] [parseways] 105 OSM time range conditions with unsupported features (years, sun events, ...)
2026-11-08 08:46:30.723855128 [INFO] Parsing files for relations: /mnt/a2disk/a2/zdev/nv/osrm/valhalla/_data/switzerland-latest.osm.pbf, /mnt/a2disk/a2/zdev/nv/osrm/valhalla/_data/liechtenstein-latest.osm.pbf
2026-11-08 08:46:30.723950516 [INFO] Parsing relations...
2026-11-08 08:46:33.642439248 [INFO] Finished with 11805 simple turn restrictions
2026-11-08 08:46:33.642477794 [INFO] Finished with 0 lane connections
2026-11-08 08:46:33.642884608 [INFO] Sorting complex restrictions by from id...
2026-11-08 08:46:33.643244457 [INFO] Sorting complex restrictions by to id...
2026-11-08 08:46:33.643582497 [INFO] Finished
2026-11-08 08:46:33.644009660 [TIMING] src/mjolnir/pbfgraphparser.cc::ParseRelations took 2s
2026-11-08 08:46:33.645743060 [INFO] Parsing files for nodes: /mnt/a2disk/a2/zdev/nv/osrm/valhalla/_data/switzerland-latest.osm.pbf, /mnt/a2disk/a2/zdev/nv/osrm/valhalla/_data/liechtenstein-latest.osm.pbf
2026-11-08 08:46:33.645784011 [INFO] Sorting osm way node references by node id...
2026-11-08 08:46:39.736005738 [INFO] Parsing nodes...
2026-11-08 08:49:26.181836294 [INFO] Finished with 16951337 nodes contained in routable ways
2026-11-08 08:49:26.181868514 [INFO] Sorting osm way node references by way index and node shape index...
2026-11-08 08:49:32.907837234 [INFO] Finished: max_osm_id 14353154743
2026-11-08 08:49:32.907870380 [INFO] Number of nodes with refs (exits) = 1418
2026-11-08 08:49:32.907881506 [INFO] Number of nodes with exit_to = 0
2026-11-08 08:49:32.907891118 [INFO] Number of nodes with names = 1098
2026-11-08 08:49:32.907901732 [INFO] Number of nodes with linguistics = 50
2026-11-08 08:49:32.907911914 [INFO] Number of way refs = 0
2026-11-08 08:49:32.907922073 [INFO] Number of reverse way refs = 0
2026-11-08 08:49:32.907932413 [INFO] Unique Node Strings (names, refs, etc.) = 671
2026-11-08 08:49:32.907942612 [INFO] Unique Strings (names, refs, etc.) = 116395
2026-11-08 08:49:32.908452122 [TIMING] src/mjolnir/pbfgraphparser.cc::ParseNodes took 179s
2026-11-08 08:49:32.908504063 [INFO] Creating graph edges from ways...
2026-11-08 08:49:37.090069912 [INFO] Finished with 3723387 graph edges
2026-11-08 08:49:37.105960147 [INFO] Sorting graph...
2026-11-08 08:49:39.803054254 [INFO] Nodes processed. Sorting begin and end nodes by edge.
2026-11-08 08:49:41.898736925 [INFO] Sorting begin and end nodes done. Populating edges...
2026-11-08 08:49:42.256574124 [INFO] Finished with 2968387 graph nodes
2026-11-08 08:49:42.260587412 [TIMING] src/mjolnir/graphbuilder.cc::BuildEdges took 9s
2026-11-08 08:49:42.260852337 [INFO] Writing tile manifest to /mnt/a2disk/a2/zdev/nv/osrm/valhalla/_databd/valhalla_tiles/tile_manifest.json
2026-11-08 08:49:42.260917717 [INFO] Building edge shapes from 19728430 way nodes...
2026-11-08 08:49:42.307390280 [TIMING] src/mjolnir/graphbuilder.cc::BuildEdgeShapes took 0s
2026-11-08 08:49:42.307442022 [INFO] Reclassifying_V2 link graph edges...
2026-11-08 08:49:44.516528497 [INFO] Class: 0 exit count = 867
2026-11-08 08:49:44.516578310 [INFO] Class: 1 exit count = 263
2026-11-08 08:49:44.516589665 [INFO] Class: 2 exit count = 1274
2026-11-08 08:49:44.516599516 [INFO] Class: 3 exit count = 1205
2026-11-08 08:49:44.516628814 [INFO] Class: 4 exit count = 420
2026-11-08 08:49:44.516658719 [INFO] Class: 5 exit count = 75
2026-11-08 08:49:44.516686531 [INFO] Class: 6 exit count = 79
2026-11-08 08:49:44.516716429 [INFO] Class: 7 exit count = 0
2026-11-08 08:49:44.632878796 [INFO] Finished with 6486 link edges reclassified.  Turn channel count = 2074
2026-11-08 08:49:44.635854696 [TIMING] src/mjolnir/linkclassification.cc::ReclassifyLinks took 2s
2026-11-08 08:49:44.635888840 [INFO] Reclassifying ferry connection graph edges...
2026-11-08 08:49:47.095477892 [INFO] Finished ReclassifyFerryEdges: ferry_endpoint_count = 22, 1941 edges reclassified
2026-11-08 08:49:47.098779637 [TIMING] src/mjolnir/ferry_connections.cc::ReclassifyFerryConnections took 2s
2026-11-08 08:49:47.328431143 [TIMING] src/mjolnir/graphbuilder.cc::ComputeFerrySpeeds took 0s
2026-11-08 08:49:47.328473004 [INFO] Building 118 tiles with 20 threads...
2026-11-08 08:50:06.087412493 [INFO] Finished
2026-11-08 08:50:06.087509584 [TIMING] src/mjolnir/graphbuilder.cc::BuildLocalTiles took 18s
2026-11-08 08:50:06.087529137 [INFO] Node Count = 2968387
2026-11-08 08:50:06.087540456 [INFO] Directed Edge Count = 7446774
2026-11-08 08:50:06.087551669 [INFO] EdgeInfo Count = 3738089
2026-11-08 08:50:06.087564444 [TIMING] src/mjolnir/graphbuilder.cc::Build took 23s
2026-11-08 08:50:06.087585349 [WARN] [build] 2 simple turn restriction masks exceeding limit
2026-11-08 08:50:06.087601120 [WARN] [build] 2 ferry connections completely failing to reclassify edges to the next level 0 edge
2026-11-08 08:50:06.087625915 [INFO] Enhancing local graph...
2026-11-08 08:50:06.180164703 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.180772088 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.180223559 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.181273423 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.181305353 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.181539133 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.181590786 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.181611392 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.181685616 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.182066643 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.182093839 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.182614717 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.182619246 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.182942440 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.183984962 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.185137362 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.189896901 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.191768063 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.198344216 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:06.199235727 [INFO] Disabled default speeds assignment from config
2026-11-08 08:50:45.432689476 [INFO] Finished with max_density 20.891634
2026-11-08 08:50:45.432722823 [INFO] internal intersection = 9479
2026-11-08 08:50:45.432798506 [TIMING] src/mjolnir/graphenhancer.cc::Enhance took 39s
2026-11-08 08:50:45.432860424 [WARN] [enhance] 1262 edges with missing access tags
2026-11-08 08:50:45.432893087 [INFO] GraphFilter - nothing to filter. Skipping...
2026-11-08 08:50:45.432906401 [TIMING] src/mjolnir/graphfilter.cc::Filter took 0s
2026-11-08 08:50:45.432978863 [INFO] Transit directory not found. Transit will not be added.
2026-11-08 08:50:45.435181368 [INFO] HierarchyBuilder
2026-11-08 08:50:46.424173827 [TIMING] src/mjolnir/hierarchybuilder.cc::CreateNodeAssociations took 0s
2026-11-08 08:50:50.200435410 [INFO] Associated 3208921 new nodes to base nodes
2026-11-08 08:50:51.583059339 [TIMING] src/mjolnir/hierarchybuilder.cc::SortSequences took 5s
2026-11-08 08:51:35.531333775 [TIMING] src/mjolnir/hierarchybuilder.cc::FormTilesInNewLevel took 43s
2026-11-08 08:51:35.897474486 [TIMING] src/mjolnir/hierarchybuilder.cc::RemoveUnusedLocalTiles took 0s
2026-11-08 08:51:35.897580626 [INFO] Done HierarchyBuilder
2026-11-08 08:51:35.899804164 [TIMING] src/mjolnir/hierarchybuilder.cc::Build took 50s
2026-11-08 08:51:35.904000753 [INFO] Creating shortcuts on level 1
2026-11-08 08:51:43.296451880 [INFO] Finished with 39332 shortcuts superseding 447580 edges, average ~11 edges per shortcut
2026-11-08 08:51:43.296486282 [INFO] Creating shortcuts on level 0
2026-11-08 08:51:46.191081917 [INFO] Finished with 15752 shortcuts superseding 158268 edges, average ~10 edges per shortcut
2026-11-08 08:51:46.191128146 [TIMING] src/mjolnir/shortcutbuilder.cc::Build took 10s
2026-11-08 08:51:46.191164555 [WARN] Elevation storage directory does not exist
2026-11-08 08:51:46.196459973 [INFO] Adding complex turn restrictions at level 2
2026-11-08 08:52:01.537587475 [TIMING] src/mjolnir/restrictionbuilder.cc::HandleOnlyRestrictionProperties took 1s
2026-11-08 08:52:01.537627792 [INFO] --Forward restrictions added: 253
2026-11-08 08:52:01.537639329 [INFO] --Reverse restrictions added: 284
2026-11-08 08:52:01.540580614 [INFO] Adding complex turn restrictions at level 1
2026-11-08 08:52:12.160023172 [TIMING] src/mjolnir/restrictionbuilder.cc::HandleOnlyRestrictionProperties took 9s
2026-11-08 08:52:12.160061442 [INFO] --Forward restrictions added: 381
2026-11-08 08:52:12.160073775 [INFO] --Reverse restrictions added: 367
2026-11-08 08:52:12.168354120 [INFO] Adding complex turn restrictions at level 0
2026-11-08 08:52:17.467639598 [TIMING] src/mjolnir/restrictionbuilder.cc::HandleOnlyRestrictionProperties took 4s
2026-11-08 08:52:17.467678979 [INFO] --Forward restrictions added: 229
2026-11-08 08:52:17.467690880 [INFO] --Reverse restrictions added: 213
2026-11-08 08:52:17.477181586 [INFO] Finished
2026-11-08 08:52:17.477276778 [TIMING] src/mjolnir/restrictionbuilder.cc::Build took 31s
2026-11-08 08:52:17.477308793 [INFO] Validating, finishing and binning tiles...
2026-11-08 08:52:24.905716390 [INFO] Finished
2026-11-08 08:52:24.905756753 [INFO] Binning inter-tile edges...
2026-11-08 08:52:26.038781239 [INFO] Finished
2026-11-08 08:52:26.038849735 [WARN] Possible duplicates at level: 0 = 228
2026-11-08 08:52:26.038876110 [WARN] Possible duplicates at level: 1 = 928
2026-11-08 08:52:26.038895616 [WARN] Possible duplicates at level: 2 = 34412
2026-11-08 08:52:26.054161975 [TIMING] src/mjolnir/graphvalidator.cc::Validate took 8s
2026-11-08 08:52:26.058720085 [INFO] Cleaning up temporary *.bin files within /mnt/a2disk/a2/zdev/nv/osrm/valhalla/_databd/valhalla_tiles/
2026-11-08 08:52:26.152157496 [TIMING] src/mjolnir/osmdata.cc::cleanup_temp_files took 0s
2026-11-08 08:52:26.187155486 [TIMING] src/mjolnir/util.cc::build_tile_set took 529s
(base) a@a-X:~/valhalla$ 
```

### step6.

```sh
(base) a@a-X:~/valhalla$ ${bdExePath}/valhalla_build_extract -c ${bdDatPath}/valhalla.json -v
2026-11-08 16:57:47,575  INFO: Finished tarring 135 tiles to /mnt/a2disk/a2/zdev/nv/osrm/valhalla/_databd/valhalla_tiles.tar

(base) a@a-X:~/valhalla$
```