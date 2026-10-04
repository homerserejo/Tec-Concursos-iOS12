#import "TWAppDelegate.h"
#import "TWViewController.h"

@implementation TWAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
	self.window.rootViewController = [TWViewController new];
	[self.window makeKeyAndVisible];
	return YES;
}

@end
