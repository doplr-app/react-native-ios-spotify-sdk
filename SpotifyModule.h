#import <React/RCTBridgeModule.h>
#import "React/RCTEventDispatcher.h"
#import <SpotifyAuthentication/SpotifyAuthentication.h>
#import <SafariServices/SafariServices.h>

@interface SpotifyModule : NSObject <RCTBridgeModule>

@property (nonatomic, strong) SPTSession *session;
@property (nonatomic, copy) RCTResponseSenderBlock loginCallback;
@property (nonatomic, strong) RCTEventDispatcher* eventDispatcher;
@property (nonatomic, strong) SPTAuth *auth;
@property (nonatomic, strong) UIViewController *authViewController;

@property (nonatomic, weak) RCTBridge *bridge;

+ (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)URL
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation;

+ (id)sharedManager;   // class method to return the singleton object

@end
