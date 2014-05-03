//
//  Birthday.h
//  SignificantDates
//
//  Created by Chris Wagner on 6/11/12.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Birthday : NSManagedObject

@property (nonatomic, retain) NSString * objectId;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSDate * date;
@property (nonatomic, retain) NSString * giftIdeas;
@property (nonatomic, retain) NSString * facebook;
@property (nonatomic, retain) NSDate * createdAt;
@property (nonatomic, retain) NSDate * updatedAt;
@property (nonatomic, retain) NSData * image;
@property (nonatomic, retain) NSNumber * syncStatus;

@end
