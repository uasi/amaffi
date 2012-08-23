//
//  AppDelegate.m
//  amaffi
//
//  Created by uasi on 2012/08/09.
//
//

#import "AppDelegate.h"

#define APP_IDENTIFIER @"org.exsen.amaffi"

#define LAUNCHD_PLIST \
    @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" \
    @"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" \
    @"<plist version=\"1.0\">\n" \
    @"<dict>\n" \
    @"\t<key>Label</key>\n" \
    @"\t<string>org.exsen.amaffi</string>\n" \
    @"\t<key>ProgramArguments</key>\n" \
    @"\t<array>\n" \
    @"\t\t<string>%@</string>\n" /* placeholder 1: full path to executable */ \
    @"\t\t<string>%@</string>\n" /* placeholder 2: tracking ID */ \
    @"\t</array>\n" \
    @"\t<key>RunAtLoad</key>\n" \
    @"\t<true/>\n" \
    @"\t<key>KeepAlive</key>\n" \
    @"\t<true/>\n" \
    @"</dict>\n" \
    @"</plist>\n"

#define USAGE \
    "Usage: amaffi [options] [tracking ID]\n" \
    "Options:\n" \
    "    --install   -i <ID>  Install launchd plist to start at login\n" \
    "    --uninstall -U       Uninstall launchd plist\n" \
    "    --load      -l       Load launchd plist and start the job\n" \
    "    --unload    -u       Unload launchd plist and stop the job\n" \
    "    --help      -h       Show this help\n" \
    "Note:\n" \
    "    If tracking ID is not given, amaffi tries to obtain it from\n" \
    "    AMAZON_TRACKING_ID environment variable.\n"


@interface AppDelegate ()
@property (nonatomic, assign) NSInteger changeCount;
@property (nonatomic, strong) NSString *trackingID;
@property (readonly) NSString *trackingParam;
@end

@interface NSString (Amaffi)
- (BOOL)isEqualToAnyOfStrings:(NSArray *)strings;
@end

@interface NSURL (Amaffi)
@property (readonly) BOOL isAmazon;
@end

@implementation AppDelegate

@dynamic trackingParam;

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    if ([args count] >= 2) {
        NSString *arg = args[1];
        if ([arg isEqualToAnyOfStrings:@[@"--install", @"-i"]]) {
            self.trackingID = [args count] >= 3 ? args[2] : nil;
            if (!self.trackingID) {
                fprintf(stderr, "Tracking ID is not given.\n");
            }
            else if ([self installLaunchdPlist]) {
                printf("Scucessfully installed.\n");
            }
            else {
                fprintf(stderr, "Installation failed.\n");
            }
            [NSApp terminate:self];
        }
        else if ([arg isEqualToAnyOfStrings:@[@"--uninstall", @"-U"]]) {
            if ([self uninstallLaunchdPlist]) {
                printf("Successfully uninstalled.\n");
            }
            else {
                fprintf(stderr, "Uninstallation failed.\n");
            }
            [NSApp terminate:self];
        }
        else if ([arg isEqualToAnyOfStrings:@[@"--load", @"-l"]]) {
            [self loadLaunchdPlist];
            [NSApp terminate:self];
        }
        else if ([arg isEqualToAnyOfStrings:@[@"--unload", @"-u"]]) {
            [self unloadLaunchdPlist];
            [NSApp terminate:self];
        }
        else if ([arg isEqualToAnyOfStrings:@[@"--help", @"-h"]]) {
            printf(USAGE);
            [NSApp terminate:self];
        }
        self.trackingID = arg;
    }
    else {
        char *trackingIDCstr = getenv("AMAZON_TRACKING_ID");
        if (trackingIDCstr) {
            self.trackingID = [NSString stringWithUTF8String:trackingIDCstr];
        }
    }
    self.changeCount = [[NSPasteboard generalPasteboard] changeCount];
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(observePasteboard:) userInfo:nil repeats:YES];
}

- (NSString *)plistPath
{
    NSURL *dirURL = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *plistURL  = [[NSURL alloc] initWithString:(@"LaunchAgents/" APP_IDENTIFIER @".plist") relativeToURL:dirURL];
    return [plistURL path];
}

