//
//  SDSyncEngine.m
//  SignificantDates
//
//  Created by Corneliu Chitanu on 29/04/14.
//
//

#import "SDSyncEngine.h"
#import "SDCoreDataController.h"
#import "SDAFParseAPIClient.h"
#import "AFHTTPRequestOperation.h"
#import "NSManagedObject+JSON.h"

NSString * const kSDSyncEngineInitialCompleteKey = @"SDSyncEngineInitialSyncCompleted";
NSString * const kSDSyncEngineSyncCompletedNotificationName = @"SDSyncEngineSyncCompleted";

@interface SDSyncEngine ()

@property (nonatomic, strong) NSMutableArray *registeredClassesToSync;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, strong) dispatch_queue_t backgroundSyncQueue;

@end

@implementation SDSyncEngine

+ (SDSyncEngine *)sharedEngine {
    static SDSyncEngine *sharedEngine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedEngine = [[SDSyncEngine alloc] init];
    });
    
    return sharedEngine;
}

- (void)startSync {
    if (!self.syncInProgress) {
        [self willChangeValueForKey:@"syncInProgress"];
        _syncInProgress = YES;
        [self didChangeValueForKey:@"syncInProgress"];
        
        self.backgroundSyncQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
        
        dispatch_async(self.backgroundSyncQueue, ^{
            [self downloadDataForRegisteredObjects:YES toDeleteLocalRecords:NO];
        });
    }
}


- (void)registerNSManagedObjectClassToSync:(Class)aClass {
    if (!self.registeredClassesToSync) {
        self.registeredClassesToSync = [NSMutableArray array];
    }
    
    if ([aClass isSubclassOfClass:[NSManagedObject class]]) {
        if (![self.registeredClassesToSync containsObject:NSStringFromClass(aClass)]) {
            [self.registeredClassesToSync addObject:NSStringFromClass(aClass)];
        } else {
            NSLog(@"Unable to register %@ as it is already registered", NSStringFromClass(aClass));
        }
    } else {
        NSLog(@"Unable to register %@ as it is not a subclass of NSManagedObject", NSStringFromClass(aClass));
    }
    
}

- (BOOL)initialSyncComplete {
    return [[[NSUserDefaults standardUserDefaults] valueForKey:kSDSyncEngineInitialCompleteKey] boolValue];
}

- (void)setInitialSyncCompleted {
    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:kSDSyncEngineInitialCompleteKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)executeSyncCompletedOperations {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setInitialSyncCompleted];
        [[NSNotificationCenter defaultCenter]
         postNotificationName:kSDSyncEngineSyncCompletedNotificationName
         object:nil];
        [self willChangeValueForKey:@"syncInProgress"];
        _syncInProgress = NO;
        [self didChangeValueForKey:@"syncInProgress"];
    });
}

- (NSDate *)mostRecentUpdatedAtDateForEntityWithName:(NSString *)entityName {
    __block NSDate *date = nil;
    //
    // Create a new fetch request for the specified entity
    //
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
    //
    // Set the sort descriptors on the request to sort by updatedAt in descending order
    //
    [request setSortDescriptors:[NSArray arrayWithObject:
                                 [NSSortDescriptor sortDescriptorWithKey:@"updatedAt" ascending:NO]]];
    //
    // You are only interested in 1 result so limit the request to 1
    //
    [request setFetchLimit:1];
    [[[SDCoreDataController sharedInstance] backgroundManagedObjectContext] performBlockAndWait:^{
        NSError *error = nil;
        NSArray *results = [[[SDCoreDataController sharedInstance] backgroundManagedObjectContext] executeFetchRequest:request error:&error];
        if ([results lastObject])   {
            //
            // Set date to the fetched result
            //
            date = [[results lastObject] valueForKey:@"updatedAt"];
        }
    }];
    
    return date;
}

