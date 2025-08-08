libname public cas caslib=public;
*cas casauto;
%let caslib = Public;

proc cas;
    session "&_sessref_";
    TableList = {"trackSE", "stationSE", "trainSE", "mta_routes", "mta_line_data",
                "mta_point_geo", "mta_point_data"};
    do i=1 to dim(TableList);
        table.tableExists result=res status=rc / caslib="&caslib" name=TableList[i];
        rc.status='';
        if (res.exists == 0) then do;
            print "Table &caslib.." TableList[i] " does not exist in memory. Loading it...";
            table.loadtable result=res status=rc / caslib="&caslib" path=TableList[i]||".sashdat" 
                casOut={caslib="&caslib", name=TableList[i], promote=TRUE};
            print res;
        end;
        else print "Table &caslib.." TableList[i] " already exists in memory.";
        end;
    run;
quit;
*cas casauto terminate;

*caslib _all_ assign;
%macro checkCasDSLoaded(lib=public, table=);
    %let dsExists=%sysfunc(exist(&lib..&table.));
    %put &=dsExists;
    %if "&dsExists"="0" %then %do;
        proc casutil;
            load data=&table casout="&table" outcaslib="&lib";
        quit;
    %end;
%mend checkCasDSLoaded;

%checkCasDSLoaded(lib=public, table=trainSE);
%checkCasDSLoaded(lib=public, table=stationSE);
%checkCasDSLoaded(lib=public, table=trackSE);
%checkCasDSLoaded(lib=public, table=mta_routes);

proc casutil  incaslib="public" outcaslib="public";   
    save casdata="mta_routes" replace;  
run;

proc casutil  incaslib="public" outcaslib="public";   
    save casdata="trainSE" replace;  
run;

proc casutil  incaslib="public" outcaslib="public";   
    save casdata="stationSE" replace;  
run;

proc casutil  incaslib="public" outcaslib="public";   
    save casdata="trackSE" replace;  
run;