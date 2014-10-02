//
//  AppDelegate.m
//  MqttExample
//
//  Created by Chris Hinkle on 10/1/14.
//
//

#import "AppDelegate.h"
#import "MQTTSession.h"

@interface AppDelegate ( )<MQTTSessionDelegate>

@property (nonatomic,strong) MQTTSession* session;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    MQTTSession* session = [[MQTTSession alloc] initWithClientId:@"tarst"];
    session.delegate = self;
    
    [session connectToHost:@"iot.eclipse.org" port:1883];
    self.session = session;

    
    return YES;
}

- (void)session:(MQTTSession *)session handleEvent:(MQTTSessionEvent)eventCode
{
    switch( eventCode )
    {
        case MQTTSessionEventConnected:
            NSLog( @"connected" );
            break;
        case MQTTSessionEventConnectionClosed:
            NSLog( @"closed" );
            break;
        case MQTTSessionEventConnectionError:
            NSLog( @"error" );
            break;
        case MQTTSessionEventConnectionRefused:
            NSLog( @"refused" );
            break;
        case MQTTSessionEventProtocolError:
            NSLog( @"protocol error" );
            break;
        default:
            break;
    }
}


- (void)session:(MQTTSession *)session newMessage:(NSData *)data onTopic:(NSString *)topic
{
    NSLog( @"message on topic" );
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
