*import file with all stops at all times;
proc import datafile="/export/sas-viya/homes/hazhan/Common_Data/ICC-Deployments/MTA/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/inputs/stop_times.txt"
        out=stopTimes
        dbms=csv
        replace;

     guessingrows=200000;
     getnames=yes;
run;

*get trip_id;
data stopTimes;
    set stopTimes(rename=(trip_id=origTripID));
    length trip_id_temp trip_id $ 50;
    trip_id_temp=scan(origTripID,-1,'-');
    trip_id=scan(trip_id_temp,-2,"_")||"_"||scan(trip_id_temp,-1,"_");
run;

*get shape_id;
data stopTimes;
    set stopTimes;
    length shape_id $ 50;
    shape_id=scan(trip_id,-1,"_");
    keep trip_id stop_sequence stop_id shape_id;
run;

*will check later to make sure all stops are in our final file;
proc sql;
    create table allStops as 
    select distinct 
      shape_id,
      stop_id
    from stopTimes;
quit;

*get the total stops for the trip;
proc sql nowarnrecurs;
    create table stopTimes as 
    select a.*,
           max(stop_sequence) as totalStops
    from stopTimes as a
    group by trip_id;
quit;

*get the max total stop for any trip for that shape;
proc sql nowarnrecurs;
    create table stopTimes as 
    select a.*,
           max(totalStops) as maxTotalStops
    from stopTimes as a
    group by shape_id;
quit;

*keep the trip that has the max number of stops for that shape;
*the assumption is that there is some trip for the shape that has ALL stops;
data uniqueStops2 (keep=shape_id stop_id stop_sequence);
    set stopTimes;
    if totalStops=maxTotalStops;
run;

proc sql;
    create table uniqueStops2 as
    select * from uniqueStops2
    where shape_id like "L%" or shape_id like "1%" or
        shape_id like "E%" or shape_id like "6%" or
        shape_id like "Q%" or shape_id like "7%";
run;

*remove pure duplicates if any;
proc sort data=uniqueStops2 nodupkey;
    by shape_id stop_sequence stop_id;
run;

/*
* delete later, filtering to L train;
proc sql;
    create table uniqueStops as
    select * from uniqueStops
    where assetID like "L%";
run;
*/

*make sure there is only one of each stop sequence for the shape;
data hmm1;
    set uniqueStops2;
    by shape_id stop_sequence;
    if not (first.stop_sequence and last.stop_sequence);
run;

*make sure each stop is represented only once per shape;
proc sort data=uniqueStops2;
    by shape_id stop_id;
run;
data hmm2;
    set uniqueStops2;
    by shape_id stop_id;
    if not (first.stop_id and last.stop_id);
run;

*sort properly;
proc sort data=uniqueStops2;
    by shape_id stop_sequence;
run;

*make sure all stops are represented - from table saved earlier;
data uniqueStops2;
    set uniqueStops2;
    isInUniqueStops=1;
run;

proc sql;
    create table bad as 
    select a.shape_id,
           a.stop_id,
           b.isInUniqueStops
    from allStops as a
    left join uniqueStops2 as b
    on a.shape_id=b.shape_id and a.stop_id=b.stop_id;
quit;
data bad;
    set bad;
    if isInUniqueStops ne 1;
run;

*rename variables;
data uniqueStops2;
    set uniqueStops2;
    drop isInUniqueStops;
    rename shape_id=hierarchyName
           stop_id=assetID;
run;

*now put the previous stop on the same record;
proc sort data=uniqueStops2;
    by hierarchyName stop_sequence;
run;
data prevStops;
    set uniqueStops2;
    by hierarchyName stop_sequence;
    length lagStop $ 250;
    lagStop=lag1(assetID);
run;
data prevStops;
    set prevstops;
    by hierarchyName stop_sequence;
    length prevStop $ 250;
    if first.hierarchyName then prevStop="";
    else prevStop=lagStop;
run;

*create a shortened hierarchy so we can start compacting from many shapes to a smaller number of hierarchies;
data prevstops;
    set prevstops (rename=(hierarchyName=oldHier));

    length hierarchyName $ 50;
    hierarchyName=scan(oldHier,1,".");
    dotLoc=index(strip(oldHier),".");
    hierarchyName=strip(hierarchyName)||".."||substr(strip(oldHier),dotLoc+2,1);
run;

*count the number of instances of each stop/prior stop combo;
data prevstops;
    set prevstops (keep=hierarchyName assetID prevStop);