- (BOOL)installLaunchdPlist
{
    NSString *program = [[NSProcessInfo processInfo] arguments][0];
    NSString *plist = [NSString stringWithFormat:LAUNCHD_PLIST, program, self.trackingID];
    return [[NSFileManager defaultManager] createFileAtPath:[self plistPath] contents:[plist dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
}

- (BOOL)uninstallLaunchdPlist
{
    return [[NSFileManager defaultManager] removeItemAtPath:[self plistPath] error:NULL];
}

- (BOOL)loadLaunchdPlist
{
    NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:@[@"load", @"-w", [self plistPath]]];
    [task waitUntilExit];
    return task.terminationStatus == 0;
}

- (BOOL)unloadLaunchdPlist
{
    NSTask *task = [NSTask launchedTaskWithLaunchPath:@"/bin/launchctl" arguments:@[@"unload", [self plistPath]]];
    [task waitUntilExit];
    return task.terminationStatus == 0;
}

- (void)observePasteboard:(NSTimer *)timer
{
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    if ([pboard changeCount] > self.changeCount) {
        self.changeCount = [self modifyPasteboard:pboard];
    }
}

- (NSInteger)modifyPasteboard:(NSPasteboard *)pboard
{
    NSString *content = ([pboard stringForType:@"public.url"] ?:
                         [pboard stringForType:NSPasteboardTypeString]);
    if (!content) return [pboard changeCount];

    NSString *newContent = [self rewriteAmazonURLString:content];
    if ([newContent isEqual:content]) {
        NSLog(@"Pboard content: %@", content.length < 128 ? content : @"<...>");
    }
    else {
        NSLog(@"Rewrite URL: <%@> to <%@>", content, newContent);
        [pboard clearContents];
        [pboard setString:newContent forType:@"public.url"];
        [pboard setString:newContent forType:NSPasteboardTypeString];
    }
    return [pboard changeCount];
}

static NSString *sub(NSString *pattern, NSString *template, NSString *string)
{
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:NULL];
    if (![re firstMatchInString:string options:0 range:NSMakeRange(0, [string length])]) {
        return nil;
    }
    return [re stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, [string length]) withTemplate:template];
}

- (NSString *)rewriteAmazonURLString:(NSString *)URLString
{
    // http://www.amazon.com/(PRODUCTNAME)/dp/(ASIN)/ may contain non-ASCII chars
    // in (PRODUCTNAME) part, which +URLWithString: doesn't accept.
    // So we first replace them with pretty harmless chars.
    NSString *origURLString = URLString;
    URLString = (sub(@"^(https?://[^/]+/)(?:[^/]+)(/dp/\\w+/.*$)", @"$1(PRODUCTNAME)$2", URLString) ?:
                 origURLString);
    NSURL *URL = [NSURL URLWithString:URLString];
    if (!URL) return origURLString;

    NSString *newURLString = nil;
    if (URL.isAmazon) {
        NSString *template = [NSString stringWithFormat:@"http://%@/dp/$1/%@", URL.host, self.trackingParam];
        newURLString = (sub(@"^.+&creativeASIN=(\\w+)&.*$", template, URLString) ?:
                        sub(@"^https?://[^/]+/gp/product/(\\w+)/.*$", template, URLString) ?:
                        sub(@"^https?://[^/]+/(?:[^/]+/)?dp/(\\w+)/.*$", template, URLString) ?:
                        sub(@"^https?://[^/]+/o/ASIN/(\\w+)/.*$", template, URLString) ?:
                        sub(@"^https?://[^/]+/exec/obidos/ASIN/(\\w+)/.*$", template, URLString));
    }
    return newURLString ?: origURLString;
}

- (NSString *)trackingParam {
    return self.trackingID ? [NSString stringWithFormat:@"?tag=%@", self.trackingID] : @"";
}

@end

@implementation NSURL (Amaffi)

@dynamic isAmazon;

- (BOOL)isAmazon
{
    return ([self hasDomain:@"amazon.com"] ||
            [self hasDomain:@"amazon.co.jp"] ||
            [self hasDomain:@"amazon.jp"]);
}

- (BOOL)hasDomain:(NSString *)domain
{
    return ([self.host isEqual:domain] ||
            [self.host hasSuffix:[@"." stringByAppendingString:domain]]);
}

@end

@implementation NSString (Amaffi)

- (BOOL)isEqualToAnyOfStrings:(NSArray *)strings
{
    for (NSString *string in strings) {
        if ([self isEqualToString:string]) return YES;
    }
    return NO;
}

@end