//
// MQTTSession.m
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

#import "MQTTSession.h"
#import "MQttTxFlow.h"

#define DEFAULT_KEEP_ALIVE 60

@interface MQTTSession( )<MQTTDecoderDelegate,MQTTEncoderDelegate>


@property (atomic,strong) NSMutableArray* queue;
@property (atomic,strong) NSMutableArray* timerRing;
@property (nonatomic,strong) NSString* clientId;
@property (nonatomic) UInt16 keepAliveInterval;
@property (nonatomic) BOOL cleanSessionFlag;
@property (nonatomic,strong) MQTTMessage* connectMessage;

@property (nonatomic,strong) NSRunLoop* runLoop;
@property (nonatomic,strong) NSString* runLoopMode;
@property (nonatomic,strong) NSTimer* timer;
@property (nonatomic) NSInteger idleTimer;
@property (nonatomic,strong) MQTTEncoder* encoder;
@property (nonatomic,strong) MQTTDecoder* decoder;
@property (nonatomic) UInt16 txMsgId;

@property (nonatomic,strong) NSMutableDictionary* txFlows;
@property (nonatomic,strong) NSMutableDictionary* rxFlows;
@property (nonatomic) unsigned int ticks;

- (void)newMessage:(MQTTMessage*)msg;
- (void)error:(MQTTSessionEvent)event;
- (void)handlePublish:(MQTTMessage*)msg;
- (void)handlePuback:(MQTTMessage*)msg;
- (void)handlePubrec:(MQTTMessage*)msg;
- (void)handlePubrel:(MQTTMessage*)msg;
- (void)handlePubcomp:(MQTTMessage*)msg;
- (void)send:(MQTTMessage*)msg;
- (UInt16)nextMsgId;



- (void)encoder:(MQTTEncoder*)sender handleEvent:(MQTTEncoderEvent)eventCode;
- (void)decoder:(MQTTDecoder*)sender handleEvent:(MQTTDecoderEvent)eventCode;
- (void)decoder:(MQTTDecoder*)sender newMessage:(MQTTMessage*)msg;


- (void)timerHandler:(NSTimer*)theTimer;

- (void)delegateHandleEvent:(MQTTSessionEvent)event;
- (void)delegateHandleMessage:(NSData*)message onTopic:(NSString*)topic;


@end

@implementation MQTTSession

- (void)delegateHandleEvent:(MQTTSessionEvent)event
{
    id<MQTTSessionDelegate> delegate = self.delegate;
    if( delegate && [delegate respondsToSelector:@selector(session:handleEvent:)] )
    {
        [delegate session:self handleEvent:MQTTSessionEventConnected];
    }
}

- (void)delegateHandleMessage:(NSData*)message onTopic:(NSString*)topic
{
    if( message == nil )
    {
        return;
    }
    
    
    id<MQTTSessionDelegate> delegate = self.delegate;
    if( delegate && [delegate respondsToSelector:@selector(session:newMessage:onTopic:)] )
    {
        [delegate session:self newMessage:message onTopic:topic];
    }
}


- (id)initWithClientId:(NSString*)theClientId
{
    return [self initWithClientId:theClientId userName:@"" password:@""];
}

- (id)initWithClientId:(NSString*)theClientId userName:(NSString*)theUserName password:(NSString*)thePassword
{
    return [self initWithClientId:theClientId userName:theUserName password:thePassword keepAlive:DEFAULT_KEEP_ALIVE cleanSession:YES];
}

- (id)initWithClientId:(NSString*)theClientId runLoop:(NSRunLoop*)theRunLoop forMode:(NSString*)theRunLoopMode
{
    return [self initWithClientId:theClientId userName:@"" password:@"" runLoop:theRunLoop forMode:theRunLoopMode];
}

- (id)initWithClientId:(NSString*)theClientId userName:(NSString*)theUserName password:(NSString*)thePassword runLoop:(NSRunLoop*)theRunLoop forMode:(NSString*)theRunLoopMode
{
    return [self initWithClientId:theClientId userName:theUserName password:thePassword keepAlive:DEFAULT_KEEP_ALIVE cleanSession:YES runLoop:theRunLoop forMode:theRunLoopMode];
}

