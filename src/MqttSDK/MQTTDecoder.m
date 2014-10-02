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

#import "MQTTDecoder.h"

@interface MQTTDecoder( )<NSStreamDelegate>

- (void)delegateHandleEvent:(MQTTDecoderEvent)event;
- (void)delegateNewMessage:(MQTTMessage*)message;


@property (nonatomic,strong) NSInputStream* stream;
@property (nonatomic,strong) NSRunLoop* runLoop;
@property (nonatomic,strong) NSString* runLoopMode;
@property (nonatomic) UInt8 header;
@property (nonatomic) UInt32 length;
@property (nonatomic) UInt32 lengthMultiplier;
@property (nonatomic,strong) NSMutableData* dataBuffer;

- (void)stream:(NSStream*)sender handleEvent:(NSStreamEvent)eventCode;

@end

@implementation MQTTDecoder

- (void)dealloc
{
    [self close];
}

- (void)delegateHandleEvent:(MQTTDecoderEvent)event
{
    id<MQTTDecoderDelegate> delegate = self.delegate;
    if( delegate && [delegate respondsToSelector:@selector(decoder:handleEvent:)] )
    {
        [delegate decoder:self handleEvent:event];
    }
}

- (void)delegateNewMessage:(MQTTMessage*)message
{
    id<MQTTDecoderDelegate> delegate = self.delegate;
    if( delegate && [delegate respondsToSelector:@selector(decoder:newMessage:)] )
    {
        [delegate decoder:self newMessage:message];
    }
}

- (id)initWithStream:(NSInputStream*)aStream runLoop:(NSRunLoop*)aRunLoop runLoopMode:(NSString*)aMode
{
    self = [super init];
    if( self )
    {
        self.status = MQTTDecoderStatusInitializing;
        self.stream = aStream;
        self.stream.delegate = self;
        self.runLoop = aRunLoop;
        self.runLoopMode = aMode;
    }
    return self;
}



- (void)open
{
    self.stream.delegate = self;
    [self.stream scheduleInRunLoop:self.runLoop forMode:self.runLoopMode];
    [self.stream open];
}

- (void)close
{
    self.stream.delegate = nil;
    [self.stream close];
    [self.stream removeFromRunLoop:self.runLoop forMode:self.runLoopMode];
    self.stream = nil;
}

- (void)stream:(NSStream*)sender handleEvent:(NSStreamEvent)eventCode
{
    NSInputStream* stream = self.stream;
    
    if( stream == nil )
    {
        return;
    }
    
    switch( eventCode )
    {
        case NSStreamEventOpenCompleted:
            self.status = MQTTDecoderStatusDecodingHeader;
            break;
        case NSStreamEventHasBytesAvailable:
            if( self.status == MQTTDecoderStatusDecodingHeader )
            {
                NSInteger n = [self.stream read:&_header maxLength:1];
                if( n == -1 )
                {
                    self.status = MQTTDecoderStatusConnectionError;
                    [self delegateHandleEvent:MQTTDecoderEventConnectionError];
                }
                else if( n == 1 )
                {
                    _length = 0;
                    _lengthMultiplier = 1;
                    self.status = MQTTDecoderStatusDecodingLength;
                }
            }
            while( self.status == MQTTDecoderStatusDecodingLength )
            {
                UInt8 digit;
                NSInteger n = [stream read:&digit maxLength:1];
                if( n == -1 )
                {
                    self.status = MQTTDecoderStatusConnectionError;
                    [self delegateHandleEvent:MQTTDecoderEventConnectionError];
                    break;
                }
                else if( n == 0 )
                {
                    break;
                }
                _length += (digit & 0x7f) * _lengthMultiplier;
                if( (digit & 0x80) == 0x00 )
                {
                    self.dataBuffer = [NSMutableData dataWithCapacity:_length];
                    self.status = MQTTDecoderStatusDecodingData;
                }
                else
                {
                    _lengthMultiplier *= 128;
                }
            }
            if( self.status == MQTTDecoderStatusDecodingData )
            {
                if( _length > 0 )
                {
                    NSInteger n, toRead;
                    UInt8 buffer[768];
                    toRead = _length - [self.dataBuffer length];
                    if( toRead > sizeof buffer )
                    {
                        toRead = sizeof buffer;
                    }
                    n = [stream read:buffer maxLength:toRead];
                    if( n == -1 )
                    {
                        self.status = MQTTDecoderStatusConnectionError;
                        [self delegateHandleEvent:MQTTDecoderEventConnectionError];
                    }
                    else {
                        [self.dataBuffer appendBytes:buffer length:n];
                    }
                }
                if( [self.dataBuffer length] == _length )
                {
                    MQTTMessage* msg = nil;
                    UInt8 type, qos;
                    BOOL isDuplicate, retainFlag;
                    type = ( _header >> 4 ) & 0x0f;
                    isDuplicate = NO;
                    if( ( _header & 0x08 ) == 0x08 )
                    {
                        isDuplicate = YES;
                    }
                    // XXX qos > 2
                    qos = ( _header >> 1 ) & 0x03;
                    retainFlag = NO;
                    if( ( _header & 0x01 ) == 0x01 )
                    {
                        retainFlag = YES;
                    }
                    msg = [[MQTTMessage alloc] initWithType:type
                                                        qos:qos
                                                 retainFlag:retainFlag
                                                    dupFlag:isDuplicate
                                                       data:[NSData dataWithData:self.dataBuffer]];
                    [self delegateNewMessage:msg];
                    self.dataBuffer = nil;
                    self.status = MQTTDecoderStatusDecodingHeader;
                }
            }
            break;
        case NSStreamEventEndEncountered:
            self.status = MQTTDecoderStatusConnectionClosed;
            [self delegateHandleEvent:MQTTDecoderEventConnectionClosed];
            break;
        case NSStreamEventErrorOccurred:
            self.status = MQTTDecoderStatusConnectionError;
            [self delegateHandleEvent:MQTTDecoderEventConnectionError];
            break;
        default:
            NSLog(@"unhandled event code");
            break;
    }
}

@end
