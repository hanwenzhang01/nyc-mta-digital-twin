import esp 

train_list = {} 
 
class Train: 
    """
    Represents a subway train being tracked in the system.
    - Initializes trains & train attributes when first detected
    - Updates train status and location based on new data

    Attributes:
        id (str): Unique train identifier (assetID)
        route (str): Route the train is assigned to
        destination (str): Final destination of the train
        curr_status (str): Current status ('stopped' or 'moving')
        curr_loc (str): Current location
        curr_conn (str): Connection descriptor used for routing logic
        msr_timestamp (int): Timestamp of the last update
    """

    def __init__(self, id, route, trainDestination, location_status, location, msr_timestamp): 
        """
        Initializes a Train object.

        Args:
            id (str): Unique train identifier (assetID)
            route (str): Assigned route
            trainDestination (str): Final destination
            location_status (str): Status from GTFS (STOPPED_AT, INCOMING_AT, IN_TRANSIT_TO)
            location (str): Current location
            msr_timestamp (int): Timestamp of the update

        Notes:
            For this system, INCOMING_AT is treated the same as IN_TRANSIT_TO.
        """
        self.id = id

        # Set route and destination if provided
        if route != "": 
            self.route = route 
        if trainDestination != "": 
            self.destination = trainDestination 

        # Determine initial status and connection based on GTFS location_status
        if location_status == 'STOPPED_AT': 
            self.curr_status = 'stopped' 
            self.curr_loc    = location 
            self.curr_conn   = location 
        elif location_status != "": 
            self.curr_status = 'moving' 
            self.curr_loc    = location 
            self.curr_conn   = 'enrouteTo'+location 
        else: 
            self.curr_status = '' 
            self.curr_loc    = '' 
            self.curr_conn   = '' 
 
        self.msr_timestamp = msr_timestamp 
 
    def __str__(self): 
        """
        String representation of the train for logging/debugging.
        """
        return f"Train(id={self.id}, route={self.route}, trainDestination={self.destination}, curr_status={self.curr_status}, curr_loc={self.curr_loc}, curr_conn={self.curr_conn}, msr_timestamp={self.msr_timestamp})" 
 
    def update(self, route, trainDestination, location_status, location, msr_timestamp): 
        """
        Updates the train's status and location based on new incoming data.

        Args:
            route (str): Updated route
            trainDestination (str): Updated destination
            location_status (str): Updated GTFS status
            location (str): Updated location
            msr_timestamp (str): Timestamp of the update

        Returns:
            updates: A list of structured update records
        """
        updates = [] 

        # Update route and destination if new values are provided
        if route != "": 
            self.route = route 
        if trainDestination != "": 
            self.destination = trainDestination 
        
        # Determine new status and connection
        if location_status == "STOPPED_AT": 
            this_status = 'stopped' 
            this_loc    = location 
            this_conn   = location 
        else: 
            this_status = 'moving' 
            this_loc    = location 
            this_conn   = 'enrouteTo'+location 

        # First-time update: no current connection exists
        # Updates status and connections
        if self.curr_conn == "":
            if this_status == "stopped": 
                updates.append([msr_timestamp,self.id,'currentStatus','stoppedAt '+this_loc,'data','','','','','','','','','','']) 
                updates.append([msr_timestamp,'','','','updateConnections','','','','','','add',self.route,this_conn,'<->',self.id]) 
            else: 
                updates.append([msr_timestamp,self.id,'currentStatus','enrouteTo '+this_loc,'data','','','','','','','','','','']) 
                updates.append([msr_timestamp,'','','','updateConnections','','','','','','add',self.route,this_conn,'<->',self.id]) 

        # No change in connection — train remains at same location with the same status
        # Updates only status
        elif self.curr_conn == this_conn: 
            if self.curr_status == 'stopped':
                # Updating status from recently arrived to stoppedAt
                updates.append([msr_timestamp,self.id,'currentStatus','stoppedAt '+this_loc,'data','','','','','','','','','',''])  
            else:
                # Updating status from departedTo to enrouteTo
                updates.append([msr_timestamp,self.id,'currentStatus','enrouteTo '+this_loc,'data','','','','','','','','','','']) 
 
        # Status unchanged but location changed — implies skipped event
        # Updates status and connections
        elif self.curr_status == this_status and self.curr_loc != this_loc:  
            if this_status == 'stopped': 
                if self.destination == this_loc: 
                    updates.append([msr_timestamp,self.id,'currentStatus','stoppedAt '+this_loc,'data','','','','','','','','','','']) 
                    updates.append([msr_timestamp,'','','','updateAssets','delete',self.id,'train',self.id,'N','','','','','']) 
                else: 
                    updates.append([msr_timestamp,self.id,'currentStatus','stoppedAt '+this_loc,'data','','','','','','','','','',''])
                    updates.append([msr_timestamp,'','','','updateConnections','','','','','','delete',self.route,self.curr_conn,'<->',self.id]) 
                    updates.append([msr_timestamp,'','','','updateConnections','','','','','','add',self.route,this_conn,'<->',self.id]) 
            else: 
                updates.append([msr_timestamp,self.id,'currentStatus','enrouteTo '+this_loc,'data','','','','','','','','','','']) 
                updates.append([msr_timestamp,'','','','updateConnections','','','','','','delete',self.route,self.curr_conn,'<->',self.id]) 
                updates.append([msr_timestamp,'','','','updateConnections','','','','','','add',self.route,this_conn,'<->',self.id]) 

        # Status change — e.g., moving → stopped or stopped → moving
        elif self.curr_status != this_status: 
            if this_status == 'stopped': 
                # Train has arrived at a station
                updates.append([msr_timestamp,self.id,'stationArrival',this_loc,'data','','','','','','','','','','']) 
                updates.append([msr_timestamp,this_loc,'trainArrival',self.id,'data','','','','','','','','','','']) 

                updates.append([msr_timestamp,self.id,'trackEnrouteToEnd','enrouteTo'+this_loc,'data','','','','','','','','','','']) 
                updates.append([msr_timestamp,'enrouteTo'+this_loc,'enrouteToEnd',self.id,'data','','','','','','','','','','']) 
 
                if self.destination == this_loc: 
                    # Train has completed its route
                    updates.append([msr_timestamp,self.id,'currentStatus','completedRouteAt '+this_loc,'data','','','','','','','','','','']) 
                    updates.append([msr_timestamp,'','','','updateAssets','delete',self.id,'train',self.id,'N','','','','','']) 
                else: 
                    # Train arrived at a non-destination station
                    updates.append([msr_timestamp,self.id,'currentStatus','arrivedAt '+this_loc,'data','','','','','','','','','','']) 
                    updates.append([msr_timestamp,'','','','updateConnections','','','','','','delete',self.route,self.curr_conn,'<->',self.id]) 
                    updates.append([msr_timestamp,'','','','updateConnections','','','','','','add',self.route,this_conn,'<->',self.id]) 
 
            else:
                # Train has departed a station and is now moving 
                updates.append([msr_timestamp,self.id,'stationDepartureFrom',self.curr_loc,'data','','','','','','','','','','']) 
                updates.append([msr_timestamp,self.curr_loc,'trainDepartureFrom',self.id,'data','','','','','','','','','','']) 
                updates.append([msr_timestamp,self.id,'stationDepartureTo',this_loc,'data','','','','','','','','','','']) 
                updates.append([msr_timestamp,this_loc,'trainDepartureTo',self.id,'data','','','','','','','','','','']) 
 
                updates.append([msr_timestamp,self.id,'trackEnrouteToStart','enrouteTo'+this_loc,'data','','','','','','','','','','']) 
                updates.append([msr_timestamp,'enrouteTo'+this_loc,'enrouteToStart',self.id,'data','','','','','','','','','','']) 
 
                updates.append([msr_timestamp,self.id,'currentStatus','departedTo '+this_loc,'data','','','','','','','','','','']) 
                updates.append([msr_timestamp,'','','','updateConnections','','','','','','delete',self.route,self.curr_conn,'<->',self.id]) 
                updates.append([msr_timestamp,'','','','updateConnections','','','','','','add',self.route,this_conn,'<->',self.id]) 
 
        else: 
            # Catch-all for edge cases not covered above
            if this_status == "stopped": 
                if self.trainDestination == this_loc: 
                    # Train has stopped at its destination
                    updates.append([msr_timestamp,self.id,'currentStatus','stoppedAt '+this_loc,'data','','','','','','','','','','']) 
                    updates.append([msr_timestamp,'','','','updateAssets','delete',self.id,'train',self.id,'N','','','','','']) 
                else: 
                    # Train stopped at a non-destination location
                    updates.append([msr_timestamp,self.id,'currentStatus','stoppedAt '+this_loc,'data','','','','','','','','','','']) 
                    updates.append([msr_timestamp,'','','','updateConnections','','','','','','delete',self.route,self.curr_conn,'<->',self.id]) 
                    updates.append([msr_timestamp,'','','','updateConnections','','','','','','add',self.route,this_conn,'<->',self.id]) 
            else: 
                # Train is moving to a new location
                updates.append([msr_timestamp,self.id,'currentStatus','enrouteTo '+this_loc,'data','','','','','','','','','','']) 
                updates.append([msr_timestamp,'','','','updateConnections','','','','','','delete',self.route,self.curr_conn,'<->',self.id]) 
                updates.append([msr_timestamp,'','','','updateConnections','','','','','','add',self.route,this_conn,'<->',self.id]) 
 
        # Updating train information for the next processing 
        self.curr_status      = this_status 
        self.curr_loc         = this_loc 
        self.curr_conn        = this_conn 

        # Sending all update records from this update block
        return updates 
 
