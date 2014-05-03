//
//  Birthday.m
//  SignificantDates
//
//  Created by Chris Wagner on 6/11/12.
//

#import "Birthday.h"
#import "NSManagedObject+JSON.h"
#import "SDSyncEngine.h"

@implementation Birthday

@dynamic objectId;
@dynamic name;
@dynamic date;
@dynamic giftIdeas;
@dynamic facebook;
@dynamic createdAt;
@dynamic updatedAt;
@dynamic image;
@dynamic syncStatus;

- (NSDictionary *)JSONToCreateObjectOnServer {
    NSDictionary *date = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"Date", @"__type",
                          [[SDSyncEngine sharedEngine] dateStringForAPIUsingDate:self.date], @"iso" , nil];
    
    NSDictionary *jsonDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    self.name, @"name",
                                    self.giftIdeas, @"giftIdeas",
                                    self.facebook, @"facebook",
                                    date, @"date", nil];
    return jsonDictionary;
}

@end
