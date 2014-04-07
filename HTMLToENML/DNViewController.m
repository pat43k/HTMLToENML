//
//  DNViewController.m
//  HTMLToENML
//
//  Created by HUANG CHEN CHERNG on 14/4/7.
//  Copyright (c) 2014年 patrick. All rights reserved.
//

#import "DNViewController.h"
#import "DNEvernoteUtil.h"

@interface DNViewController ()

@end

@implementation DNViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    // get the code for sdk and fbcomment
    NSString *path = [[NSBundle mainBundle] pathForResource:@"PunNode   台灣：從 App 經營看反服貿" ofType:@"html"];
    NSString *html = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    
    NSLog(@"html:%@",html);
    NSString* enml = [[DNEvernoteUtil sharedClient] convertToENML:html];
    NSLog(@"enml:%@",enml);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
