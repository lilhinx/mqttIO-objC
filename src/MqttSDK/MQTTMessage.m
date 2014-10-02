//
// MQTTMessage.m
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

#import "MQTTMessage.h"

#define MQTIsdp @"MQIsdp"

@interface NSMutableData( MQTT )

- (void)appendByte:(UInt8)byte;
- (void)appendUInt16BigEndian:(UInt16)val;
- (void)appendMQTTString:(NSString*)s;

@end

@implementation NSMutableData( MQTT )

- (void)appendByte:(UInt8)byte
{
    [self appendBytes:&byte length:1];
}

- (void)appendUInt16BigEndian:(UInt16)val
{
    [self appendByte:val / 256];
    [self appendByte:val % 256];
}

- (void)appendMQTTString:(NSString*)string
{
    UInt8 buf[2];
    const char* utf8String = [string UTF8String];
    NSInteger strLen = strlen(utf8String);
    buf[0] = strLen / 256;
    buf[1] = strLen % 256;
    [self appendBytes:buf length:2];
    [self appendBytes:utf8String length:strLen];
}

@end

@implementation MQTTMessage


- (id)initWithType:(MQTTMessageType)aType
{
    self = [super init];
    if( self )
    {
        self.type = aType;
        self.data = nil;
    }
    return self;
}

- (id)initWithType:(MQTTMessageType)aType data:(NSData*)aData
{
    self = [super init];
    if( self )
    {
        self.type = aType;
        self.data = aData;
    }
    return self;
}

- (id)initWithType:(MQTTMessageType)aType qos:(UInt8)aQos data:(NSData*)aData
{
    self = [super init];
    if( self )
    {
        self.type = aType;
        self.qos = aQos;
        self.data = aData;
    }
    return self;
}

- (id)initWithType:(MQTTMessageType)aType qos:(UInt8)aQos retainFlag:(BOOL)aRetainFlag dupFlag:(BOOL)aDupFlag data:(NSData*)aData
{
    self = [super init];
    if( self )
    {
        self.type = aType;
        self.qos = aQos;
        self.retainFlag = aRetainFlag;
        self.dupFlag = aDupFlag;
        self.data = aData;
    }
    return self;
}

+ (instancetype)connectMessageWithClientId:(NSString*)clientId userName:(NSString*)userName password:(NSString*)password keepAlive:(NSInteger)keepAlive cleanSession:(BOOL)cleanSessionFlag
{
    MQTTMessage* msg = nil;
    UInt8 flags = 0x00;
    
    if( cleanSessionFlag )
    {
        flags |= 0x02;
    }
    
    if( [userName length] > 0 )
    {
        flags |= 0x80;
        if( [password length] > 0 )
        {
            flags |= 0x40;
        }
    }
    
    NSMutableData* data = [NSMutableData data];
    [data appendMQTTString:MQTIsdp];
    [data appendByte:3];
    [data appendByte:flags];
    [data appendUInt16BigEndian:keepAlive];
    [data appendMQTTString:clientId];
    if( [userName length] > 0 )
    {
        [data appendMQTTString:userName];
        if( [password length] > 0 )
        {
            [data appendMQTTString:password];
        }
    }
    
    msg = [[MQTTMessage alloc] initWithType:MQTTMessageTypeConnect data:data];
    return msg;
}

