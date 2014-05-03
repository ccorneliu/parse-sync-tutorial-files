//
//  Holiday.m
//  SignificantDates
//
//  Created by Chris Wagner on 5/15/12.
//

#import "Holiday.h"
#import "NSManagedObject+JSON.h"
#import "SDSyncEngine.h"

@implementation Holiday

@dynamic objectId;
@dynamic date;
@dynamic details;
@dynamic image;
@dynamic name;
@dynamic observedBy;
@dynamic wikipediaLink;
@dynamic createdAt;
@dynamic updatedAt;
@dynamic syncStatus;

- (NSDictionary *)JSONToCreateObjectOnServer {
    NSDictionary *date = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"Date", @"__type",
                          [[SDSyncEngine sharedEngine] dateStringForAPIUsingDate:self.date], @"iso" , nil];
    
    NSDictionary *jsonDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    self.name, @"name",
                                    self.details, @"details",
                                    self.wikipediaLink, @"wikipediaLink",
                                    date, @"date", nil];
    return jsonDictionary;
}

@end