- (void)newManagedObjectWithClassName:(NSString *)className
                            forRecord:(NSDictionary *)record {
    
    NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:[[SDCoreDataController sharedInstance] backgroundManagedObjectContext]];
    
    [record enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self setValue:obj forKey:key forManagedObject:newManagedObject];
    }];
    [record setValue:[NSNumber numberWithInt:SDObjectSynced] forKey:@"syncStatus"];
}

- (void)updateManagedObject:(NSManagedObject *)managedObject
                 withRecord:(NSDictionary *)record {
    
    [record enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [self setValue:obj forKey:key forManagedObject:managedObject];
    }];
}

- (void)setValue:(id)value
          forKey:(NSString *)key
forManagedObject:(NSManagedObject *)managedObject {
    
    if ([key isEqualToString:@"createdAt"] ||
        [key isEqualToString:@"updatedAt"]) {
        
        NSDate *date = [self dateUsingStringFromAPI:value];
        [managedObject setValue:date forKey:key];
        
    } else if ([value isKindOfClass:[NSDictionary class]]) {
        
        if ([value objectForKey:@"__type"]) {
            
            NSString *dataType = [value objectForKey:@"__type"];
            
            if ([dataType isEqualToString:@"Date"]) {
                
                NSString *dateString = [value objectForKey:@"iso"];
                NSDate *date = [self dateUsingStringFromAPI:dateString];
                [managedObject setValue:date forKey:key];
                
            } else if ([dataType isEqualToString:@"File"]) {
                
                NSString *urlString = [value objectForKey:@"url"];
                NSURL *url = [NSURL URLWithString:urlString];
                NSURLRequest *request = [NSURLRequest requestWithURL:url];
                NSURLResponse *response = nil;
                NSError *error = nil;
                NSData *dataResponse = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                [managedObject setValue:dataResponse forKey:key];
                
            } else {
                
                NSLog(@"Unknown Data Type Received");
                [managedObject setValue:nil forKey:key];
                
            }
        }
        
    } else {
        [managedObject setValue:value forKey:key];
    }
}

- (NSArray *)managedObjectsForClass:(NSString *)className withSyncStatus:(SDObjectSyncStatus)syncStatus {
    __block NSArray *results = nil;
    NSManagedObjectContext *managedObjectContext = [[SDCoreDataController sharedInstance] backgroundManagedObjectContext];
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:className];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"syncStatus = %d", syncStatus];
    [fetchRequest setPredicate:predicate];
    [managedObjectContext performBlockAndWait:^{
        NSError *error = nil;
        results = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    }];
    
    return results;
}

- (NSArray *)managedObjectsForClass:(NSString *)className sortedByKey:(NSString *)key usingArrayOfIds:(NSArray *)idArray inArrayOfIds:(BOOL)inIds {
    __block NSArray *results = nil;
    NSManagedObjectContext *managedObjectContext = [[SDCoreDataController sharedInstance] backgroundManagedObjectContext];
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:className];
    NSPredicate *predicate;
    if (inIds) {
        predicate = [NSPredicate predicateWithFormat:@"objectId IN %@", idArray];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"NOT (objectId IN %@)", idArray];
    }
    
    [fetchRequest setPredicate:predicate];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:
                                      [NSSortDescriptor sortDescriptorWithKey:@"objectId" ascending:YES]]];
    [managedObjectContext performBlockAndWait:^{
        NSError *error = nil;
        results = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    }];
    
    return results;
}

