//
//  CCParseAPIClient.h
//  ParseCoreDataSyncTutorial
//
//  Created by Corneliu Chitanu on 28/04/14.
//  Copyright (c) 2014 Chitanu. All rights reserved.
//

#import "AFHTTPRequestOperationManager.h"
#import "CWLSynthesizeSingleton.h"

typedef void (^SuccessBlockType)(AFHTTPRequestOperation *operation, id responseObject);
typedef void (^FailureBlockType)(AFHTTPRequestOperation *operation, NSError *error);

@interface SDAFParseAPIClient : AFHTTPRequestOperationManager

CWL_DECLARE_SINGLETON_FOR_CLASS(SDAFParseAPIClient)

- (AFHTTPRequestOperation *)GETRequestForClass:(NSString *)className
                                    parameters:(NSDictionary *)parameters
                                       success:(SuccessBlockType)success
                                       failure:(FailureBlockType)failure;

- (AFHTTPRequestOperation *)GETRequestForAllRecordsOfClass:(NSString *)className
                                          updatedAfterDate:(NSDate *)updatedDate
                                                   success:(SuccessBlockType)success
                                                   failure:(FailureBlockType)failure;

- (AFHTTPRequestOperation *)POSTRequestForClass:(NSString *)className
                                     parameters:(NSDictionary *)parameters
                                        success:(SuccessBlockType)success
                                        failure:(FailureBlockType)failure;

- (AFHTTPRequestOperation *)DELETERequestForClass:(NSString *)className
                                  forObjectWithId:(NSString *)objectId
                                          success:(SuccessBlockType)success
                                          failure:(FailureBlockType)failure;

@end
