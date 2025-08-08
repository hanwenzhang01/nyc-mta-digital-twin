--------------------------------------------------------------------------------------------
DEPENDENCIES
Instructions: Enter assetType --- attributeID
Result:       These attributes will exist and be accessible as their ***SASAttributeID*** 
              variable names for the code that is run.
--------------------------------------------------------------------------------------------

station --- prevTrackTrain1
station --- prevTrackTrain2
station --- prevStationTrain1
station --- prevStationTrain2
station --- prevTrackTravelTime
station --- expectedNextTrain1Time

--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
LOGIC
Instructions: Enter the code you would like to run. It should be SAS DS2 code and can
              access any ***SASAttributeIDs*** referenced above - and it should define how 
              to create a variable named the ***SASAttributeID*** of the new attribute.
              Users can also declare new variables, init code, and supporting 
              methods below.
Result:       This code will run for each assetID of the specified assetType.
--------------------------------------------------------------------------------------------

expectedNextTrain2Time='';

countPrevTrack=0;
if strip(prevTrackTrain1) ne '' then countPrevTrack=countPrevTrack+1;
if strip(prevTrackTrain2) ne '' then countPrevTrack=countPrevTrack+1;

countPrevStation=0;
if strip(prevStationTrain1) ne '' then countPrevStation=countPrevStation+1;
if strip(prevStationTrain2) ne '' then countPrevStation=countPrevStation+1;

if countPrevTrack=2 then do;
  expectedNextTrain2Time='2 minutes';
end;
else if countPrevTrack=1 then do;
  if countPrevStation ge 1 then do;
    if prevTrackTravelTime gt 0 then do;
      expectedNextTrain2Time=strip(put(1.0+ceil(prevTrackTravelTime/60.0),8.0))||' minutes';
    end;
    else do;
      expectedNextTrain2Time='3 minutes';
    end;
  end;
end;
else if countPrevTrack=0 then do;
  if countPrevStation ge 2 then do;
    if prevTrackTravelTime gt 0 then do;
      expectedNextTrain2Time=strip(put(2.0+ceil(prevTrackTravelTime/60.0),8.0))||' minutes';
    end;
    else do;
      expectedNextTrain2Time='4 minutes';
    end;
  end;
end;

if strip(expectedNextTrain1Time) ne '' and strip(expectedNextTrain2Time) ne '' then do;
  expectedTrain1TimeN = inputn(scan(expectedNextTrain1Time,1,' '),8.0);
  expectedTrain2TimeN = inputn(scan(expectedNextTrain2Time,1,' '),8.0);

  if expectedTrain1TimeN gt 0 and 
     expectedTrain2TimeN gt 0 and 
     expectedTrain2TimeN le expectedTrain1TimeN then do;
    expectedNextTrain2Time=strip(put(expectedTrain1TimeN+1.0,8.0))||' minutes';
  end;
end;

--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
DECLARATIONS
Instructions: If you need to define supporting variables, enter those declarations 
              here. The new attribute will already be defined so it should not be 
              defined in this section.
Result:       This code will run at the beginning of the DS2 package to ensure
              these variables exist.
--------------------------------------------------------------------------------------------

/* insert supporting variable declarations here, if applicable */
/* for example... declare double mySupportingVariable; */
declare double countPrevTrack;
declare double countPrevStation;
declare double expectedTrain1TimeN;
declare double expectedTrain2TimeN;

--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
INITIALIZATIONS
Instructions: If you need to define code to run in the init method for the DS2
              package, enter it here. The most common use is to define hash tables
              and hash iterators that may be used to track information. 
Result:       This code will run in the init method for the DS2 package 
              (DO NOT define the method init here... it will already exist)
--------------------------------------------------------------------------------------------

/* insert DS2 code to include in the the init method here, if applicable */

--------------------------------------------------------------------------------------------


--------------------------------------------------------------------------------------------
METHODS
Instructions: If you need to define supporting methods for your created variable,
              enter those method declarations here. 
Result:       These methods will be defined after the default methods that exist in
              each ESP DS2 package.
--------------------------------------------------------------------------------------------

/* insert supporting method definitions as DS2 code here, if applicable */

--------------------------------------------------------------------------------------------