- (void)downloadDataForRegisteredObjects:(BOOL)useUpdatedAtDate toDeleteLocalRecords:(BOOL)toDelete {
    // Create a dispatch group
    dispatch_group_t group = dispatch_group_create();
    
    for (NSString *className in self.registeredClassesToSync) {
        
        dispatch_group_enter(group);
        
        NSDate *mostRecentUpdatedDate = nil;
        if (useUpdatedAtDate) {
            mostRecentUpdatedDate = [self mostRecentUpdatedAtDateForEntityWithName:className];
        }
        AFHTTPRequestOperation *operation = [[SDAFParseAPIClient sharedSDAFParseAPIClient]
                                        GETRequestForAllRecordsOfClass:className
                                        updatedAfterDate:mostRecentUpdatedDate
                                        success:^(AFHTTPRequestOperation *operation, id responseObject) {
                                            if ([responseObject isKindOfClass:[NSDictionary class]]) {
                                                //write JSON response to disk
                                                [self writeJSONResponse:responseObject toDiskForClassWithName:className];
                                            }
                                            dispatch_group_leave(group);
                                        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                                            //
                                            NSLog(@"Request for class %@ failed with error: %@", className, error);
                                            dispatch_group_leave(group);
                                        }];
        operation.responseSerializer = [AFJSONResponseSerializer serializer];
        [operation start];
    }

    // Here we wait for all the requests to finish
    dispatch_group_notify(group, self.backgroundSyncQueue, ^{
        // Do whatever you need to do when all requests are finished
        NSLog(@"All operations completed");
        // 2
        // Need to process JSON records into Core Data
        if (!toDelete) {
            [self processJSONDataRecordsIntoCoreData];
        } else {
            [self processJSONDataRecordsForDeletion];
        }
    });
}

- (void)postLocalObjectsToServer {
    
    // Create a dispatch group
    dispatch_group_t group = dispatch_group_create();
    
    NSMutableArray *operations = [NSMutableArray array];
    //
    // Iterate over all register classes to sync
    //
    for (NSString *className in self.registeredClassesToSync) {
        
        //
        // Fetch all objects from Core Data whose syncStatus is equal to SDObjectCreated
        //
        NSArray *objectsToCreate = [self managedObjectsForClass:className withSyncStatus:SDObjectCreated];
        //
        // Iterate over all fetched objects who syncStatus is equal to SDObjectCreated
        //
        for (NSManagedObject *objectToCreate in objectsToCreate) {
            
            dispatch_group_enter(group);
            
            //
            // Get the JSON representation of the NSManagedObject
            //
            NSDictionary *jsonString = [objectToCreate JSONToCreateObjectOnServer];
            //
            // Create a request using your POST method with the JSON representation of the NSManagedObject
            //
            
            AFHTTPRequestOperation *operation = [[SDAFParseAPIClient sharedSDAFParseAPIClient] POSTRequestForClass:className parameters:jsonString success:^(AFHTTPRequestOperation *operation, id responseObject) {
                //
                // Set the completion block for the operation to update the NSManagedObject with the createdDate from the
                // remote service and objectId, then set the syncStatus to SDObjectSynced so that the sync engine does not
                // attempt to create it again
                //
                NSLog(@"Success creation: %@", responseObject);
                NSDictionary *responseDictionary = responseObject;
                NSDate *createdDate = [self dateUsingStringFromAPI:[responseDictionary valueForKey:@"createdAt"]];
                [objectToCreate setValue:createdDate forKey:@"createdAt"];
                [objectToCreate setValue:[responseDictionary valueForKey:@"objectId"] forKey:@"objectId"];
                [objectToCreate setValue:[NSNumber numberWithInt:SDObjectSynced] forKey:@"syncStatus"];
                
                dispatch_group_leave(group);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                //
                // Log an error if there was one, proper error handling should be done if necessary, in this case it may not
                // be required to do anything as the object will attempt to sync again next time. There could be a possibility
                // that the data was malformed, fields were missing, extra fields were present etc... so it is a good idea to
                // determine the best error handling approach for your production applications.
                //
                NSLog(@"Failed creation: %@", error);
                
                dispatch_group_leave(group);
            }];
            operation.responseSerializer = [AFJSONResponseSerializer serializer];
            
            //
            // Add all operations to the operations NSArray
            //
            [operations addObject:operation];
            [operation start];
        }
    }
    
    
    //
    // Pass off operations array to the sharedClient so that they are all executed
    //
    
    
    // Here we wait for all the requests to finish
    dispatch_group_notify(group, self.backgroundSyncQueue, ^{
        // Do whatever you need to do when all requests are finished
        //
        // Set the completion block to save the backgroundContext
        //
        if ([operations count] > 0) {
            [[SDCoreDataController sharedInstance] saveBackgroundContext];
            [[SDCoreDataController sharedInstance] saveMasterContext];
        }
        
        //
        // Invoke executeSyncCompletionOperations as this is now the final step of the sync engine's flow
        //
        [self deleteObjectsOnServer];
    });
}