- (id)initWithClientId:(NSString*)theClientId userName:(NSString*)theUserName password:(NSString*)thePassword keepAlive:(UInt16)theKeepAliveInterval cleanSession:(BOOL)theCleanSessionFlag
{
    return [self initWithClientId:theClientId userName:theUserName password:thePassword keepAlive:theKeepAliveInterval cleanSession:theCleanSessionFlag runLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (id)initWithClientId:(NSString*)theClientId userName:(NSString*)theUserName password:(NSString*)thePassword keepAlive:(UInt16)theKeepAliveInterval cleanSession:(BOOL)theCleanSessionFlag runLoop:(NSRunLoop*)theRunLoop forMode:(NSString*)theRunLoopMode
{
    MQTTMessage *msg = [MQTTMessage connectMessageWithClientId:theClientId userName:theUserName password:thePassword keepAlive:theKeepAliveInterval cleanSession:theCleanSessionFlag];
    return [self initWithClientId:theClientId keepAlive:theKeepAliveInterval connectMessage:msg runLoop:theRunLoop forMode:theRunLoopMode];
}

- (id)initWithClientId:(NSString*)theClientId userName:(NSString*)theUserName password:(NSString*)thePassword keepAlive:(UInt16)theKeepAliveInterval cleanSession:(BOOL)theCleanSessionFlag willTopic:(NSString*)willTopic willMsg:(NSData*)willMsg willQoS:(UInt8)willQoS willRetainFlag:(BOOL)willRetainFlag
{
    return [self initWithClientId:theClientId userName:theUserName password:thePassword keepAlive:theKeepAliveInterval cleanSession:theCleanSessionFlag willTopic:willTopic willMsg:willMsg willQoS:willQoS willRetainFlag:willRetainFlag runLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (id)initWithClientId:(NSString*)theClientId userName:(NSString*)theUserName password:(NSString*)thePassword keepAlive:(UInt16)theKeepAliveInterval cleanSession:(BOOL)theCleanSessionFlag willTopic:(NSString*)willTopic willMsg:(NSData*)willMsg willQoS:(UInt8)willQoS willRetainFlag:(BOOL)willRetainFlag runLoop:(NSRunLoop*)theRunLoop forMode:(NSString*)theRunLoopMode
{
    MQTTMessage* msg = [MQTTMessage connectMessageWithClientId:theClientId userName:theUserName password:thePassword keepAlive:theKeepAliveInterval cleanSession:theCleanSessionFlag willTopic:willTopic willMsg:willMsg willQoS:willQoS willRetain:willRetainFlag];
    return [self initWithClientId:theClientId keepAlive:theKeepAliveInterval connectMessage:msg runLoop:theRunLoop forMode:theRunLoopMode];
}

- (id)initWithClientId:(NSString*)theClientId keepAlive:(UInt16)theKeepAliveInterval connectMessage:(MQTTMessage*)theConnectMessage runLoop:(NSRunLoop*)theRunLoop forMode:(NSString*)theRunLoopMode
{
    self = [super init];
    if( self )
    {
        self.clientId = theClientId;
        self.keepAliveInterval = theKeepAliveInterval;
        self.connectMessage = theConnectMessage;
        self.runLoop = theRunLoop;
        self.runLoopMode = theRunLoopMode;
        
        self.queue = [NSMutableArray array];
        self.txMsgId = 1;
        self.txFlows = [[NSMutableDictionary alloc] init];
        self.rxFlows = [[NSMutableDictionary alloc] init];
        self.timerRing = [[NSMutableArray alloc] initWithCapacity:60];
        int i;
        for( i = 0; i < 60; i++ )
        {
            [self.timerRing addObject:[NSMutableSet set]];
        }
        self.ticks = 0;
    }
    return self;
}

- (void)dealloc
{
    [self.timer invalidate];
    self.timer = nil;
    
}

- (void)close
{
    [self.encoder close];
    [self.decoder close];
    self.encoder = nil;
    self.decoder = nil;
    [self.timer invalidate];
    self.timer = nil;
    [self error:MQTTSessionEventConnectionClosed];
}


- (void)connectToHost:(NSString*)ip port:(UInt32)port
{
    [self connectToHost:ip port:port usingSSL:NO];
}

- (void)connectToHost:(NSString*)ip port:(UInt32)port usingSSL:(BOOL)usingSSL
{
    self.status = MQTTSessionStatusCreated;

    CFReadStreamRef readStream = nil;
    CFWriteStreamRef writeStream = nil;

    CFStreamCreatePairWithSocketToHost( NULL, (__bridge CFStringRef)ip, port, &readStream, &writeStream );

    if( usingSSL )
    {
        const void *keys[] = { kCFStreamSSLLevel, kCFStreamSSLPeerName };
        const void *vals[] = { kCFStreamSocketSecurityLevelNegotiatedSSL, kCFNull };
        CFDictionaryRef sslSettings = CFDictionaryCreate( kCFAllocatorDefault, keys, vals, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks );
        CFReadStreamSetProperty( readStream, kCFStreamPropertySSLSettings, sslSettings );
        CFWriteStreamSetProperty( writeStream, kCFStreamPropertySSLSettings, sslSettings );

        CFRelease( sslSettings );
    }

    self.encoder = [[MQTTEncoder alloc] initWithStream:(__bridge NSOutputStream*)writeStream runLoop:self.runLoop runLoopMode:self.runLoopMode];
    self.encoder.delegate = self;
    self.decoder = [[MQTTDecoder alloc] initWithStream:(__bridge NSInputStream*)readStream runLoop:self.runLoop runLoopMode:self.runLoopMode];
    self.decoder.delegate = self;
    
    [self.encoder open];
    [self.decoder open];
}

- (void)subscribeTopic:(NSString*)theTopic
{
    [self subscribeToTopic:theTopic atLevel:0];
}

- (void)subscribeToTopic:(NSString*)topic atLevel:(UInt8)qosLevel
{
    [self send:[MQTTMessage subscribeMessageWithMessageId:[self nextMsgId] topic:topic qos:qosLevel]];
}

- (void)unsubscribeTopic:(NSString*)theTopic
{
    [self send:[MQTTMessage unsubscribeMessageWithMessageId:[self nextMsgId] topic:theTopic]];
}

- (void)publishData:(NSData*)data onTopic:(NSString*)topic
{
    [self publishDataAtMostOnce:data onTopic:topic];
}

- (void)publishDataAtMostOnce:(NSData*)data onTopic:(NSString*)topic
{
  [self publishDataAtMostOnce:data onTopic:topic retain:NO];
}

- (void)publishDataAtMostOnce:(NSData*)data onTopic:(NSString*)topic retain:(BOOL)retainFlag
{
    [self send:[MQTTMessage publishMessageWithData:data onTopic:topic retainFlag:retainFlag]];
}

- (void)publishDataAtLeastOnce:(NSData*)data onTopic:(NSString*)topic
{
    [self publishDataAtLeastOnce:data onTopic:topic retain:NO];
}

- (void)publishDataAtLeastOnce:(NSData*)data onTopic:(NSString*)topic retain:(BOOL)retainFlag
{
    UInt16 msgId = [self nextMsgId];
    MQTTMessage* msg = [MQTTMessage publishMessageWithData:data onTopic:topic qos:1 msgId:msgId retainFlag:retainFlag dupFlag:NO];
    MQttTxFlow* flow = [MQttTxFlow flowWithMsg:msg deadline:(_ticks + 60)];
    [self.txFlows setObject:flow forKey:[NSNumber numberWithUnsignedInt:msgId]];
    [[self.timerRing objectAtIndex:([flow deadline] % 60)] addObject:[NSNumber numberWithUnsignedInt:msgId]];
    [self send:msg];
}

- (void)publishDataExactlyOnce:(NSData*)data onTopic:(NSString*)topic
{
    [self publishDataExactlyOnce:data onTopic:topic retain:false];
}

- (void)publishDataExactlyOnce:(NSData*)data onTopic:(NSString*)topic retain:(BOOL)retainFlag
{
    UInt16 msgId = [self nextMsgId];
    MQTTMessage* msg = [MQTTMessage publishMessageWithData:data onTopic:topic qos:2 msgId:msgId retainFlag:retainFlag dupFlag:false];
    MQttTxFlow* flow = [MQttTxFlow flowWithMsg:msg deadline:(_ticks + 60)];
    [self.txFlows setObject:flow forKey:[NSNumber numberWithUnsignedInt:msgId]];
    [[self.timerRing objectAtIndex:([flow deadline] % 60)] addObject:[NSNumber numberWithUnsignedInt:msgId]];
    [self send:msg];
}

- (void)publishJson:(id)payload onTopic:(NSString*)theTopic
{
    NSError* error = nil;
    NSData* data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if( error != nil )
    {
        return;
    }
    [self publishData:data onTopic:theTopic];
}

- (void)timerHandler:(NSTimer*)theTimer
{
    self.idleTimer++;
    if( self.idleTimer >= self.keepAliveInterval )
    {
        if( [self.encoder status] == MQTTEncoderStatusReady )
        {
            //NSLog(@"sending PINGREQ");
            [self.encoder encodeMessage:[MQTTMessage pingreqMessage]];
            self.idleTimer = 0;
        }
    }
    _ticks++;
    NSEnumerator *e = [[self.timerRing objectAtIndex:(_ticks % 60)] objectEnumerator];
    id msgId;

    while( ( msgId = [e nextObject] ) )
    {
        MQttTxFlow* flow = [self.txFlows objectForKey:msgId];
        MQTTMessage *msg = [flow msg];
        [flow setDeadline:(_ticks + 60)];
        msg.dupFlag = YES;
        [self send:msg];
    }
}

- (void)encoder:(MQTTEncoder*)sender handleEvent:(MQTTEncoderEvent) eventCode
{
    if( sender == self.encoder )
    {
        switch( eventCode )
        {
            case MQTTEncoderEventReady:
            {
                switch( self.status )
                {
                    case MQTTSessionStatusCreated:
                        [sender encodeMessage:self.connectMessage];
                        self.status = MQTTSessionStatusConnecting;
                        break;
                    case MQTTSessionStatusConnecting:
                        break;
                    case MQTTSessionStatusConnected:
                        if( [self.queue count] > 0 )
                        {
                            MQTTMessage* msg = [self.queue objectAtIndex:0];
                            [self.queue removeObjectAtIndex:0];
                            [self.encoder encodeMessage:msg];
                        }
                        break;
                    case MQTTSessionStatusError:
                        break;
                }
                break;
            }
            case MQTTEncoderEventErrorOccurred:
                [self error:MQTTSessionEventConnectionError];
                break;
        }
    }
}

- (void)decoder:(MQTTDecoder*)sender handleEvent:(MQTTDecoderEvent)eventCode
{
    //NSLog(@"decoder:(MQTTDecoder*)sender handleEvent:(MQTTDecoderEvent)eventCode");
    if( sender == self.decoder )
    {
        MQTTSessionEvent event;
        switch( eventCode )
        {
            case MQTTDecoderEventConnectionClosed:
                event = MQTTSessionEventConnectionError;
                break;
            case MQTTDecoderEventConnectionError:
                event = MQTTSessionEventConnectionError;
                break;
            case MQTTDecoderEventProtocolError:
                event = MQTTSessionEventProtocolError;
                break;
        }
        [self error:event];
    }
}

- (void)decoder:(MQTTDecoder*)sender newMessage:(MQTTMessage*)msg
{
    if( sender == self.decoder )
    {
        switch( self.status )
        {
            case MQTTSessionStatusConnecting:
            {
                switch( [msg type] )
                {
                    case MQTTMessageTypeConnack:
                        if( [[msg data] length] != 2 )
                        {
                            [self error:MQTTSessionEventProtocolError];
                        }
                        else
                        {
                            const UInt8* bytes = [[msg data] bytes];
                            if( bytes[1] == 0 )
                            {
                                self.status = MQTTSessionStatusConnected;
                                self.timer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:1.0] interval:1.0 target:self selector:@selector(timerHandler:) userInfo:nil repeats:YES];
                                [self delegateHandleEvent:MQTTSessionEventConnected];
                                [self.runLoop addTimer:self.timer forMode:self.runLoopMode];
                            }
                            else
                            {
                                [self error:MQTTSessionEventConnectionRefused];
                            }
                        }
                        break;
                    default:
                        [self error:MQTTSessionEventProtocolError];
                        break;
                }
                break;
            }
            case MQTTSessionStatusConnected:
                [self newMessage:msg];
                break;
            default:
                break;
        }
    }
}

- (void)newMessage:(MQTTMessage*)msg
{
    switch( [msg type] )
    {
        case MQTTMessageTypePublish:
            [self handlePublish:msg];
            break;
        case MQTTMessageTypePuback:
            [self handlePuback:msg];
            break;
        case MQTTMessageTypePubrec:
            [self handlePubrec:msg];
            break;
        case MQTTMessageTypePubrel:
            [self handlePubrel:msg];
            break;
        case MQTTMessageTypePubcomp:
            [self handlePubcomp:msg];
            break;
        default:
            return;
    }
}

- (void)handlePublish:(MQTTMessage*)msg
{
    id<MQTTSessionDelegate> delegate = self.delegate;
    if( !delegate || ![delegate respondsToSelector:@selector(session:newMessage:onTopic:)] )
    {
        return;
    }
    
    NSData* data = [msg data];
    if( [data length] < 2 )
    {
        return;
    }
    
    UInt8 const* bytes = [data bytes];
    UInt16 topicLength = 256 * bytes[0] + bytes[1];
    if( [data length] < 2 + topicLength )
    {
        return;
    }
    
    NSData* topicData = [data subdataWithRange:NSMakeRange( 2, topicLength )];
    NSString* topic = [[NSString alloc] initWithData:topicData encoding:NSUTF8StringEncoding];
    NSRange range = NSMakeRange( 2 + topicLength, [data length] - topicLength - 2 );
    data = [data subdataWithRange:range];
    if( [msg qos] == 0 )
    {
        [delegate session:self newMessage:data onTopic:topic];
    }
    else
    {
        if( [data length] < 2 )
        {
            return;
        }
        bytes = [data bytes];
        UInt16 msgId = 256 * bytes[0] + bytes[1];
        if( msgId == 0 )
        {
            return;
        }
        
        data = [data subdataWithRange:NSMakeRange( 2, [data length] - 2 )];
        if( [msg qos] == 1 )
        {
            [delegate session:self newMessage:data onTopic:topic];
            [self send:[MQTTMessage pubackMessageWithMessageId:msgId]];
        }
        else
        {
            NSDictionary* dict =  @{ @"data": data, @"topic":topic };
            [self.rxFlows setObject:dict forKey:[NSNumber numberWithUnsignedInt:msgId]];
            [self send:[MQTTMessage pubrecMessageWithMessageId:msgId]];
        }
    }
}

- (void)handlePuback:(MQTTMessage*)msg
{
    if( [[msg data] length] != 2 )
    {
        return;
    }
    
    UInt8 const* bytes = [[msg data] bytes];
    NSNumber* msgId = [NSNumber numberWithUnsignedInt:( 256 * bytes[0] + bytes[1]) ];
    if( [msgId unsignedIntValue] == 0 )
    {
        return;
    }
    
    MQttTxFlow* flow = [self.txFlows objectForKey:msgId];
    if( flow == nil )
    {
        return;
    }

    if( [[flow msg] type] != MQTTMessageTypePublish || [[flow msg] qos] != 1 )
    {
        return;
    }

    [[self.timerRing objectAtIndex:([flow deadline] % 60)] removeObject:msgId];
    [self.txFlows removeObjectForKey:msgId];
}

- (void)handlePubrec:(MQTTMessage*)msg
{
    if( [[msg data] length] != 2 )
    {
        return;
    }
    
    UInt8 const* bytes = [[msg data] bytes];
    NSNumber* msgId = [NSNumber numberWithUnsignedInt:( 256 * bytes[0] + bytes[1] )];
    if( [msgId unsignedIntValue] == 0 )
    {
        return;
    }
    
    MQttTxFlow* flow = [self.txFlows objectForKey:msgId];
    if( flow == nil )
    {
        return;
    }
    
    msg = [flow msg];
    if( [msg type] != MQTTMessageTypePublish || [msg qos] != 2 )
    {
        return;
    }
    
    msg = [MQTTMessage pubrelMessageWithMessageId:[msgId unsignedIntValue]];
    [flow setMsg:msg];
    [[self.timerRing objectAtIndex:( [flow deadline] % 60 )] removeObject:msgId];
    [flow setDeadline:(_ticks + 60)];
    [[self.timerRing objectAtIndex:( [flow deadline] % 60 )] addObject:msgId];

    [self send:msg];
}

- (void)handlePubrel:(MQTTMessage*)msg
{
    if( [[msg data] length] != 2 )
    {
        return;
    }
    
    UInt8 const* bytes = [[msg data] bytes];
    NSNumber* msgId = [NSNumber numberWithUnsignedInt:( 256 * bytes[0] + bytes[1] )];
    if( [msgId unsignedIntValue] == 0 )
    {
        return;
    }
    
    NSDictionary* dict = [self.rxFlows objectForKey:msgId];
    if( dict != nil )
    {
        [self delegateHandleMessage:[dict valueForKey:@"data"] onTopic:[dict valueForKey:@"topic"]];
        [self.rxFlows removeObjectForKey:msgId];
    }
    [self send:[MQTTMessage pubcompMessageWithMessageId:[msgId unsignedIntegerValue]]];
}

- (void)handlePubcomp:(MQTTMessage*)msg
{
    if( [[msg data] length] != 2 )
    {
        return;
    }
    
    UInt8 const* bytes = [[msg data] bytes];
    NSNumber* msgId = [NSNumber numberWithUnsignedInt:( 256 * bytes[0] + bytes[1] )];
    if( [msgId unsignedIntValue] == 0 )
    {
        return;
    }
    
    MQttTxFlow* flow = [self.txFlows objectForKey:msgId];
    if( flow == nil || [[flow msg] type] != MQTTMessageTypePubrel )
    {
        return;
    }

    [[self.timerRing objectAtIndex:([flow deadline] % 60)] removeObject:msgId];
    [self.txFlows removeObjectForKey:msgId];
}

- (void)error:(MQTTSessionEvent)eventCode
{
    
    [self.encoder close];
    self.encoder = nil;
    
    [self.decoder close];
    self.decoder = nil;
    
    if( self.timer != nil )
    {
        [self.timer invalidate];
        self.timer = nil;
    }
    
    self.status = MQTTSessionStatusError;
    
    usleep(1000000); // 1 sec delay
    
    [self delegateHandleEvent:eventCode];

}

- (void)send:(MQTTMessage*)msg
{
    if( [self.encoder status] == MQTTEncoderStatusReady )
    {
        [self.encoder encodeMessage:msg];
    }
    else
    {
        [self.queue addObject:msg];
    }
}

- (UInt16)nextMsgId
{
    _txMsgId++;
    while( _txMsgId == 0 || [self.txFlows objectForKey:[NSNumber numberWithUnsignedInt:_txMsgId]] != nil )
    {
        _txMsgId++;
    }
    return _txMsgId;
}

@end
