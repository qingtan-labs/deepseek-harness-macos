#import <Cocoa/Cocoa.h>

int main(void) {
    @autoreleasepool {
        NSURL *mainAppURL = NSBundle.mainBundle.bundleURL;
        for (NSInteger index = 0; index < 4; index++) mainAppURL = mainAppURL.URLByDeletingLastPathComponent;
        if (![NSFileManager.defaultManager fileExistsAtPath:mainAppURL.path]) return 1;
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/usr/bin/open";
        task.arguments = @[ @"-gj", mainAppURL.path, @"--args", @"--background" ];
        @try {
            [task launch];
        } @catch (NSException *exception) {
            return 1;
        }
    }
    return 0;
}