- (void)deleteObjectsOnServer {
    
    dispatch_group_t group = dispatch_group_create();
    
    NSMutableArray *operations = [NSMutableArray array];
    //
    // Iterate over all registered classes to sync
    //
    for (NSString *className in self.registeredClassesToSync) {
        //
        // Fetch all records from Core Data whose syncStatus is equal to SDObjectDeleted
        //
        NSArray *objectsToDelete = [self managedObjectsForClass:className withSyncStatus:SDObjectDeleted];
        //
        // Iterate over all fetched records from Core Data
        //
        for (NSManagedObject *objectToDelete in objectsToDelete) {
            
            dispatch_group_enter(group);
            //
            // Create a request for each record
            //
            AFHTTPRequestOperation *operation = [[SDAFParseAPIClient sharedSDAFParseAPIClient] DELETERequestForClass:className forObjectWithId:[objectToDelete valueForKey:@"objectId"] success:^(AFHTTPRequestOperation *operation, id responseObject) {
                NSLog(@"Success deletion: %@", responseObject);
                //
                // In the operations completion block delete the NSManagedObject from Core data locally since it has been
                // deleted on the server
                //
                [[[SDCoreDataController sharedInstance] backgroundManagedObjectContext] deleteObject:objectToDelete];
                dispatch_group_leave(group);
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSLog(@"Failed to delete: %@", error);
                dispatch_group_leave(group);
            }];
            operation.responseSerializer = [AFHTTPResponseSerializer serializer];
            //
            // Add each operation to the operations array
            //
            [operations addObject:operation];
            [operation start];
        }
    }
    
    dispatch_group_notify(group, self.backgroundSyncQueue, ^{
        
        if ([operations count] > 0) {
            //
            // Save the background context after all operations have completed
            //
            [[SDCoreDataController sharedInstance] saveBackgroundContext];
            [[SDCoreDataController sharedInstance] saveMasterContext];
        }
        
        //
        // Execute the sync completed operations
        //
        [self executeSyncCompletedOperations];
    });
}

#pragma mark - Date formatting

- (void)initializeDateFormatter {
    if (!self.dateFormatter) {
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
        [self.dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    }
}

- (NSDate *)dateUsingStringFromAPI:(NSString *)dateString {
    [self initializeDateFormatter];
    // NSDateFormatter does not like ISO 8601 so strip the milliseconds and timezone
    dateString = [dateString substringWithRange:NSMakeRange(0, [dateString length]-5)];
    
    return [self.dateFormatter dateFromString:dateString];
}

- (NSString *)dateStringForAPIUsingDate:(NSDate *)date {
    [self initializeDateFormatter];
    NSString *dateString = [self.dateFormatter stringFromDate:date];
    // remove Z
    dateString = [dateString substringWithRange:NSMakeRange(0, [dateString length]-1)];
    // add milliseconds and put Z back on
    dateString = [dateString stringByAppendingFormat:@".000Z"];
    
    return dateString;
}

#pragma mark - File Management

- (NSURL *)applicationCacheDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSURL *)JSONDataRecordsDirectory{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *url = [NSURL URLWithString:@"JSONRecords/" relativeToURL:[self applicationCacheDirectory]];
    NSError *error = nil;
    if (![fileManager fileExistsAtPath:[url path]]) {
        [fileManager createDirectoryAtPath:[url path] withIntermediateDirectories:YES attributes:nil error:&error];
    }
    
    return url;
}