def find_route(long_route):
    """
    Parses a full route identifier and returns the abbreviated route name.

    Expected input formats:
        - "1..S03R" → returns "1..S"
        - "SI.S03R" → returns "SI.S"
        - "FS.N02R" → returns "FS.N"
        - Special case: "SI.NXXX" → returns "SI.." (not "SI..N")
    """
    dot_index = long_route.find("..")

    if dot_index != -1:
        # Route contains ".." — return prefix plus next character (e.g., "1..S")
        return long_route[:dot_index + 3]
    else:
        dot_index = long_route.find(".")
        if long_route[:2] == 'SI':
            # Special handling for Staten Island routes
            if dot_index != -1 and len(long_route) > dot_index + 1:
                if long_route[dot_index + 1] == 'S':
                    return 'SI..S'
                elif long_route[dot_index + 1] == 'N':
                    return 'SI..'
        else:
            # General case: return prefix plus next character (e.g., "FS.N")
            if dot_index != -1:
                return long_route[:dot_index + 2]

    # Fallback: return original string if no known pattern matched
    return long_route

def gtfs_read_function(events,thisroute): 
    global key1 
    import time 
    import urllib 
    import urllib.request 
    import getpass 
    import string 
    import datetime as dt 
    import json 
    from nyct_gtfs import NYCTFeed # Library for accessing MTA GTFS data
    import re 
    from datetime import datetime, timezone, timedelta 
 
    # Initialize counters and storage containers
    numrecs = 0           # Number of records processed
    alltrips = []         # List to store parsed train trip data
    failedquery = 0       # Flag for API query failure
    failedread = 0        # Flag for data parsing failure 
 
    try: 
        # Query the GTFS API for current trips on a specified subway route
        feed=NYCTFeed(thisroute) 
        trains = feed.filter_trips(line_id=[thisroute],underway=True) 
    except: 
        failedquery=1 
 
    if failedquery==0: 
        for train in trains: 

            # Attempt to extract the train's unique asset ID
            try: 
                assetID = train.nyc_train_id 
            except: 
                failedread = 1 

            # Attempt to parse and simplify the route identifier
            try: 
                route = find_route(train.shape_id) 
            except: 
                failedread = 1 

            # Use the current UTC time as the timestamp
            try: 
                utc_now = datetime.now(timezone.utc)
                curr_timestamp=int(utc_now.timestamp()*1000000)
                msr_timestamp = curr_timestamp

                # Old code extracting the timestamp from the last position update
                # Faced issues with the timestamp
                # msr_timestamp=int(train.last_position_update.timestamp()*1000000) 
            except: 
                failedread = 1 

            # Attempt to extract the train's current location
            try: 
                location = train.location 
            except: 
                failedread = 1 

            # Attempt to extract the train's location status
            try: 
                location_status = train.location_status 
            except: 
                failedread = 1 

            # Attempt to extract the stop index in the train's route sequence
            try: 
                stopIndex = str(train.current_stop_sequence_index) 
            except: 
                # Non-issue if the stop index is not found
                stopIndex="" 
                doNothing = 1 

            # Attempt to extract and format the train's scheduled departure time
            try: 
                departure_timestamp=int(train.departure_time.timestamp()*1000000) 
 
                departure_datetime = train.departure_time 
                departureDateString = departure_datetime.strftime("%Y-%m-%d %H:%M:%S") 
                departureDateString = departureDateString[0:10] 
            except: 
                failedread = 1 

            # Attempt to extract the list of upcoming stops and final destination
            try: 
                # Extracting the list of upcoming stops for the train
                remainingStops=train.stop_time_updates 

                # Converting the stop data to a string for manual formatting
                asString=str(remainingStops) 

                # Perform a series of string replacements to convert the raw stop data into valid JSON format
                # These replacements add quotes and colons to make the data parsable by json.loads()
                asString=asString.replace('ID: ', 'ID: "') 
                asString=asString.replace('Arr: ', 'Arr: "') 
                asString=asString.replace('Dep: ', 'Dep: "') 
                asString=asString.replace('Sched: ', 'Sched: "') 
                asString=asString.replace('Act: ', 'Act: "') 
                asString=asString.replace(', Arr', '", Arr') 
                asString=asString.replace(', Dep', '", Dep') 
                asString=asString.replace(', Sched', '", Sched') 
                asString=asString.replace(', Act', '", Act') 
                asString=asString.replace('ID:', '"ID":') 
                asString=asString.replace('Arr:', '"Arr":') 
                asString=asString.replace('Dep:', '"Dep":') 
                asString=asString.replace('Sched:', '"Sched":') 
                asString=asString.replace('Act:', '"Act":') 
                asString=asString.replace('},', '"},') 
                asString=asString.replace(', }', '", }') 
                asString=asString.replace(', }', '}') 
                asString=asString.replace('}]', '"}]') 

                # Create JSON object
                asJson=json.loads(asString) 

                # Count the number of stops in the route
                numStops=len(asJson) 
                
                # Determine the train's destination based on the number of stops
                if numStops<3:
                    # If there are fewer than 3 stops, use the first stop as the destination
                    trainDestination=asJson[0]['ID']
                else:
                    # Otherwise, use the second-to-last stop as the destination
                    trainDestination=asJson[numStops-2]['ID']
            except:
                # If parsing fails, log a warning and set default values
                print('WARNING: Could not get trainDestination')
                trainDestination=""
                nothingNeeded = 1

            # Attempt to create a list of upcoming stops
            # And parse out the expected route completion time
            try:
                # Repeat the stop parsing process to build a list of all stop IDs
                remainingStops=train.stop_time_updates
                asString=str(remainingStops)

                # Apply the same string replacements as above to format the data
                asString=asString.replace('ID: ', 'ID: "')
                asString=asString.replace('Arr: ', 'Arr: "')
                asString=asString.replace('Dep: ', 'Dep: "')
                asString=asString.replace('Sched: ', 'Sched: "')
                asString=asString.replace('Act: ', 'Act: "')
                asString=asString.replace(', Arr', '", Arr')
                asString=asString.replace(', Dep', '", Dep')
                asString=asString.replace(', Sched', '", Sched')
                asString=asString.replace(', Act', '", Act')
                asString=asString.replace('ID:', '"ID":')
                asString=asString.replace('Arr:', '"Arr":')
                asString=asString.replace('Dep:', '"Dep":')
                asString=asString.replace('Sched:', '"Sched":')
                asString=asString.replace('Act:', '"Act":')
                asString=asString.replace('},', '"},')
                asString=asString.replace(', }', '", }')
                asString=asString.replace(', }', '}')
                asString=asString.replace('}]', '"}]')

                # Parse the formatted string into JSON
                asJson=json.loads(asString)
                numStops=len(asJson)

                # Build a dash-separated string of all stop IDs in the route
                allStopsList="" 
                for thisStopNum in range(numStops): 
                    thisStopID=asJson[thisStopNum]['ID'] 
                    if allStopsList=="": 
                        allStopsList=thisStopID 
                    else: 
                        allStopsList=allStopsList+'-'+thisStopID 

                # If the train is at the beginning of its route, estimate its completion time
                if stopIndex=="0" or stopIndex=="1": 
                    expectedCompletion=str(asJson[numStops-1]['Arr']) 
                    currentDate=str(train.start_date) 

                    # Parse date and time components
                    year=int(currentDate[0:4]) 
                    month=int(currentDate[5:7]) 
                    day=int(currentDate[8:10]) 
                    hour=int(expectedCompletion[0:2]) 
                    minute=int(expectedCompletion[3:5]) 
                    second=int(expectedCompletion[6:8]) 

                    # Construct a datetime object for expected completion
                    expcompl = datetime(year, month, day, hour, minute, second) 

                    # Convert to microsecond timestamp
                    expcompl_timestamp = str(int(expcompl.timestamp())* 1000000) 
                else: 
                    expcompl_timestamp="" 
 
            except: 
                # If parsing fails, log a note and set default values
                nothingNeeded = 1 
                print('NOTE: Could not get all stops list')
                allStopsList = ""
                expcompl_timestamp=""
 
            # Send in all updates only if data was successfully read 
            if failedread == 0: 
 
                # Generate a unique train ID by sanitizing the assetID and prefixing with departure date
                # Example: "0L 1402+8AV/RPY" → "t_0L_1402_8AV_RPY"
                t_id = "t_"+re.sub('[^A-Za-z0-9]', '_', assetID) 
                t_id = departureDateString+t_id 

                # If this train has been seen before, send updates
                if t_id in train_list: 

                    # Raw location status update
                    key1 = key1 + 1 
                    temprecord = [key1, msr_timestamp, str(assetID), 'currentStatusRaw', str(location_status+"---"+location), 'data','','','','','','','','','',''] 
                    alltrips.append(tuple(temprecord)) 
                    numrecs = numrecs + 1 

                    # Route update
                    key1 = key1 + 1 
                    temprecord = [key1, msr_timestamp, str(assetID), 'route', str(route), 'data','','','','','','','','','',''] 
                    alltrips.append(tuple(temprecord)) 
                    numrecs = numrecs + 1 

                    # Destination update, if available
                    if trainDestination != "": 
                        key1 = key1 + 1 
                        temprecord = [key1, msr_timestamp,str(assetID),'trainDestination',trainDestination,'data','','','','','','','','','',''] 
                        alltrips.append(tuple(temprecord)) 
                        numrecs = numrecs + 1 

                    # Departure time update, if available
                    if departure_timestamp != "": 
                        key1 = key1 + 1 
                        temprecord = [key1, msr_timestamp, str(assetID), 'trainDepartureTimestamp', str(departure_timestamp), 'data','','','','','','','','','',''] 
                        alltrips.append(tuple(temprecord)) 
                        numrecs = numrecs + 1 

                    # Expected completion time update, if just starting and available
                    if (stopIndex=="0" or stopIndex=="1") and expcompl_timestamp != "": 
                        key1 = key1 + 1 
                        temprecord = [key1, msr_timestamp, str(assetID), 'trainExpArrivalTimestamp', str(expcompl_timestamp), 'data','','','','','','','','','',''] 
                        alltrips.append(tuple(temprecord)) 
                        numrecs = numrecs + 1 

                    # Remaining stops update, if available
                    if allStopsList != "": 
                        key1 = key1 + 1 
                        temprecord = [key1, msr_timestamp, str(assetID), 'remainingStops', str(allStopsList), 'data','','','','','','','','','',''] 
                        alltrips.append(tuple(temprecord)) 
                        numrecs = numrecs + 1 

                    # Stop index update, if available
                    if stopIndex != "": 
                        key1 = key1 + 1 
                        temprecord = [key1, msr_timestamp,str(assetID),'stopIndex',stopIndex,'data','','','','','','','','','',''] 
                        alltrips.append(tuple(temprecord)) 
                        numrecs = numrecs + 1 

                    # Location status update, based on status
                    if location_status == "STOPPED_AT": 
                        key1 = key1 + 1 
                        temprecord = [key1, msr_timestamp,str(assetID),'currentLocation',location,'data','','','','','','','','','',''] 
                        alltrips.append(tuple(temprecord)) 
                        numrecs = numrecs + 1 
                    else: 
                        key1 = key1 + 1 
                        temprecord = [key1, msr_timestamp,str(assetID),'currentLocation','enrouteTo'+location,'data','','','','','','','','','',''] 
                        alltrips.append(tuple(temprecord)) 
                        numrecs = numrecs + 1 
                    
                    # Expected completion time update, if available
                    if expcompl_timestamp != "":
                        key1 = key1 + 1
                        temprecord = [key1, msr_timestamp, str(assetID), 'trainExpArrivalTimestamp', str(expcompl_timestamp), 'data','','','','','','','','','','']
                        alltrips.append(tuple(temprecord))
                        numrecs = numrecs + 1

                    # Update the train object in train_list with new data
                    t = train_list.get(t_id) 
                    updates = t.update(route, trainDestination, location_status, location, msr_timestamp) 

                    # Append each update from the Train class to alltrips
                    for x in updates: 
                        key1 = key1 + 1 
                        x.insert(0,key1) 
                        alltrips.append(tuple(x)) 
                        numrecs = numrecs + 1 
                
                # If train is new and not yet at its destination, create a new train object
                elif (location!="" and trainDestination!="" and location!=trainDestination):
                    key1 = key1 + 1 
                    temprecord = [key1, msr_timestamp,'','','','updateAssets','add',str(assetID),'train', str(assetID),'Y','','','','',''] 
                    alltrips.append(tuple(temprecord)) 
                    numrecs = numrecs + 1 
 
                    # Add new train object to train_list
                    train_list[t_id] = Train(assetID, route, trainDestination, location_status, location, msr_timestamp)

                # If train is at its destination or missing key data, skip processing

                # Print statements for debugging/logging
                """
                print('assetID:', assetID)
                print('location:', location)
                print('location_status:', location_status)
                print('len(remainingStops):', len(remainingStops))
                print('destination: ', trainDestination)
                """

            # If data read failed, log an error and record it
            else: 
                print('WARNING: Missing information') 
                key1 = key1 + 1 
                temprecord = [key1, msr_timestamp,'readError','readError','readError','data','','','','','','','','','',''] 
                alltrips.append(tuple(temprecord)) 
                numrecs = numrecs + 1 
 
    # Convert each tuple in alltrips into a structured dictionary and append to events
    for value in alltrips: 
       e = {} 
       e['key1'] = value[0] 
       e['msr_timestamp'] = value[1] 
       e['assetID'] = value[2] 
       e['attributeID'] = value[3] 
       e['value'] = value[4] 
       e['action'] = value[5] 
       e['updateAssetAction'] = value[6] 
       e['updateAssetID'] = value[7] 
       e['updateAssetType'] = value[8] 
       e['updateAssetLabel'] = value[9] 
       e['updateAssetOutputRequired'] = value[10] 
       e['updateConnectionAction'] = value[11] 
       e['updateHierarchyName'] = value[12] 
       e['updateParentAssetID'] = value[13] 
       e['updateDirection'] = value[14] 
       e['updateChildAssetID'] = value[15] 
       events.append(e) 
    
    # Return the full list of structured event dictionaries
    return (events) 
 
def create(data,context): 
    """
    Entry point function for generating train tracking data.

    Args:
        data (dict): Contains metadata including the 'id' used for key generation.
        context (dict): Additional runtime context.

    Returns:
        events: A list of structured event dictionaries for the specified routes.
    """
    events = [] # Empty list to hold event records

    global key1 
    key1=int(data["id"] * 100000.0) # Generate a base key using the input ID

    countCalls=int(data["id"]+1) # Used to determine when to trigger data collection

    # Only run GTFS data collection on specific cycles
    if (countCalls % 6) == 2 or (countCalls % 6) == 5: 
 
        # List of subway routes to query
        routeList = [ 
                     ('L'), 
                     ('1'), 
                     ('6'), 
                     ('7'), 
                     ('E'), 
                     ('Q') 
                    ] 
        
        # For each route, call the GTFS reader to collect and parse train data
        for route in routeList: 
            gtfs_read_function(events,route) 
 
    else: 
        # Skip data collection on other cycles
        doNothing = 1 
        
    # Return the compiled list of events
    return events]]