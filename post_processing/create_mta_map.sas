libname public cas caslib=public;

proc sql noprint;
  select put(max(msr_timestamp), 20.) into :last_datetime trimmed
  from public.trainSE;
quit;
%put ***last_datetime =&last_datetime ;

*train table information;
data train_temp2;
	set public.trainSE 
		(rename=(trainLatitude=latitude 
				trainLongitude=longitude 
				assetType=temp_assetType)
		where=(msr_timestamp=&last_datetime.));
	length assetType $7;
    length route_id $5.;
    length newTime 8.;

    format expectedRouteCompletionTime time10.;
    format timeToArrival time10.;
	assetType=temp_assetType;
    route_id = scan(route,1,".");

    if substr(currentStatus,1,3)="enr" then do;
        inTransit=1;
        stopped=0;
    end;
    else do;
        inTransit=0;
        stopped=1;
    end;

    newTime = msr_timestamp - 315619100;
    timeToArrivalSec = (trainExpArrivalTimestamp/1000000) - (newTime);
    timeToArrival = hms(0,0,timeToArrivalSec);

    trainExpArrivalTimestamp = trainExpArrivalTimestamp/1000000;
    trainDepartureTimestamp = trainDepartureTimestamp/1000000;

    expectedRouteCompletionTime = hms(0,0,(trainExpArrivalTimestamp - trainDepartureTimestamp));
	drop _opcode key1 key2 currentStatusRaw lastArrivalStation 
		lastArrivalTime prevArrivalStation prevArrivalTime
		stationArrival stationDepartureTo stationDepartureFrom temp_assetType
        newTime timeToArrivalSec;
	assetCode = 0;
run;

proc sql;
    create table train_temp22 as
    select 
        a.*,
        b.*
    from train_temp2 as a
    left join public.mta_routes as b
        on a.route_id = b.route_id;
quit;


*station table information;
data station_temp2;
	set public.stationSE
		(rename=(stationLatitude=latitude 
                stationLongitude=longitude)
		where=(msr_timestamp=&last_datetime.));
    length route_id $5.;
    
    route_id = scan(route,1,".");

    delayed = (waitTime > waitTimeRollingAvg);
    if delayed then delayTime = waitTime - waitTimeRollingAvg;
    else delayTime = .;

	drop _opcode key1 key2 departedTrainStatus nextStation
		prevStation prevStationTrain1 prevStationTrain2;
	assetCode = 1;
run;

proc sql;
    create table station_temp22 as
    select 
        a.*,
        b.*
    from station_temp2 as a
    left join public.mta_routes as b
        on a.route_id = b.route_id;
quit;

data track_temp2;
	set public.trackSE
		(rename=(assetType=temp_assetType)
        where=(msr_timestamp=&last_datetime.));
    length route_id $5.;
    length assetType $7.;
    length delayTime 8.;
    assetType=temp_assetType;
    route_id = scan(route,1,".");
    delayed = (travelTime > travelTimeRollingAvg);
    if delayed then delayTime = travelTime - travelTimeRollingAvg;
    else delayTime = .;

    keep assetID assetType route_id travelTime travelTimeRollingAvg avgTravelTime delayed delayTime;
run;

proc sql;
    create table track_temp22 as
    select 
        a.*,
        b.*
    from track_temp2 as a
    left join public.mta_routes as b
        on a.route_id = b.route_id;
quit;


/* combine tables */
data mta_map2;
	set train_temp22 station_temp22 track_temp22 public.mta_line_data;
run;

proc casutil;
	   droptable incaslib='public' casdata="mta_map2" quiet;
run;
   
proc casutil; 
   load data=work.mta_map2 outcaslib="public"
        casout="mta_map2"
        promote;
quit;  

proc casutil;
     list tables incaslib="public";
run;