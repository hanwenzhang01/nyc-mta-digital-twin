* run after getMTAdata.sas;
/* 
    fills in the following files:
    - assets.json
    - hierarchyMap.json
    - staticAttributes.json
*/

* creating the assets file;

data stations_og;
    length assetID $20.;
    set uniqueStops(rename=(assetID=oldAssetID));
    assetType="station";
    assetID = oldAssetID;
    keep assetID assetLabel assetType hierarchy_group;
run;


proc sql;
    create table stations as
    select * from stations_og
    where hierarchy_group like "L%" or hierarchy_group like "1%" or
        hierarchy_group like "E%" or hierarchy_group like "6%" or
        hierarchy_group like "Q%" or hierarchy_group like "7%";
run;

proc sort data=stations nodupkey;
    by assetID hierarchy_group;
run;

proc sort
     data = stations  out=bad2  nouniquekey  ;
     by assetID;
run;

proc sort data=bad2;
    by hierarchy_group;
run;

*sort properly;
proc sort data=stations;
    by hierarchy_group;
run;

data stations2;
    set stations;
run;

proc sort data=stations2 nodupkey;
    by assetID;
run;

*make sure all stops are represented - from table saved earlier;
data uniqueStops2;
    set stations2;
    isInUniqueStops=1;
run;

proc sql;
    create table bad as 
    select a.assetID,
           a.hierarchy_group,
           b.isInUniqueStops
    from stations as a
    left join uniqueStops2 as b
    on a.assetID=b.assetID and a.hierarchy_group=b.hierarchy_group;
quit;
data bad;
    set bad;
    if isInUniqueStops ne 1;
run;


data tracks;
    length assetID $20.;
    set uniqueStops(rename=(assetID=oldAssetID));
    assetType="track";
    assetID = oldAssetID;
    keep assetID assetLabel assetType hierarchy_group;
run;


proc sql;
    create table tracks as
    select * from tracks
    where hierarchy_group like "L%" or hierarchy_group like "1%" or
        hierarchy_group like "E%" or hierarchy_group like "6%" or
        hierarchy_group like "Q%" or hierarchy_group like "7%";
run;


data tracks;
    set tracks;
    assetID = cat('enrouteTo', assetID);
    assetLabel = cat('Enroute To ', assetLabel);
run;

proc sort data=tracks nodupkey;
    by assetID;
run;

data assets;
    set stations tracks;
    drop hierarchy_group;
run;


proc json out="/export/sas-viya/homes/hazhan/Common_Data/ICC-Deployments/MTA/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/assets.json" pretty;
    export assets / nosastags;
run;
/*
data routes;
    set myfolder.routes;
    assetType="subway";
    rename route_id_routes = assetID;
    rename route_long_name = assetLabel;
run;

data routes;
    set routes;
    keep assetID assetLabel assetType;
run;

proc sort data=routes nodupkey;
    by assetID;
run;

proc json out="/workspaces/myfolder/AutoMLforIoT/Deployments/mta/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/trains.json" pretty;
    export routes / nosastags;
run;

data assets;
    set stations routes;
run;

proc json out="/workspaces/myfolder/AutoMLforIoT/Deployments/mta/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/assets.json" pretty;
    export routes / nosastags;
run;
*/

* creating the hierarchyList file;
data hierarchyList;
    set condensed_hierarchies;
    keep hierarchy_group;
run;

proc sql;
    create table hierarchyList as
    select * from hierarchyList
    where hierarchy_group like "L%" or hierarchy_group like "1%" or
        hierarchy_group like "E%" or hierarchy_group like "6%" or
        hierarchy_group like "Q%" or hierarchy_group like "7%";
run;

/*
*delete later, filtering to L train;
proc sql;
    create table hierarchyList as
    select * from hierarchyList
    where hierarchy_group like "L..%" or hierarchy_group like "1..%";
run;
*/

data hierarchyList;
    set hierarchyList;
    rename hierarchy_group = hierarchyName;
run;

proc json out="/export/sas-viya/homes/hazhan/Common_Data/ICC-Deployments/MTA/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/hierarchyList.json" pretty;
    export hierarchyList / nosastags;
run;


* creating the hierarchy map file;
proc sql;
    create table hmmm as
    select * 
    from condensed_hierarchies as a
    left join uniqueStops as b
    on a.hierarchyName = b.hierarchyName;
quit;

proc sort data=uniqueStops nodupkey;
    by hierarchyName stop_sequence assetID;
run;

