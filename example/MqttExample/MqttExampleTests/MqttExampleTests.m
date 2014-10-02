//
//  MqttExampleTests.m
//  MqttExampleTests
//
//  Created by Chris Hinkle on 10/1/14.
//
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "MQTTSession.h"

@interface MqttExampleTests : XCTestCase<MQTTSessionDelegate>


@property (nonatomic,strong) MQTTSession* session;

@end

@implementation MqttExampleTests

- (void)setUp
{
    [super setUp];
    self.session = [[MQTTSession alloc] initWithClientId:@"tarst" userName:@"" password:@""];
}


- (void)session:(MQTTSession *)session handleEvent:(MQTTSessionEvent)eventCode
{
    
}

- (void)session:(MQTTSession *)session newMessage:(NSData *)data onTopic:(NSString *)topic
{
    
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    XCTAssert(YES, @"Pass");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