- (void)writeJSONResponse:(id)response toDiskForClassWithName:(NSString *)className {
    NSURL *fileURL = [NSURL URLWithString:className relativeToURL:[self JSONDataRecordsDirectory]];
    if (![(NSDictionary *)response writeToFile:[fileURL path] atomically:YES]) {
        NSLog(@"Error saving response to disk, will attempt to remove NSNull values and try again.");
        // remove NSNulls and try again...
        NSArray *records = [response objectForKey:@"results"];
        NSMutableArray *nullFreeRecords = [NSMutableArray array];
        for (NSDictionary *record in records) {
            NSMutableDictionary *nullFreeRecord = [NSMutableDictionary dictionaryWithDictionary:record];
            [record enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if ([obj isKindOfClass:[NSNull class]]) {
                    [nullFreeRecord setValue:nil forKey:key];
                }
            }];
            [nullFreeRecords addObject:nullFreeRecord];
        }
        
        NSDictionary *nullFreeDictionary = [NSDictionary dictionaryWithObject:nullFreeRecords forKey:@"results"];
        
        if (![nullFreeDictionary writeToFile:[fileURL path] atomically:YES]) {
            NSLog(@"Failed all attempts to save response to disk: %@", response);
        }
    }
}

#pragma mark - Process remote service data into Core Data

- (void)deleteJSONDataRecordsForClassWithName:(NSString *)className {
    NSURL *url = [NSURL URLWithString:className relativeToURL:[self JSONDataRecordsDirectory]];
    NSError *error = nil;
    BOOL deleted = [[NSFileManager defaultManager] removeItemAtURL:url error:&error];
    if (!deleted) {
        NSLog(@"Unable to delete JSON Records at %@, reason: %@", url, error);
    }
}

- (NSDictionary *)JSONDictionaryForClassWithName:(NSString *)className {
    NSURL *fileURL = [NSURL URLWithString:className
                            relativeToURL:[self JSONDataRecordsDirectory]];
    return [NSDictionary dictionaryWithContentsOfURL:fileURL];
}

- (NSArray *)JSONDataRecordsForClass:(NSString *)className sortedByKey:(NSString *)key {
    NSDictionary *JSONDictionary = [self JSONDictionaryForClassWithName:className];
    NSArray *records = [JSONDictionary objectForKey:@"results"];
    return [records sortedArrayUsingDescriptors:[NSArray arrayWithObject:
                                                 [NSSortDescriptor sortDescriptorWithKey:key ascending:YES]]];
}

