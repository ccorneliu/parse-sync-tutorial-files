//
//  CCParseAPIClient.m
//  ParseCoreDataSyncTutorial
//
//  Created by Corneliu Chitanu on 28/04/14.
//  Copyright (c) 2014 Chitanu. All rights reserved.
//

#import "SDAFParseAPIClient.h"

static NSString * const kSDFParseAPIBaseURLString = @"https://api.parse.com/1/";

#warning Set Your Application ID and API Key
static NSString * const kSDFParseAPIApplicationId = @"YOUR_APP_ID";
static NSString * const kSDFParseAPIKey = @"YOUR_API_KEY";

@implementation SDAFParseAPIClient

+ (instancetype)sharedSDAFParseAPIClient {
    static SDAFParseAPIClient *sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedClient = [[SDAFParseAPIClient alloc] initWithBaseURL:[NSURL URLWithString:kSDFParseAPIBaseURLString]];
    });
    
    return sharedClient;
}

-(instancetype)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (self) {
        AFJSONRequestSerializer *requestSerializer = [[AFJSONRequestSerializer alloc] init];
        [requestSerializer setValue:kSDFParseAPIApplicationId forHTTPHeaderField:@"X-Parse-Application-Id"];
        [requestSerializer setValue:kSDFParseAPIKey forHTTPHeaderField:@"X-Parse-REST-API-Key"];
        [self setRequestSerializer:requestSerializer];
        [self setResponseSerializer:[AFJSONResponseSerializer serializer]];
    }
    
    return self;
}

- (AFHTTPRequestOperation *)GETRequestForClass:(NSString *)className
                                    parameters:(NSDictionary *)parameters
                                       success:(SuccessBlockType)success
                                       failure:(FailureBlockType)failure {
    
    AFHTTPRequestOperation *operation = [self GET:[NSString stringWithFormat:@"classes/%@", className] parameters:parameters success:success failure:failure];
    return operation;
}

- (AFHTTPRequestOperation *)GETRequestForAllRecordsOfClass:(NSString *)className
                                          updatedAfterDate:(NSDate *)updatedDate
                                                   success:(SuccessBlockType)success
                                                   failure:(FailureBlockType)failure {
    AFHTTPRequestOperation *operation = nil;
    NSDictionary *parameters = nil;
    if (updatedDate) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.'999Z'"];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
        
        NSString *jsonString = [NSString
                                stringWithFormat:@"{\"updatedAt\":{\"$gte\":{\"__type\":\"Date\",\"iso\":\"%@\"}}}",
                                [dateFormatter stringFromDate:updatedDate]];
        
        parameters = [NSDictionary dictionaryWithObject:jsonString forKey:@"where"];
    }
    
    operation = [self GETRequestForClass:className parameters:parameters success:success failure:failure];
    return operation;
}

- (AFHTTPRequestOperation *)POSTRequestForClass:(NSString *)className
                                     parameters:(NSDictionary *)parameters
                                        success:(SuccessBlockType)success
                                        failure:(FailureBlockType)failure {

    AFHTTPRequestOperation *operation = [self POST:[NSString stringWithFormat:@"classes/%@", className] parameters:parameters success:success failure:failure];
    return operation;
}

- (AFHTTPRequestOperation *)DELETERequestForClass:(NSString *)className
                                  forObjectWithId:(NSString *)objectId
                                          success:(SuccessBlockType)success
                                          failure:(FailureBlockType)failure {
    
    AFHTTPRequestOperation *operation = [self DELETE:[NSString stringWithFormat:@"classes/%@/%@", className, objectId]
                                          parameters:nil
                                             success:success
                                             failure:failure];
    
    return operation;
}

@end
