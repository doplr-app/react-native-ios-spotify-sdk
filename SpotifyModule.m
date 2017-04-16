/*
 * A react-native native modules exposing the Spotify SDK Auth features.
 * Based on the code provided by Giannis in a comment on this Stackoverflow thread:
 * https://stackoverflow.com/questions/41682991/reactnative-ios-spotify-sdk
 */

#import "SpotifyModule.h"
#import "React/RCTLog.h"
#import "React/RCTBridge.h"


@implementation SpotifyModule

/*
 * Exposes the module to react-native.
 * Accessible through NativeModules.SpotifyModule
 */
RCT_EXPORT_MODULE()


+ (id)sharedManager {
  static SpotifyModule *sharedManager = nil;
  @synchronized(self) {
    if (sharedManager == nil)
      sharedManager = [[self alloc] init];
  }
  return sharedManager;
}

// Exposes the 'authenticate' method to React Native
RCT_EXPORT_METHOD(authenticate:(RCTResponseSenderBlock)callback)
{
  /*
   * Sets everything up
   */
  
  // The spotify client id
  [[SPTAuth defaultInstance] setClientID:@"[client_id]"];
  
  // The callback (called Custom URL Scheme in XCode project configuration)
  [[SPTAuth defaultInstance] setRedirectURL:[NSURL URLWithString:@"my-app-login://callback"]];

  // The scope request for the token
  [[SPTAuth defaultInstance] setRequestedScopes:@[SPTAuthUserReadPrivateScope, SPTAuthUserReadEmailScope, SPTAuthUserFollowReadScope]];

  // OPTIONAL. Allows retrieval of refresheable tokens. If not specified, it uses the 'Implicit Grant' auth workflow
  //[[SPTAuth defaultInstance] setTokenSwapURL: [NSURL URLWithString:@"http://my-token-swap-service.tld/swap.php"]];
  
  /*
   * Creates and opens a Spotify Auth Webview
   */
  
  // Construct a login URL and open it
  NSURL *loginURL = [[SPTAuth defaultInstance] spotifyWebAuthenticationURL];
  
  //save the login callback
  SpotifyModule *spotifyModule = (SpotifyModule *)[SpotifyModule sharedManager];
  spotifyModule.loginCallback = callback;
  
  //setup event dispatcher
  spotifyModule.eventDispatcher = [[RCTEventDispatcher alloc] init];
  [spotifyModule.eventDispatcher setValue:self.bridge forKey:@"bridge"];
  
  RCTLogInfo(@"%@", loginURL);
  
  // Opening a URL in Safari close to application launch may trigger
  // an iOS bug, so we wait a bit before doing so.
  [[UIApplication sharedApplication] openURL:loginURL];
}

/*
 * The method that you need to call when the application is opened through a Custom URL Scheme
 * (Here it would be whenever the webview redirects to: 'my-super-application://callback')
 */
+ (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
  
  RCTLogInfo(@"Login Callback");
  
  // Ask SPTAuth if the URL given is a Spotify authentication callback
  if ([[SPTAuth defaultInstance] canHandleURL:url]) {
    
    // The 'session' object contains all the data returned by the Spotify API
    [[SPTAuth defaultInstance] handleAuthCallbackWithTriggeredAuthURL:url callback:^(NSError *error, SPTSession *session) {
      
      // If anything failed, logs the error then returns
      if (error != nil) {
        NSLog(@"*** Auth error: %@", error);
        return;
      }
      
      RCTLogInfo(@"Login Successful");
      
      SpotifyModule *spotifyModule = (SpotifyModule *)[SpotifyModule sharedManager];
      spotifyModule.session = session;
      
      // The object that will be returned to the JS callback
      NSDictionary *inventory = nil;
      
      // Converts the NSDate expiration date to a Unix timestamp
      NSTimeInterval timestamp = [session.expirationDate timeIntervalSince1970];
      NSString *expirationDate = [NSString stringWithFormat:@"%ld", (long)timestamp];
      
      // If a token swap URL was provided, extracts all the fields
      if([[SPTAuth defaultInstance] hasTokenSwapService])
      {
        // We swapped the short lived token for a real one; which means we have access
        // to an access/refresh token and an expiration date
        inventory = @{
                      @"accessToken" : session.accessToken,
                      @"refreshToken" : session.encryptedRefreshToken,
                      @"expirationDate": expirationDate
                      };
      }
      else
      {
        // If we're in the 'Implicit Grant' case, only retrieves the access token, since that is the only
        // thing we have access to
        inventory = @{
                      @"accessToken" : session.accessToken,
                      @"expirationDate": expirationDate
                      };
      }
      
      // Sends the 'inventory' object to the js Callback
      spotifyModule.loginCallback(@[inventory]);
    }];
    
    return YES;
  }
  
  return NO;
}

@end
