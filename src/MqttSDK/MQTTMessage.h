//
// MQTTMessage.h
// MQtt Client
// 
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
// 

#import <Foundation/Foundation.h>

typedef enum {
    MQTTUnknown,
    MQTTMessageTypeConnect,
    MQTTMessageTypeConnack,
    MQTTMessageTypePublish,
    MQTTMessageTypePuback,
    MQTTMessageTypePubrec,
    MQTTMessageTypePubrel,
    MQTTMessageTypePubcomp,
    MQTTMessageTypeSubscribe,
    MQTTMessageTypeSuback,
    MQTTMessageTypeUnsubscribe,
    MQTTMessageTypeUnsuback,
    MQTTMessageTypePingreq,
    MQTTMessageTypePingresp,
    MQTTMessageTypeDisconnect
} MQTTMessageType;

@interface MQTTMessage : NSObject

@property (nonatomic) MQTTMessageType type;
@property (nonatomic) UInt8 qos;
@property (nonatomic) BOOL retainFlag;
@property (nonatomic,getter=isDuplicate) BOOL dupFlag;
@property (nonatomic,strong) NSData * data;

- (id)initWithType:(MQTTMessageType)aType;
- (id)initWithType:(MQTTMessageType)aType data:(NSData*)aData;
- (id)initWithType:(MQTTMessageType)aType qos:(UInt8)aQos data:(NSData*)aData;
- (id)initWithType:(MQTTMessageType)aType qos:(UInt8)aQos retainFlag:(BOOL)aRetainFlag dupFlag:(BOOL)aDupFlag data:(NSData*)aData;


+ (instancetype)connectMessageWithClientId:(NSString*)clientId userName:(NSString*)userName password:(NSString*)password keepAlive:(NSInteger)keeplive cleanSession:(BOOL)cleanSessionFlag;
+ (instancetype)connectMessageWithClientId:(NSString*)clientId userName:(NSString*)userName password:(NSString*)password keepAlive:(NSInteger)keeplive cleanSession:(BOOL)cleanSessionFlag willTopic:(NSString*)willTopic willMsg:(NSData*)willData willQoS:(UInt8)willQoS willRetain:(BOOL)willRetainFlag;

+ (instancetype)pingreqMessage;
+ (instancetype)subscribeMessageWithMessageId:(UInt16)msgId topic:(NSString*)topic qos:(UInt8)qos;
+ (instancetype)unsubscribeMessageWithMessageId:(UInt16)msgId topic:(NSString*)topic;
+ (instancetype)publishMessageWithData:(NSData*)payload onTopic:(NSString*)theTopic retainFlag:(BOOL)retain;
+ (instancetype)publishMessageWithData:(NSData*)payload onTopic:(NSString*)topic qos:(UInt8)qosLevel msgId:(UInt16)msgId retainFlag:(BOOL)retain dupFlag:(BOOL)dup;
+ (instancetype)pubackMessageWithMessageId:(UInt16)msgId;
+ (instancetype)pubrecMessageWithMessageId:(UInt16)msgId;
+ (instancetype)pubrelMessageWithMessageId:(UInt16)msgId;
+ (instancetype)pubcompMessageWithMessageId:(UInt16)msgId;

@end


