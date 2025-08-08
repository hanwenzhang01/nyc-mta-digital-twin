%let stopTimesPath = /export/sas-viya/homes/hazhan/Common_Data/ICC-Deployments/MTA/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/inputs/stop_times.txt;
%let stopsPath = /export/sas-viya/homes/hazhan/Common_Data/ICC-Deployments/MTA/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/inputs/stops.txt;
%let tripsPath = /export/sas-viya/homes/hazhan/Common_Data/ICC-Deployments/MTA/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/inputs/trips.txt;

*import file with all stops at all times;
proc import datafile="&stopTimesPath"
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

*get trainLine_id;
data stopTimes;
    set stopTimes;
    length trainLine_id $ 50;
    trainLine_id=scan(shape_id,1,".");
    dotLoc=index(strip(shape_id),".");
    trainLine_id=strip(trainLine_id)||".."||substr(strip(shape_id),dotLoc+2,1);
    keep origTripID trip_id stop_sequence stop_id shape_id trainLine_id;
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
data uniqueStops (keep=shape_id stop_id stop_sequence);
    set stopTimes;
    if totalStops=maxTotalStops;
run;

*remove pure duplicates if any;
proc sort data=uniqueStops nodupkey;
    by shape_id stop_sequence stop_id;
run;

*make sure there is only one of each stop sequence for the shape;
data hmm1;
    set uniqueStops;
    by shape_id stop_sequence;
    if not (first.stop_sequence and last.stop_sequence);
run;

*make sure each stop is represented only once per shape;
proc sort data=uniqueStops;
    by shape_id stop_id;
run;
data hmm2;
    set uniqueStops;
    by shape_id stop_id;
    if not (first.stop_id and last.stop_id);
run;

*sort properly;
proc sort data=uniqueStops;
    by shape_id stop_sequence;
run;

*make sure all stops are represented - from table saved earlier;
data uniqueStops;
    set uniqueStops;
    isInUniqueStops=1;
run;

proc sql;
    create table bad as 
    select a.shape_id,
           a.stop_id,
           b.isInUniqueStops
    from allStops as a
    left join uniqueStops as b
    on a.shape_id=b.shape_id and a.stop_id=b.stop_id;
quit;
data bad;
    set bad;
    if isInUniqueStops ne 1;
run;

*rename variables;
data uniqueStops;
    set uniqueStops;
    drop isInUniqueStops;
    rename shape_id=hierarchyName
           stop_id=assetID;
run;

*getting only hierarchies;
proc sort data=uniqueStops out=hierarchies;
    by hierarchyName;
run;

proc sql;
    create table hierarchies_summary as
    select hierarchyName, count(*) as count
    from hierarchies
    group by hierarchyName;
quit;

/* Step 1: Extract the matching sequence */
data hierarchies;
    set hierarchies_summary;
    length hierarchy_group $10;

    /* Extract prefix for grouping */
    if hierarchyName='SI..N' then hierarchy_group = "SI..N";
    if hierarchyName="SI..S" then hierarchy_group = "SI..S";
    else hierarchy_group = substr(hierarchyName, 1, 4);
run;

/* Step 2: Identify the highest count for each group */
proc sort data=hierarchies; 
    by hierarchy_group descending count; 
run;

data condensed_hierarchies;
    set hierarchies;
    by hierarchy_group;
    if first.hierarchy_group; /* Keep only the first row (largest count) */
run;

/* Step 3: Merge back and replace hierarchyName */
proc sql nowarnrecurs;
    create table uniqueStops as
    select a.*, b.Hierarchy_group
    from uniqueStops as a
    left join hierarchies as b
    on a.hierarchyName= b.hierarchyName;
quit;

* if needed: use a longform hierarchyName like "Broadway - 7 Avenue Local"instead of "1..N103R";
    * merge uniqueStops with trips.txt on shape_id, to get route_id;
    * merge with routes.txt on route_id to get route_long_name;
proc import datafile="&tripsPath"
    out=trips
    dbms=csv
    replace;
    
    guessingrows=max;
    getnames=yes;
run;

data trips;
    set trips (keep= shape_id route_id);
    rename route_id = route_id_trips;
run;

proc sort data=trips nodupkey;
    by shape_id;
run;

%let routesPath = /export/sas-viya/homes/hazhan/Common_Data/ICC-Deployments/MTA/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/inputs/routes.txt;

proc import datafile="&routesPath"
    out=routes
    dbms=csv
    replace;
    
    guessingrows=max;
    getnames=yes;
run;

data mta_routes;
    set routes(keep=route_id route_long_name rename=(route_long_name=route_long));
run;

*getting only hierarchies;
proc sort data=mta_routes nodupkey;
    by route_id;
run;

proc casutil;
	   droptable quiet incaslib='public' casdata="mta_routes";
	run;	
   
proc casutil; 
   load data=work.mta_routes outcaslib="public"
        casout="mta_routes"
        promote;
quit;  

proc sql nowarnrecurs;
    create table hmm2 as 
    select a.*, 
           b.*
    from routes as a
    right join trips as b
    on a.route_id=b.route_id_trips;
quit;

data hierarchies;
    set hmm2;
    rename shape_id = hierarchyName;
    rename route_long_name = routeName;
    rename route_id = routeID;
run;

*confirm that all stops picked up a label / lat / lon;
data hmm;
    set uniqueStops;
    if strip(assetLabel)="";
run;


*add in information from the stops table;
proc import datafile="&stopsPath"
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
proc sql nowarnrecurs;
    create table uniqueStops as 
    select a.*, 
           b.assetLabel,
           b.latitude,
           b.longitude
    from uniqueStops as a
    left join stops as b
    on a.assetID=b.assetID;
quit;

*confirm that all stops picked up a label / lat / lon;
data hmm;
    set uniqueStops;
    if strip(assetLabel)="";
run;

*sort the final file;
proc sort data=uniqueStops;
    by hierarchyName stop_sequence;
run;

/*
proc sql nowarnrecurs;
    create table myfolder.uniqueStops as 
    select a.*, 
           b.routeID
    from myfolder.uniqueStops as a
    left join myfolder.routes as b
    on a.hierarchyName=b.hierarchyName;
quit;
*/