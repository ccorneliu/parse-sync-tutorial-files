//
//  NSManagedObject+JSON.h
//  SignificantDates
//
//  Created by Corneliu Chitanu on 30/04/14.
//
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (JSON)

- (NSDictionary *)JSONToCreateObjectOnServer;
- (NSString *)dateStringForAPIUsingDate:(NSDate *)date;

@end