* make sure we didn't lose stops;
proc sort data=uniqueStops out=test1 nodupkey;
    by assetID;
run;

proc sort data=hmmm out=test2 nodupkey;
    by assetID;
run;

proc sql;
    create table test3 as
    select * 
    from test1 as a
    full join test2 as b
    on a.assetID = b.assetID;
quit;

data rows_with_nulls;
    set test3;
    if cmiss(of _all_) > 0; /* Checks for missing values in all columns */
run;
/*
PROC SQL;
CREATE TABLE filtered_data AS
SELECT *
FROM hmmm
WHERE hierarchy_group LIKE 'L%' OR 
        hierarchy_group LIKE '1%';
QUIT;
*/

*end;

PROC SQL;
CREATE TABLE filtered_data AS
SELECT *
FROM hmmm
WHERE hierarchy_group like "L%" or hierarchy_group like "1%" or
        hierarchy_group like "E%" or hierarchy_group like "6%" or
        hierarchy_group like "Q%" or hierarchy_group like "7%";
QUIT;

proc sort data=filtered_data out=filtered_data2;
    by hierarchyName descending stop_sequence assetID;
run;

data doubled;
    set filtered_data2(rename=(assetID=_oldID));
    length assetID $20.;
    assetID = _oldID;
    output;

    assetID = "enrouteTo" || _oldID;
    output;
run;


data hmm;
    set doubled;
    by hierarchyName;
    child_assetID = lag (assetID);
    direction = "<->";
    keep child_assetID direction hierarchy_group assetID;
run;

data hier;
    *reordering columns;
    retain child_assetID direction hierarchy_group assetID;
    set hmm;
    by hierarchy_group;
    if first.hierarchy_group then delete;
    if last.hierarchy_group then delete;
    rename assetID = parent_assetID;
run;

/*
*delete later, filtering to L train;
proc sql;
    create table hier as
    select * from hier
    where hierarchy_group like "L..%" or hierarchy_group like "1..%";
run;
*/

data hier;
    set hier;
    rename hierarchy_group = hierarchyName;
run;

proc sql;
    select distinct(hierarchyName) from hier;
run;

proc json out="/export/sas-viya/homes/hazhan/Common_Data/ICC-Deployments/MTA/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/hierarchyMap.json" pretty;
    export hier / nosastags;
run;



* creating the staticAttributes file with lat/longs;
data latlongs;
    set uniquestops;
    keep assetID assetLabel Latitude Longitude hierarchy_group;
run;

proc sql;
    create table latlongs as
    select * from latlongs
    where hierarchy_group like "L%" or hierarchy_group like "1%" or
        hierarchy_group like "E%" or hierarchy_group like "6%" or
        hierarchy_group like "Q%" or hierarchy_group like "7%";
run;

data latlongs;
    set latlongs;
    drop hierarchy_group;
run;

*transpose the dataset so we now have an attributeID and value to contain our address and phone number;
data transposedDataset2 (keep=assetID attribute value); /*keep on the data line will keep only the specified columns in the output table */
	set latlongs;
	format attribute $20.
		   value 10.6;

	attribute="stationLatitude";
	value=strip(latitude);
	output;

	attribute="stationLongitude";
	value=strip(longitude);
	output;
run;

data stationLocsFinal;
    set transposedDataset2;
    rename attribute = attributeID;
run;

data routesFinal;
    set uniqueStops;
    attributeID = 'route';
run;

proc sql;
    create table routesFinal as
    select * from routesFinal
    where hierarchy_group like "L%" or hierarchy_group like "1%" or
        hierarchy_group like "E%" or hierarchy_group like "6%" or
        hierarchy_group like "Q%" or hierarchy_group like "7%";
run;

proc sort data=routesFinal nodupkey;
    by assetID;
run;

data routesFinal;
    set routesFinal;
    rename hierarchy_group=value;
    rename stop_id=assetID;
run;

data routesFinal3;
    length assetID $20.;
    set routesFinal(rename=(assetID=oldAssetID));
    assetID=oldAssetID;
    drop oldAssetID;
run;

data enrouteLocs3;
    set transposed3;
    rename attribute = attributeID;
    assetID=cat('enrouteTo', assetID);
run;

data routesFinal2;
    set routesFinal3(keep=assetID value attributeID) enrouteLocs4(keep=assetID value attributeID);
run;

proc json out="/export/sas-viya/homes/hazhan/Common_Data/ICC-Deployments/MTA/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/routesFinal.json" pretty;
    export routesFinal2 / nosastags;
run;