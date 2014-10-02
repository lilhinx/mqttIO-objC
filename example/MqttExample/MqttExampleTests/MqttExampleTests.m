// Copyright (c) 2011, 2013, 2lemetry LLC
//
// All rights reserved. This program and the accompanying materials
// are made available under the terms of the Eclipse Public License v1.0
// and Eclipse Distribution License v. 1.0 which accompanies this distribution.
// The Eclipse Public License is available at http://www.eclipse.org/legal/epl-v10.html
// and the Eclipse Distribution License is available at
// http://www.eclipse.org/org/documents/edl-v10.php.
//
// Contributors:
//    Kyle Roche - initial API and implementation and/or initial documentation
//    Chris Hinkle - Objective-C modernization

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
