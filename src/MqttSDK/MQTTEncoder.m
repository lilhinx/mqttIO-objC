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

#import "MQTTEncoder.h"

@interface MQTTEncoder( )<NSStreamDelegate>

@property (nonatomic,strong) NSOutputStream* stream;
@property (nonatomic,strong) NSRunLoop* runLoop;
@property (nonatomic,strong) NSString* runLoopMode;
@property (nonatomic,strong) NSMutableData* buffer;
@property (nonatomic) NSInteger byteIndex;

- (void)stream:(NSStream*)sender handleEvent:(NSStreamEvent)eventCode;

- (void)delegateHandleEvent:(MQTTEncoderEvent)event;

@end

@implementation MQTTEncoder

- (void)dealloc
{
    [self close];
}

- (void)delegateHandleEvent:(MQTTEncoderEvent)event
{
    id<MQTTEncoderDelegate> delegate = self.delegate;
    if( delegate && [delegate respondsToSelector:@selector(encoder:handleEvent:)] )
    {
        [delegate encoder:self handleEvent:event];
    }
}

- (id)initWithStream:(NSOutputStream*)aStream runLoop:(NSRunLoop*)aRunLoop runLoopMode:(NSString*)aMode
{
    self = [super init];
    if( self )
    {
        self.status = MQTTEncoderStatusInitializing;
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
    [self.stream close];
    self.stream.delegate = nil;
    [self.stream removeFromRunLoop:self.runLoop forMode:self.runLoopMode];
    self.stream = nil;
}

- (void)stream:(NSStream*)sender handleEvent:(NSStreamEvent)eventCode
{
    NSOutputStream* stream = self.stream;
    if( stream == nil )
    {
        return;
    }
    
    assert( sender == stream );
    switch( eventCode )
    {
        case NSStreamEventOpenCompleted:
            break;
        case NSStreamEventHasSpaceAvailable:
            if( self.status == MQTTEncoderStatusInitializing )
            {
                self.status = MQTTEncoderStatusReady;
                [self delegateHandleEvent:MQTTEncoderEventReady];
            }
            else if( self.status == MQTTEncoderStatusReady )
            {
                [self delegateHandleEvent:MQTTEncoderEventReady];
            }
            else if( self.status == MQTTEncoderStatusSending )
            {
                UInt8* ptr;
                NSInteger n, length;
                
                ptr = (UInt8*) [self.buffer bytes] + _byteIndex;
                // Number of bytes pending for transfer
                length = [self.buffer length] - _byteIndex;
                n = [stream write:ptr maxLength:length];
                if( n == -1 )
                {
                    self.status = MQTTEncoderStatusError;
                    [self delegateHandleEvent:MQTTEncoderEventErrorOccurred];
                }
                else if( n < length )
                {
                    _byteIndex += n;
                }
                else
                {
                    self.buffer = nil;
                    _byteIndex = 0;
                    self.status = MQTTEncoderStatusReady;
                }
            }
            break;
        case NSStreamEventErrorOccurred:
        case NSStreamEventEndEncountered:
            if( self.status != MQTTEncoderStatusError )
            {
                self.status = MQTTEncoderStatusError;
                [self delegateHandleEvent:MQTTEncoderEventErrorOccurred];
            }
            break;
        default:
            NSLog( @"Oops, event code not handled" );
            break;
    }
}

- (void)encodeMessage:(MQTTMessage*)msg
{
    UInt8 header;
    NSInteger n, length;
    
    if( self.status != MQTTEncoderStatusReady )
    {
        NSLog(@"Encoder not ready");
        return;
    }
    
    assert( self.buffer == nil );
    assert( _byteIndex == 0 );
    
    self.buffer = [[NSMutableData alloc] init];
    
    // encode fixed header
    header = [msg type] << 4;
    if( [msg isDuplicate] )
    {
        header |= 0x08;
    }
    header |= [msg qos] << 1;
    if( [msg retainFlag] )
    {
        header |= 0x01;
    }
    [self.buffer appendBytes:&header length:1];
    
    // encode remaining length
    length = [[msg data] length];
    do
    {
        UInt8 digit = length % 128;
        length /= 128;
        if( length > 0 )
        {
            digit |= 0x80;
        }
        [self.buffer appendBytes:&digit length:1];
    }
    while( length > 0 );
    
    // encode message data
    if( [msg data] != NULL )
    {
        [self.buffer appendData:[msg data]];
    }
    
    n = [self.stream write:[self.buffer bytes] maxLength:[self.buffer length]];
    if( n == -1 )
    {
        self.status = MQTTEncoderStatusError;
        [self delegateHandleEvent:MQTTEncoderEventErrorOccurred];
    }
    else if( n < [self.buffer length] )
    {
        _byteIndex += n;
        self.status = MQTTEncoderStatusSending;
    }
    else
    {
        self.buffer = nil;
        // XXX [delegate encoder:self handleEvent:MQTTEncoderEventReady];
    }
}

@end