+ (instancetype)connectMessageWithClientId:(NSString*)clientId userName:(NSString*)userName password:(NSString*)password keepAlive:(NSInteger)keepAlive cleanSession:(BOOL)cleanSessionFlag willTopic:(NSString*)willTopic willMsg:(NSData*)willMsg willQoS:(UInt8)willQoS willRetain:(BOOL)willRetainFlag
{
    UInt8 flags = 0x04 | ( willQoS << 4 & 0x18 );
    
    if( willRetainFlag )
    {
        flags |= 0x20;
    }
    
    if( cleanSessionFlag )
    {
        flags |= 0x02;
    }
    
    if( [userName length] > 0 )
    {
        flags |= 0x80;
        if( [password length] > 0 )
        {
            flags |= 0x40;
        }
    }
    
    NSMutableData* data = [NSMutableData data];
    [data appendMQTTString:MQTIsdp];
    [data appendByte:3];
    [data appendByte:flags];
    [data appendUInt16BigEndian:keepAlive];
    [data appendMQTTString:clientId];
    [data appendMQTTString:willTopic];
    [data appendUInt16BigEndian:[willMsg length]];
    [data appendData:willMsg];
    if( [userName length] > 0 )
    {
        [data appendMQTTString:userName];
        if( [password length] > 0 )
        {
            [data appendMQTTString:password];
        }
    }
    
    MQTTMessage* msg = [[MQTTMessage alloc] initWithType:MQTTMessageTypeConnect data:data];
    return msg;
}

+ (instancetype)pingreqMessage
{
    return [[MQTTMessage alloc] initWithType:MQTTMessageTypePingreq];
}

+ (instancetype)subscribeMessageWithMessageId:(UInt16)msgId topic:(NSString*)topic qos:(UInt8)qos
{
    NSMutableData* data = [NSMutableData data];
    [data appendUInt16BigEndian:msgId];
    [data appendMQTTString:topic];
    [data appendByte:qos];
    MQTTMessage* msg = [[MQTTMessage alloc] initWithType:MQTTMessageTypeSubscribe qos:1 data:data];
    return msg;
}

+ (instancetype)unsubscribeMessageWithMessageId:(UInt16)msgId topic:(NSString*)topic
{
    NSMutableData* data = [NSMutableData data];
    [data appendUInt16BigEndian:msgId];
    [data appendMQTTString:topic];
    MQTTMessage* msg = [[MQTTMessage alloc] initWithType:MQTTMessageTypeUnsubscribe qos:1 data:data];
    return msg;
}

+ (instancetype)publishMessageWithData:(NSData*)payload onTopic:(NSString*)topic retainFlag:(BOOL)retain
{
    NSMutableData* data = [NSMutableData data];
    [data appendMQTTString:topic];
    [data appendData:payload];
    MQTTMessage* msg = [[MQTTMessage alloc] initWithType:MQTTMessageTypePublish qos:0 retainFlag:retain dupFlag:NO data:data];
    return msg;
}

+ (instancetype)publishMessageWithData:(NSData*)payload onTopic:(NSString*)topic qos:(UInt8)qosLevel msgId:(UInt16)msgId retainFlag:(BOOL)retain dupFlag:(BOOL)dup
{
    NSMutableData* data = [NSMutableData data];
    [data appendMQTTString:topic];
    [data appendUInt16BigEndian:msgId];
    [data appendData:payload];
    MQTTMessage* msg = [[MQTTMessage alloc] initWithType:MQTTMessageTypePublish qos:qosLevel retainFlag:retain dupFlag:dup data:data];
    return msg;
}

+ (instancetype)pubackMessageWithMessageId:(UInt16)msgId
{
    NSMutableData* data = [NSMutableData data];
    [data appendUInt16BigEndian:msgId];
    return [[MQTTMessage alloc] initWithType:MQTTMessageTypePuback data:data];
}

+ (instancetype)pubrecMessageWithMessageId:(UInt16)msgId
{
    NSMutableData* data = [NSMutableData data];
    [data appendUInt16BigEndian:msgId];
    return [[MQTTMessage alloc] initWithType:MQTTMessageTypePubrec data:data];
}

+ (instancetype)pubrelMessageWithMessageId:(UInt16)msgId
{
    NSMutableData* data = [NSMutableData data];
    [data appendUInt16BigEndian:msgId];
    return [[MQTTMessage alloc] initWithType:MQTTMessageTypePubrel data:data];
}

+ (instancetype)pubcompMessageWithMessageId:(UInt16)msgId
{
    NSMutableData* data = [NSMutableData data];
    [data appendUInt16BigEndian:msgId];
    return [[MQTTMessage alloc] initWithType:MQTTMessageTypePubcomp data:data];
}


@end