run;
proc sql;
    create table stopSumm as
    select distinct 
           a.hierarchyName,
           a.assetID as assetID,
           a.prevStop as prevAssetID,
           count(*) as count
    from prevstops as a
    group by a.hierarchyName, a.assetID, a.prevStop;
quit;

*remove prior stops that are missing;
data stopSumm;
    set stopSumm;
    if prevAssetID="" then delete;
run;

*see if there are any that have more than one different prior stop - we will need to choose one;
proc sort data=stopSumm;
    by hierarchyName assetID prevAssetID;
run;
data hmm;
    set stopSumm;
    by hierarchyName assetID prevAssetID;
    if not (first.assetID and last.assetID);
run;

data stopSumm;
    set stopSumm;
    keep hierarchyName assetID prevAssetID;
run;

*add in information from the stops table;
proc import datafile="/export/sas-viya/homes/hazhan/Common_Data/ICC-Deployments/MTA/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/inputs/stops.txt"
        out=stops
        dbms=csv
        replace;

     guessingrows=max;
     getnames=yes;
run;

data stops;
    set stops (keep=stop_id stop_name stop_lat stop_lon);
    rename stop_id=assetID
           stop_name=assetLabel
           stop_lat=latitude
           stop_lon=longitude;
run;
data getlatlon;
    set stops (keep=assetID latitude longitude);
run;

proc sql;
    create table stoplatlon as 
    select a.*,
           b.latitude as thislat,
           b.longitude as thislon,
           c.latitude as prevlat,
           c.longitude as prevlon
    from stopSumm as a
    inner join getlatlon as b on a.assetID=b.assetID
    inner join getlatlon as c on a.prevAssetID=c.assetID;
quit;
proc sort data=stoplatlon nodupkey;
    by hierarchyName assetID prevAssetID;
run;

*import shape file;
proc import datafile="/export/sas-viya/homes/hazhan/Common_Data/ICC-Deployments/MTA/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/inputs/shapes.txt"
        out=shapes
        dbms=csv
        replace;
 
     guessingrows=200000;
     getnames=yes;
run;
data shapes;
    set shapes;
    length hierarchyName $ 50;
    hierarchyName=scan(shape_id,1,".");
    dotLoc=index(strip(shape_id),".");
    hierarchyName=strip(hierarchyName)||".."||substr(strip(shape_id),dotLoc+2,1);
    keep hierarchyName shape_id shape_pt_sequence shape_pt_lat shape_pt_lon;
run;
data shapes;
    set shapes;
    keep hierarchyName shape_id shape_pt_sequence shape_pt_lat shape_pt_lon;
run;
proc sort data=shapes;
    by hierarchyName shape_id shape_pt_sequence;
run;

*stoplatlon - hierarchyName assetID prevAssetID thislat thislon prevlat prevlon;
*shapes     - hierarchyName shape_id shape_pt_sequence shape_pt_lat shape_pt_lon shape_maxpts;

*now join the hierarchy with the shapes file to keep any shapes between the two stops;
proc sql;
    create table work1 as 
    select a.*,
           b.shape_id,
           b.shape_pt_sequence,
           b.shape_pt_lat,
           b.shape_pt_lon
    from stoplatlon as a, shapes as b
    where a.hierarchyName=b.hierarchyName and 
          min(thislat,prevlat) le shape_pt_lat le max(thislat,prevlat) and 
          min(thislon,prevlon) le shape_pt_lon le max(thislon,prevlon);
quit; 

*now keep only one of the shapes between the two stops so we can use the sequence numbers;
proc sql;
    create table pickshapeid as
    select distinct 
           a.hierarchyName,
           a.assetID,
           a.prevAssetID,
           a.shape_id
    from work1 as a;
quit;
proc sort data=pickshapeid;
    by hierarchyName assetID prevAssetID shape_id;
run;
data pickshapeID;
    set pickshapeID;
    by hierarchyName assetID prevAssetID shape_id;
    if first.prevAssetID;
run;
proc sort data=work1;
    by hierarchyName assetID prevAssetID shape_id shape_pt_sequence;
run;
data work1;
  merge work1 (in=in1)
        pickshapeID (in=in2);
  by hierarchyName assetID prevAssetID shape_id;
  if in1 and in2;
run;

*now create a new pt sequence;
proc sort data=work1;
    by hierarchyName assetID prevAssetID shape_id shape_pt_sequence;
run;
data work1;
    set work1;
    by hierarchyName assetID prevAssetID shape_id shape_pt_sequence;
    retain newSequence;
    if first.prevAssetID then newSequence=1;
    else newSequence=newSequence+1;
