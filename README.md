## [react-native-ios-spotify-sdk](https://github.com/Emphaz/react-native-ios-spotify-sdk)

This module allows any react-native application to use the Spotify iOS SDK authentication features.
It opens a Spotify Authentication Webview asking the user to login, and then returns the token provided by Spotify.

It currently supports two types of authentication:
- The [implicit grant flow](https://developer.spotify.com/web-api/authorization-guide/#implicit-grant-flow) that generates a non-refreshable token. With this flow you don't have to host any *token swaping* service.
- The [authorization code flow](https://developer.spotify.com/web-api/authorization-guide/#authorization-code-flow) that generates a refreshable token. You're provided with an *access_token* and a *refresh_token*.

## Installation

### Installing the Spotify iOS SDK

Before installing the module, you have to install the Spotify iOS SDK.

You can use this [tutorial](https://developer.spotify.com/technologies/spotify-ios-sdk/tutorial/). 
Follow the steps `Creating a new Project` (not the creation of a blank project, only the import of Spotify 
framework. Only the `SpotifyAuthentication` file is required) `Creating Your Client ID, Secret and Callback URI`  
and `Setting Up Your Build Environment`.

### Copying the module's files

Your react-native project directory structure should now look like this:
```
.
├── README.md
├── __tests__
├── android
├── app
├── ios
│   ├── Frameworks
│   ├── SpotifyAuthentication.framework
│   ├── build
│   ├── myappname
│   │   ├── AppDelegate.h
│   │   ├── AppDelegate.m
│   │   ...
│   │   └── main.m
│   ├── myappname-tvOS
│   ├── myappname-tvOSTests
│   ├── myappname.xcodeproj
│   └── myappnameTests
...
└── package.json
```

We're not exactly sure whether the `SpotifyAuthentication.framework` should be in `Frameworks/` or not, but if it is properly linked in Xcode, you should be fine.

You should now copy the `SpotifyModule.h` and `SpotifyModule.m` files into the `ios/myappname/` folder.

Once it is done, right click (in XCode) on the folder called `myappname` in the project, click on `Add files to "myappname"` 
and select the two files you just copied.

### Configuration of the `SpotifyModule.m` file

Open `SpotifyModule.m` and find the following lines:
```objective-c
  // The spotify client id
  [[SPTAuth defaultInstance] setClientID:@"[your-client-id]"];
  
  // The callback (called Custom URL Scheme in XCode project configuration)
  [[SPTAuth defaultInstance] setRedirectURL:[NSURL URLWithString:@"emphaz-app-login://callback"]];

  // The scope request for the token
  [[SPTAuth defaultInstance] setRequestedScopes:@[SPTAuthUserReadPrivateScope, SPTAuthUserReadEmailScope, SPTAuthUserFollowReadScope]];
```

Replace the values by the ones you generated when creating your Spotify App in the tutorial linked before.


### Optional. Enabling token swapping

Just after the lines you edited, there is the following line of code:
```objective-c
  // OPTIONAL. Allows retrieval of refresheable tokens. If not specified, it uses the 'Implicit Grant' auth workflow
  [[SPTAuth defaultInstance] setTokenSwapURL: [NSURL URLWithString:@"http://my-token-swapping-service.tld/swap.php"]];
```

By un-commenting the second line, you're enabling the token swapping service. It allows you to 
exchange an `authorization code` provided by Spotify for an `access_token` and more importantly a 
`refresh token`.

For this to work, you need to host a simple swapping service that answers to the requests 
defined in the [Spotify iOS SDK Token Swap and Refresh](https://developer.spotify.com/technologies/spotify-ios-sdk/token-swap-refresh/) page.

There are a few token swapping libraries available:
- [Emphaz/spotify-token-swap-php](https://github.com/Emphaz/spotify-token-swap-php), a php composer package we developed especially for this.
- [spotify_token_swap.rb](https://github.com/spotify/ios-sdk/blob/master/Demo%20Projects/spotify_token_swap.rb), a ruby implementation from Spotify themselves
- Probably other implementations but these are the only one we have experience with

### Triggering SpotifyModule when the webview redirects to the app

You could already call the module from your js scripts, but you wouldn't be able to catch the response from the authentication webview, and your callbacks would be broken.

For it to work, you have to edit your `ios/myappname/AppDelegate.m` file so that it knows which method to call whenever the application is opened through a *Custom URL Scheme*.

If you don't have the `- (BOOL) application: ...` method, add this at the end of `AppDelegate.m`:
```objective-c
// ios/myappname/AppDelegate.m

// ...

#import "SpotifyModule.h"

// ...

/**
 * Called whenever the application is opened from a custom URL Scheme
 * ex: my-app-login, fb[APP_ID], etc...
 */
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
  
  return [SpotifyModule application:application
                            openURL:url
                  sourceApplication:sourceApplication
                         annotation:annotation];
}
```

If for any reason you already have the `- (BOOL) application: ...` method, it means some other module might already be triggering some behavior whenever the application is opened through a *Custom URL Scheme*.

This is what we did so that Spotify and Facebook could both work together. Please note that you only have to do that if some code already exists within the `- (BOOL) application: ...` method.

```objective-c
// ios/myappname/AppDelegate.m

// ...

/**
 * Called whenever the application is opened from a custom URL Scheme
 * ex: emphaz-app-login, fb[APP_ID], etc...
 */
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
  
  // Creates a string from the URL
  NSString *myString = url.absoluteString;

  // Extracts the prefix of the string (all before the colon)
  NSString *prefix = [myString componentsSeparatedByString:@":"][0];
  
  // Callback for Spotify Auth
  if ([prefix isEqualToString:@"my-app-login"])
  {
    return [SpotifyModule application:application
                              openURL:url
                    sourceApplication:sourceApplication
                           annotation:annotation];
  }
  // Callback for anything else (only Facebook here)
  else
  {
    return [[FBSDKApplicationDelegate sharedInstance] application:application
                                                          openURL:url
                                                sourceApplication:sourceApplication
                                                       annotation:annotation];
  }
}
```

This is a bit dirty, there's probably a better way of doing it, but it works and it's sufficient for us.

## Usage
The setup is the hardest part, once it is done, you don't have much code to write to make it work.

First, import `NativeModules` from `react-native`, and get the `SpotifyModule` module:
```javascript
import { NativeModules } from 'react-native';
const SpotifyModule = NativeModules.SpotifyModule;
```

You can then trigger the Authentication in any method you want, such as on button press:
```jsx

import React, { Component } from 'react';
import {
  AppRegistry,
  View,
  TouchableHighlight,
  Text,
  NativeModules 
} from 'react-native';

class myappname extends Component {
  
  _onSpotifyButtonPress() {
    try {
      SpotifyModule.authenticate(data => {
        console.log(data);
      });    
    } catch(err) {
      console.error('Spotify authentication failed: ', err);
    }
  }

  render() {
    return (
      <View>
        <TouchableHighlight onPress={this._onSpotifyButtonPress.bind(this)}>
          <Text>Spotify Login</Text>
        </TouchableHighlight>
      </View>
    );
  }
}

AppRegistry.registerComponent('myappname', () => myappname);
```

It would output a JS object such as: 
```
// In the case of an implicit grant flow
Object {
  accessToken: "BQBy2fuwTU8ldrPNksDFOal ... _LSp7jL3bNVFDEd-9sdf91skf3VNzFx5Q", 
  expirationDate: "1492999797"
}

// or this, in the case of a authorization code flow
Object {
  accessToken: "BQBy2fuwTU8ldrPNksDFOal ... _LSp7jL3bNVFDEd-9sdf91skf3VNzFx5Q", 
  refreshToken: "AQBKDmSKSDFkskfaoeposdk ... TF-vhKPmKSDFksdkfksdfkkbi2cvbHLY",
  expirationDate: "1492999797"
}
```


