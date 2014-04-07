//
//  DNEvernoteUtil.h
//  ReaderStore
//
//  Created by HUANG CHEN CHERNG on 14/4/3.
//  Copyright (c) 2014年 DrawNews. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DNFeedItem.h"

@interface DNEvernoteUtil : NSObject

+ (DNEvernoteUtil *)sharedClient;

//
//  Evernote Service
//
//- (BOOL) evernoteAction:(UIViewController*)controller withFeedItem:(DNFeedItem*)fitem;

- (BOOL) saveToEvernote:(DNFeedItem*)fitem;

- (void) saveToEvernote2:(DNFeedItem*)fitem withBLK:(void (^)(BOOL success))BLK;

- (void) __createNoteBook:(void (^)(EDAMNotebook*))BLK;

@end
