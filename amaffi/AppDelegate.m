//
//  AppDelegate.m
//  amaffi
//
//  Created by uasi on 2012/08/09.
//
//

#import "AppDelegate.h"

@interface AppDelegate ()
@property (nonatomic, assign) NSInteger changeCount;
@property (nonatomic, strong) NSString *trackingID;
@property (readonly) NSString *trackingParam;
@end

@interface NSURL (Amaffi)
@property (readonly) BOOL isAmazon;
@end

@implementation AppDelegate

@dynamic trackingParam;

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    char *trackingIDCstr = getenv("AMAZON_TRACKING_ID");
    if (trackingIDCstr) {
        self.trackingID = [NSString stringWithUTF8String:trackingIDCstr];
    }
    else {
        fprintf(stderr, "Warning: AMAZON_TRACKING_ID is not set\n");
    }
    self.changeCount = [[NSPasteboard generalPasteboard] changeCount];
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(observePasteboard:) userInfo:nil repeats:YES];
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
    NSString *URLString = ([pboard stringForType:@"public.url"] ?:
                           [pboard stringForType:NSPasteboardTypeString]);
    if (!URLString) return [pboard changeCount];

    NSString *newURLString = [self rewriteURLString:URLString];
    if (![newURLString isEqual:URLString]) {
        NSLog(@"Rewrite URL: <%@> to <%@>", URLString, newURLString);
        [pboard clearContents];
        [pboard setString:newURLString forType:@"public.url"];
        [pboard setString:newURLString forType:NSPasteboardTypeString];
    }
    else {
        NSLog(@"Unmatched URL: <%@>", URLString);
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

- (NSString *)rewriteURLString:(NSString *)URLString
{
    // http://www.amazon.com/(PRODUCTNAME)/dp/(ASIN)/ may contain non-ASCII chars
    // in (PRODUCTNAME) part, which +URLWithString: doesn't accept.
    // So we first replace them with pretty harmless chars.
    URLString = sub(@"^(https?://[^/]+/)(?:[^/]+)(/dp/\\w+/.+$)", @"$1(PRODUCTNAME)$2", URLString);
    NSURL *URL = [NSURL URLWithString:URLString];
    if (!URL) return URLString;

    NSString *newURLString = nil;
    if (URL.isAmazon) {
        NSString *template = [NSString stringWithFormat:@"http://%@/dp/$1/%@", URL.host, self.trackingParam];
        newURLString = (sub(@"^.+&creativeASIN=(\\w+)&.+$", template, URLString) ?:
                        sub(@"^https?://[^/]+/gp/product/(\\w+)/.+$", template, URLString) ?:
                        sub(@"^https?://[^/]+/(?:[^/]+/)dp/(\\w+)/.+$", template, URLString) ?:
                        sub(@"^https?://[^/]+/o/ASIN/(\\w+)/.+$", template, URLString) ?:
                        sub(@"-https?://[^/]+/exec/obidos/ASIN/(\\w+)/.+$", template, URLString));
    }
    return newURLString ?: URLString;
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
