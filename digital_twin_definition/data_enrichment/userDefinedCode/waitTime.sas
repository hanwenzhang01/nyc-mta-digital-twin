--------------------------------------------------------------------------------------------
DEPENDENCIES
Instructions: Enter assetType --- attributeID
Result:       These attributes will exist and be accessible as their ***SASAttributeID*** 
              variable names for the code that is run.
--------------------------------------------------------------------------------------------

station --- lastDepartedTrainTime
station --- lastDepartedTrainArrivalTime
station --- lastDepartedTrainStatus

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

if find(lastDepartedTrainStatus, 'arrived') = 1 or find(lastDepartedTrainStatus, 'completed') = 1 then do;
  if lastDepartedTrainArrivalTime gt 0 and lastDepartedTrainTime gt 0 then do;
    waitTime = (lastDepartedTrainTime - lastDepartedTrainArrivalTime) / 1000000.0;
  end;
  else do;
    waitTime=.;
  end;
end;
else do;
  waitTime=.;
end;

if waitTime le 0 then waitTime=.;

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

--------------------------------------------------------------------------------------------
LOGIC
Instructions: Enter the code you would like to run. It should be SAS DS2 code and can
              access any ***SASAttributeIDs*** referenced above - and it should define how 
              to create a variable named the ***SASAttributeID*** of the new attribute.
              Users can also declare new variables, init code, and supporting 
              methods below.
Result:       This code will run for each assetID of the specified assetType.
--------------------------------------------------------------------------------------------

if strip(prevTrackTrain1) ne '' then expectedNextTrain1Time='1 minute';
else if strip(prevStationTrain1) ne '' then expectedNextTrain1Time='2 minutes';
else expectedNextTrain1Time='';

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
