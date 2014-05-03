//
//  NSManagedObject+JSON.m
//  SignificantDates
//
//  Created by Corneliu Chitanu on 30/04/14.
//
//

#import "NSManagedObject+JSON.h"

@implementation NSManagedObject (JSON)

- (NSDictionary *)JSONToCreateObjectOnServer {
    @throw [NSException exceptionWithName:@"JSONStringToCreateObjectOnServer Not Overridden" reason:@"Must override JSONStringToCreateObjectOnServer on NSManagedObject class" userInfo:nil];
    return nil;
}

@end
