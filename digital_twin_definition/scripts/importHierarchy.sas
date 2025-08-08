*import stops - directional and standard;
data stops stops_directional;
    length  stop_id         $ 5 
            stop_name       $ 100
            stop_lat        8
            stop_lon        8
            location_type   8
            parent_station  8;
    infile "/workspaces/myfolder/AutoMLforIoT/Deployments/mta/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/inputs/stops.txt" dlm="," dsd firstobs=2;
    input stop_id stop_name stop_lat stop_lon location_type parent_station;
    if location_type=1 then output stops;
    else output stops_directional;
run;

*import file with all stops at all times;
data stopTimes;
    length  trip_id         $ 100 
            stop_id         $ 5
            arrival_time    $ 8
            departure_time  $ 8
            stop_sequence   8;
    infile "/workspaces/myfolder/AutoMLforIoT/Deployments/mta/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/inputs/stop_times.txt" dlm="," dsd firstobs=2;
    input trip_id stop_id arrival_time departure_time stop_sequence;
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
data uniqueStops (keep=shape_id stop_id stop_sequence);
    set stopTimes;
    if totalStops=maxTotalStops;
run;

*remove pure duplicates if any;
proc sort data=uniqueStops nodupkey;
    by shape_id stop_sequence stop_id;
run;


*get the trips information;
data trips;
    length  route_id         $ 5 
            trip_id          $ 100
            service_id       $ 10
            trip_headsign    $ 50
            direction_id     $ 10
            shape_id         $ 10;
    infile "/workspaces/myfolder/AutoMLforIoT/Deployments/mta/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/inputs/trips.txt" dlm="," dsd firstobs=2;
    input route_id trip_id service_id trip_headsign direction_id shape_id;
run;

/* get the shapes information */
data shapes;
    length  shape_id                 $ 10
            shape_pt_sequence        8
            shape_pt_lat             8
            shape_pt_lon             8;
    infile "/workspaces/myfolder/AutoMLforIoT/Deployments/mta/programs/hazhan/Phase-1---Project-Definition/02_defineDigitalTwin/inputs/shapes.txt" dlm="," dsd firstobs=2;
    input shape_id shape_pt_sequence shape_pt_lat shape_pt_lon;
run;

/* add the stops to the shapes file */
proc sql;
    create table shapes as 
    select distinct b.*, c.stop_id, c.stop_name
    from shapes as b 
        left join stops as c on (b.shape_pt_lat=c.stop_lat and b.shape_pt_lon=c.stop_lon);
quit;

/* get the list of unique routes - there are many trips with many duplicates.
   we just need the list of routes and their associated shape_id's */
proc sql;
    create table trips_unique as
    select distinct route_id, shape_id, direction_id
    from trips
    where ^missing(shape_id);
quit;

/* combine the trips, shapes and details to make a full detailed table for trips */
proc sql;
        create table trips_details as 
        select distinct a.route_id, a.shape_id, a.direction_id,
                        b.shape_pt_sequence, b.shape_pt_lat, b.shape_pt_lon, c.stop_id, c.stop_name
        from trips_unique as a
            left join shapes as b on (a.shape_id=b.shape_id)
            left join stops as c on (b.shape_pt_lat=c.stop_lat and b.shape_pt_lon=c.stop_lon);
quit;

/* create a routed direction */
data trips_details;
    set trips_details;
    if direction_id=1 then route_id_dir=strip(route_id)||"_S";
    else route_id_dir=strip(route_id)||"_N";
    
run;

/* create a trips table with all the unique stops and shapes */
proc sort data=trips_details (where=(^missing(stop_id))) out=trips_wStops;
    by route_id_dir shape_pt_sequence ;
run;


/* separate the shape id to separate datasets */
data trips_2_N01R;
    set trips_wStops (where=(strip(shape_id)="2..N01R"));
run;

data trips_2_N03R;
    set trips_wStops (where=(strip(shape_id)="2..N03R"));
run;

data trips_2_N08R;
    set trips_wStops (where=(strip(shape_id)="2..N08R"));
run;

/* recombine routes to create the final dataset */
proc sql;
    create table trips_2N as 
    select a.route_id, a.shape_pt_sequence, a.stop_id,
    b.route_id as route_id2, b.shape_pt_sequence as shape_pt_sequence2, b.stop_id as stop_id2
    /*,
    c.route_id as route_id3, c.shape_pt_sequence as shape_pt_sequence3, c.stop_id as stop_id3*/
    from trips_2_N03R as a
        full join trips_2_N08R as b on (a.stop_id=b.stop_id)
       /* full join trips_2_N08R as c on (a.stop_id=c.stop_id)*/
    order by a.shape_pt_sequence, b.shape_pt_sequence/*, c.shape_pt_sequence*/;
quit;

/* coalesce the routes and stops to create a final column */
data trips_2N (drop=route_id2 stop_id2 shape_pt_sequence2
                    /*route_id3 stop_id3 shape_pt_sequence3*/
                    shape_pt_sequence);
    set trips_2N;
    stop_sequence=_n_;
    if missing(route_id) then route_id=coalesce(route_id,route_id2/*, route_id3*/);
    if missing(stop_id) then stop_id=coalesce(stop_id,stop_id2/*, stop_id3*/);
run;