- (void)processJSONDataRecordsIntoCoreData {
    NSManagedObjectContext *managedObjectContext = [[SDCoreDataController sharedInstance] backgroundManagedObjectContext];
    //
    // Iterate over all registered classes to sync
    //
    for (NSString *className in self.registeredClassesToSync) {
        if (![self initialSyncComplete]) { // import all downloaded data to Core Data for initial sync
            //
            // If this is the initial sync then the logic is pretty simple, you will fetch the JSON data from disk
            // for the class of the current iteration and create new NSManagedObjects for each record
            //
            NSDictionary *JSONDictionary = [self JSONDictionaryForClassWithName:className];
            NSArray *records = [JSONDictionary objectForKey:@"results"];
            for (NSDictionary *record in records) {
                [self newManagedObjectWithClassName:className forRecord:record];
            }
        } else {
            //
            // Otherwise you need to do some more logic to determine if the record is new or has been updated.
            // First get the downloaded records from the JSON response, verify there is at least one object in
            // the data, and then fetch all records stored in Core Data whose objectId matches those from the JSON response.
            //
            NSArray *downloadedRecords = [self JSONDataRecordsForClass:className sortedByKey:@"objectId"];
            if ([downloadedRecords lastObject]) {
                //
                // Now you have a set of objects from the remote service and all of the matching objects
                // (based on objectId) from your Core Data store. Iterate over all of the downloaded records
                // from the remote service.
                //
                NSArray *storedRecords = [self managedObjectsForClass:className sortedByKey:@"objectId" usingArrayOfIds:[downloadedRecords valueForKey:@"objectId"] inArrayOfIds:YES];
                int currentIndex = 0;
                //
                // If the number of records in your Core Data store is less than the currentIndex, you know that
                // you have a potential match between the downloaded records and stored records because you sorted
                // both lists by objectId, this means that an update has come in from the remote service
                //
                for (NSDictionary *record in downloadedRecords) {
                    NSManagedObject *storedManagedObject = nil;
                    
                    // Make sure we don't access an index that is out of bounds as we are iterating over both collections together
                    if ([storedRecords count] > currentIndex) {
                        storedManagedObject = [storedRecords objectAtIndex:currentIndex];
                    }
                    
                    if ([[storedManagedObject valueForKey:@"objectId"] isEqualToString:[record valueForKey:@"objectId"]]) {
                        //
                        // Do a quick spot check to validate the objectIds in fact do match, if they do update the stored
                        // object with the values received from the remote service
                        //
                        [self updateManagedObject:[storedRecords objectAtIndex:currentIndex] withRecord:record];
                    } else {
                        //
                        // Otherwise you have a new object coming in from your remote service so create a new
                        // NSManagedObject to represent this remote object locally
                        //
                        [self newManagedObjectWithClassName:className forRecord:record];
                    }
                    currentIndex++;
                }
            }
        }
        //
        // Once all NSManagedObjects are created in your context you can save the context to persist the objects
        // to your persistent store. In this case though you used an NSManagedObjectContext who has a parent context
        // so all changes will be pushed to the parent context
        //
        [managedObjectContext performBlockAndWait:^{
            NSError *error = nil;
            if (![managedObjectContext save:&error]) {
                NSLog(@"Unable to save context for class %@", className);
            }
        }];
        
        //
        // You are now done with the downloaded JSON responses so you can delete them to clean up after yourself,
        // then call your -executeSyncCompletedOperations to save off your master context and set the
        // syncInProgress flag to NO
        //
        [self deleteJSONDataRecordsForClassWithName:className];
    }
    [self downloadDataForRegisteredObjects:NO toDeleteLocalRecords:YES];
}

- (void)processJSONDataRecordsForDeletion {
    NSManagedObjectContext *managedObjectContext = [[SDCoreDataController sharedInstance] backgroundManagedObjectContext];
    //
    // Iterate over all registered classes to sync
    //
    for (NSString *className in self.registeredClassesToSync) {
        //
        // Retrieve the JSON response records from disk
        //
        NSArray *JSONRecords = [self JSONDataRecordsForClass:className sortedByKey:@"objectId"];
        if ([JSONRecords count] > 0) {
            //
            // If there are any records fetch all locally stored records that are NOT in the list of downloaded records
            //
            NSArray *storedRecords = [self
                                      managedObjectsForClass:className
                                      sortedByKey:@"objectId"
                                      usingArrayOfIds:[JSONRecords valueForKey:@"objectId"]
                                      inArrayOfIds:NO];
            
            //
            // Schedule the NSManagedObject for deletion and save the context
            //
            [managedObjectContext performBlockAndWait:^{
                for (NSManagedObject *managedObject in storedRecords) {
                    [managedObjectContext deleteObject:managedObject];
                }
                NSError *error = nil;
                BOOL saved = [managedObjectContext save:&error];
                if (!saved) {
                    NSLog(@"Unable to save context after deleting records for class %@ because %@", className, error);
                }
            }];
        }
        
        //
        // Delete all JSON Record response files to clean up after yourself
        //
        [self deleteJSONDataRecordsForClassWithName:className];
    }
    
    [self postLocalObjectsToServer];
}

@end
