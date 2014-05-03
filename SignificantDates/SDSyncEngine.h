//
//  SDSyncEngine.h
//  SignificantDates
//
//  Created by Corneliu Chitanu on 29/04/14.
//
//

#import <Foundation/Foundation.h>

typedef enum {
    SDObjectSynced = 0,
    SDObjectCreated,
    SDObjectDeleted,
} SDObjectSyncStatus;

@interface SDSyncEngine : NSObject

@property (atomic, readonly) BOOL syncInProgress;

+ (SDSyncEngine *)sharedEngine;

- (void)registerNSManagedObjectClassToSync:(Class)aClass;
- (void)startSync;

- (NSString *)dateStringForAPIUsingDate:(NSDate *)date;

@end
