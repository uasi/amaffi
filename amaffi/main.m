//
//  main.m
//  amaffi
//
//  Created by uasi on 2012/08/09.
//
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        AppDelegate *appDelegate = [[AppDelegate alloc] init];
        [NSApp setDelegate:appDelegate];
        [NSApp run];
    }
    return 0;
}