run;
proc sql;
    create table work1 as 
    select a.*,
           count(*) as newMaxSequence
    from work1 as a
    group by hierarchyName, assetID, prevAssetID;
quit;
proc sort data=work1;
    by hierarchyName assetID prevAssetID newSequence;
run;

proc freq data=work1;
    tables newMaxSequence;
run;

data work1;
    set work1;
    whichToKeep1=max(floor((newMaxSequence+0)/3),1);
    whichToKeep2=ceil(2*(newMaxSequence+0)/3);
run;
proc freq data=work1;
    tables newMaxSequence*whichToKeep1*whichToKeep2 / list missing;
run;

*now subset to the one third locations;
data loc1 (keep=hierarchyName assetID prevAssetID thislat thislon prevlat prevlon shape_pt_lat shape_pt_lon
           rename=(shape_pt_lat=enroute1Lat
                   shape_pt_lon=enroute1Lon));
    set work1;
    if newSequence=whichToKeep1;
run;
data loc2 (keep=hierarchyName assetID prevAssetID shape_pt_lat shape_pt_lon
           rename=(shape_pt_lat=enroute2Lat
                   shape_pt_lon=enroute2Lon));
    set work1;
    if newSequence=whichToKeep2;
run;

*now transpose the locations for each stop;
proc sort data=loc1 nodup;
    by hierarchyName assetID prevAssetID;
run;
proc sort data=loc2 nodup;
    by hierarchyName assetID prevAssetID;
run;

data enrouteLocs;
    merge loc1 loc2;
    by hierarchyName assetID prevAssetID;
run;

data enrouteLocs;
    set enrouteLocs;
    distance=geodist(thislat, thislon, prevlat, prevlon, 'M');
run;

proc sort data=enrouteLocs;
    by assetID distance;
run;

data enrouteLocs;
    set enrouteLocs;
    by assetID distance;
    if first.assetID;
run;

*will check later to make sure all stops are in our final file;
proc sql;
    create table uniqueStops2 as 
    select distinct 
    stop_id
    from allstops;
quit;

proc sql;
    create table hmm as 
    select a.stop_id
    from uniqueStops2 as a
    where stop_id not in (select distinct assetID from enrouteLocs);
quit;

data enrouteLocs;
    set enrouteLocs;
    keep assetID enroute1lat enroute1lon enroute2lat enroute2lon hierarchyName;
run;

data transposed1 (keep=assetID attribute value); /*keep on the data line will keep only the specified columns in the output table */
	set enrouteLocs;
	format attribute $20.
		   value 10.6;

	attribute="trackLatitude";
	value=enroute1lat;
	output;

	attribute="trackLongitude";
	value=enroute1lon;
	output;
run;

data transposed2 (keep=assetID attribute value); /*keep on the data line will keep only the specified columns in the output table */
	set enrouteLocs;
	format attribute $20.
		   value 10.6;

	attribute="trackLatitude1";
	value=enroute2lat;
	output;

	attribute="trackLongitude1";
	value=enroute2lon;
	output;
run;

data transposed3 (keep=assetID attribute value); /*keep on the data line will keep only the specified columns in the output table */
	set enrouteLocs;
	format attribute $20.
		   value $5.;

	attribute="route";
	value=hierarchyName;
	output;
run;

data enrouteLocs1;
    length assetID $20.;
    set transposed1(rename=(assetID=oldAssetID));
    rename attribute = attributeID;
    assetID = cat('enrouteTo', oldAssetID);
run;

data enrouteLocs2;
    length assetID $20.;
    set transposed2(rename=(assetID=oldAssetID));
    rename attribute = attributeID;
    assetID = cat('enrouteTo', oldAssetID);
run;

data enrouteLocs4;
    length assetID $20.;
    set transposed3(rename=(assetID=oldAssetID));
    rename attribute = attributeID;
    assetID = cat('enrouteTo', oldAssetID);
run;

data enrouteLocsFinal;
    length assetID $20.;
    set enrouteLocs1 enrouteLocs2;
    drop oldAssetID;
run;

data staticAttrs;
    set enrouteLocsFinal stationLocsFinal;
run;

proc json out="/export/sas-viya/homes/hazhan/Common_Data/ICC-Deployments/MTA/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/LL_staticAttributes.json" pretty;
    export staticAttrs / nosastags;
run;

/*
proc export data=enrouteLocs           
     outfile="/export/sas-viya/homes/hazhan/Common_Data/ICC-Deployments/MTA/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/enrouteToLocs.csv"  
     dbms=csv                                     
     replace;                                     
run;*/