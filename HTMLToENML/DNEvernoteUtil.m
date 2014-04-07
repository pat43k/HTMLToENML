//
//  DNEvernoteUtil.m
//  ReaderStore
//
//  Created by HUANG CHEN CHERNG on 14/4/3.
//  Copyright (c) 2014年 DrawNews. All rights reserved.
//

//  Evernote
#import "EvernoteNoteStore+Extras.h"
#import "EvernoteSession.h"

#import "DNEvernoteUtil.h"

#import "DNHtmlStream.h"
#import "DNHtmlSloganEnco.h"
#import "DNFeedItem+EXT.h"

#import "DNSTConvertAgent.h"
#import "DrawReaderStore.h"

#import "DrawNewsContstants.h"
#import "DrawNewsUtils.h"

#import "TFHpple.h"
#import "NSString+HTML.h"
#import "CTidy.h"

@implementation DNEvernoteUtil

+ (DNEvernoteUtil*)sharedClient
{
    static DNEvernoteUtil* _sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[DNEvernoteUtil alloc] init];
    });
    return _sharedClient;
}

//
//  instance APIs
//

- (DNEvernoteUtil*) init
{
    self = [super init];
    if (!self) {
        return nil;
    }

    return self;
}

- (BOOL) saveToEvernote:(DNFeedItem*)fitem
{
    #if 0
    return [self saveToEvernote2:fitem withBLK:^(BOOL success) {
        ;
    }];
    #endif
    
    NSMutableString *content = [NSMutableString stringWithString:[self appendSourceInfo:fitem]];
    DNHtmlStream* org_stream = [[DNHtmlStream alloc] initWithMutableString:content];
    //DNHtmlSloganEnco* slogan_stream_enco = [[DNHtmlSloganEnco alloc] initWithStream:org_stream];

    DNSubscription *sub = [[DrawReaderStore sharedClient] getSubscriptionById:(fitem.subscriptionId)];
    BOOL bNeedSTConvert = DN_SUBSCRIPTION_IS_NEED_ST_CONVERT(sub.flags);
    NSString* title=bNeedSTConvert?DN_ST_CONVERT([fitem title]):[fitem title];

    EDAMNote* note = [[EDAMNote alloc] initWithGuid:nil title:title content:[org_stream fetch] contentHash:nil contentLength:0 created:0 updated:0 deleted:0 active:YES updateSequenceNum:0 notebookGuid:nil tagGuids:nil resources:nil attributes:nil tagNames:nil];
    //[[EvernoteSession sharedSession] setDelegate:[self get_instance]];
    [[EvernoteNoteStore noteStore] saveNewNoteToEvernoteApp:note withType:@"text/html"];

    if (!DN_FEEDITEM_IS_EVERNOTE(fitem.flags)) {
        DN_FEEDITEM_SET_EVERNOTE(fitem.flags);
    }

    //fitem.lastMod = [NSDate date];
    //NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextForCurrentThread];
    //[localContext MR_saveToPersistentStoreAndWait];
    [[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
    return true;
}

- (void) saveToEvernote2:(DNFeedItem*)fitem withBLK:(void (^)(BOOL success))BLK
{
    //http://dev.yinxiang.com/doc/articles/enml.php#prohibited
    //[[EvernoteSession sharedSession] setDelegate:[self get_instance]];
    EvernoteSession *session = [EvernoteSession sharedSession];
    if(![session isAuthenticated])
        return;

    [self __createNoteBook:^(EDAMNotebook *notebook) {
        if (!notebook) {
            if(BLK)
                BLK(false);
            return;
        }

        NSString* enml = [self getENML:fitem];
        NSLog(@"enml:%@",enml);

        DNSubscription *sub = [[DrawReaderStore sharedClient] getSubscriptionById:(fitem.subscriptionId)];

        BOOL bNeedSTConvert = DN_SUBSCRIPTION_IS_NEED_ST_CONVERT(sub.flags);
        NSString* title=bNeedSTConvert?DN_ST_CONVERT([fitem title]):[fitem title];
        EDAMNote* note = [[EDAMNote alloc] initWithGuid:nil title:title content:enml contentHash:nil contentLength:0 created:0 updated:0 deleted:0 active:YES updateSequenceNum:0 notebookGuid:notebook.guid tagGuids:nil resources:nil attributes:nil tagNames:nil];

        [[EvernoteNoteStore noteStore] createNote:note success:^(EDAMNote *note){
            NSLog(@"Received note guid: %@", [note guid]);

            //if (!DN_FEEDITEM_IS_EVERNOTE(fitem.flags)) {
            //    DN_FEEDITEM_SET_EVERNOTE(fitem.flags);
            //}
            //fitem.lastMod = [NSDate date];
            //NSManagedObjectContext *localContext = [NSManagedObjectContext MR_contextForCurrentThread];
            //[localContext MR_saveOnlySelfAndWait];
            //[[NSManagedObjectContext MR_defaultContext] MR_saveToPersistentStoreAndWait];
            if(BLK)
                BLK(true);
        } failure: ^(NSError *error) {
            NSLog(@"Create note failed: %@", error);
            if(BLK)
                BLK(false);
        }];
    }];
}

- (NSString*)getENML:(DNFeedItem*)fitem
{
    NSMutableDictionary* dumpedDict = [NSMutableDictionary new];

    NSError* error;
    NSString* html = [fitem content];
    NSString* xhtml = [[CTidy tidy] tidyHTMLString:html
                                          encoding:@"UTF8"
                                             error:&error];
    NSLog(@"xhtml:%@",xhtml);

    // 1
    NSData *htmlData = [xhtml dataUsingEncoding:NSUTF8StringEncoding];

    // 2
    TFHpple *parser = [TFHpple hppleWithHTMLData:htmlData];

    // 3
    NSString *tutorialsXpathQueryString = @"//*";
    NSArray *elemArr = [parser searchWithXPathQuery:tutorialsXpathQueryString];

    // 4
    NSMutableString *enml = [NSMutableString new];
    [enml appendFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE en-note SYSTEM \"http://xml.evernote.com/pub/enml2.dtd\">"];
    [enml appendFormat:@"<en-note>"];
    NSString* subTitle = [fitem getSubscriptionForSection];

    NSDateFormatter*dateFormatter =[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
    NSString* strDate =[dateFormatter stringFromDate:fitem.date];
    [enml appendFormat:@"<p><span style=\"font-weight:bold;color:gray;\">%@ %@</span></p>",strDate,subTitle?subTitle:@""];

    int num = [elemArr count];
    for (int i=0;i<num;i++) {
        TFHppleElement* element = [elemArr objectAtIndex:i];
        NSLog(@"element tag name(%d):%@",i,element.tagName);
        [self __travNode:element withENML:enml withDumpedDict:dumpedDict];
    }

    NSString* lnk = fitem.link;
    if (lnk)
    {
        lnk = [lnk stringByEncodingHTMLEntities];
        [enml appendFormat:@"<p><a href=\"%@\" target=\"_blank\">%@</a></p>",lnk,@"[view on website]"];
    }
    [enml appendFormat:@"</en-note>"];
    return enml;
}

- (void) __createNoteBook:(void (^)(EDAMNotebook*))BLK
{
    #define DN_STACK   @"[ DrawNews ]"
    #define DN_MY_NOTE @"[DN] My note"
    EvernoteSession *session = [EvernoteSession sharedSession];
    if(![session isAuthenticated])
    {
        BLK(nil);
        return;
    }

    static EDAMNotebook* _DNNotebook = nil;

    @synchronized(_DNNotebook){

    if (_DNNotebook) {
        BLK(_DNNotebook);
        return;
    }

    [[EvernoteNoteStore noteStore] listNotebooksWithSuccess:^(NSArray *notebooks) {
        for (EDAMNotebook* nb in notebooks) {
            NSLog(@"Evernote iter: %@",nb.name);
            if ([nb.name isEqualToString:DN_MY_NOTE]) {
                _DNNotebook = nb;
                BLK(_DNNotebook);
                return;
            }
        }
        //
        //  crNotebook under DrawNews Stack
        //
        EvernoteNoteStore *noteStore = [EvernoteNoteStore noteStore];
        EDAMNotebook* notebook = [[EDAMNotebook alloc] initWithGuid:nil name:DN_MY_NOTE updateSequenceNum:0 defaultNotebook:NO serviceCreated:0 serviceUpdated:0 publishing:nil published:NO stack:DN_STACK sharedNotebookIds:nil sharedNotebooks:nil businessNotebook:nil contact:nil restrictions:nil];

        [noteStore createNotebook:notebook success:^(EDAMNotebook *notebook) {
            _DNNotebook = notebook;
            BLK(_DNNotebook);
        } failure:^(NSError *error) {
            NSLog(@"err:%@",error);
            BLK(nil);
            return;
        }];
    } failure:^(NSError *error) {
        NSLog(@"err:%@",error);
        BLK(nil);
        return;
    }];

    }
}

- (void)__travNode:(TFHppleElement*)element withENML:(NSMutableString*)enml withDumpedDict:(NSMutableDictionary*)dumpedDict
{
    if ([element.tagName isEqualToString:@"p"]) {
        NSArray* arr = [element children];
        [enml appendFormat:@"<p>"];
        for ( TFHppleElement *subElem in arr ) {
            [self __travNode:subElem withENML:enml withDumpedDict:dumpedDict];
        }
        [enml appendFormat:@"</p>"];
    }
    else if ([element.tagName isEqualToString:@"br"]) {
        NSLog(@"    br:%@",[[element firstChild] content]);
        [enml appendFormat:@"<br></br>"];
    }
    else if ([element.tagName isEqualToString:@"strong"]) {
        NSLog(@"    strong:%@",[[element firstChild] content]);
        //[DrawNewsUtils __crENMLLeaf:element withENML:enml withDumpedDict:dumpedDict];
        [enml appendFormat:@"<strong>"];
        NSArray* arr = [element children];
        for ( TFHppleElement *subElem in arr ) {
            [self __travNode:subElem withENML:enml withDumpedDict:dumpedDict];
        }
        [enml appendFormat:@"</strong>"];
    }
    else if ([element.tagName isEqualToString:@"h1"]) {
        NSLog(@"    h1:%@",[[element firstChild] content]);
        NSArray* arr = [element children];
        [enml appendFormat:@"<h1>"];
        for ( TFHppleElement *subElem in arr ) {
            [self __travNode:subElem withENML:enml withDumpedDict:dumpedDict];
        }
        [enml appendFormat:@"</h1>"];
    }
    else if ([element.tagName isEqualToString:@"h2"]) {
        NSLog(@"    h2:%@",[[element firstChild] content]);
        NSArray* arr = [element children];
        [enml appendFormat:@"<h2>"];
        for ( TFHppleElement *subElem in arr ) {
            [self __travNode:subElem withENML:enml withDumpedDict:dumpedDict];
        }
        [enml appendFormat:@"</h2>"];
    }
    else if ([element.tagName isEqualToString:@"h3"]) {
        NSLog(@"    h3:%@",[[element firstChild] content]);
        NSArray* arr = [element children];
        [enml appendFormat:@"<h3>"];
        for ( TFHppleElement *subElem in arr ) {
            [self __travNode:subElem withENML:enml withDumpedDict:dumpedDict];
        }
        [enml appendFormat:@"</h3>"];
    }
    else if ([element.tagName isEqualToString:@"h4"]) {
        NSLog(@"    h4:%@",[[element firstChild] content]);
        NSArray* arr = [element children];
        [enml appendFormat:@"<h4>"];
        for ( TFHppleElement *subElem in arr ) {
            [self __travNode:subElem withENML:enml withDumpedDict:dumpedDict];
        }
        [enml appendFormat:@"</h4>"];
    }
    else if ([element.tagName isEqualToString:@"h5"]) {
        NSLog(@"    h5:%@",[[element firstChild] content]);
        NSArray* arr = [element children];
        [enml appendFormat:@"<h5>"];
        for ( TFHppleElement *subElem in arr ) {
            [self __travNode:subElem withENML:enml withDumpedDict:dumpedDict];
        }
        [enml appendFormat:@"</h5>"];
    }
    else if ([element.tagName isEqualToString:@"h6"]) {
        NSLog(@"    h6:%@",[[element firstChild] content]);
        NSArray* arr = [element children];
        [enml appendFormat:@"<h6>"];
        for ( TFHppleElement *subElem in arr ) {
            [self __travNode:subElem withENML:enml withDumpedDict:dumpedDict];
        }
        [enml appendFormat:@"</h6>"];
    }
    else
    {
        [self __travLeaf:element withENML:enml withDumpedDict:dumpedDict];
    }
}

- (void)__travLeaf:(TFHppleElement*)element withENML:(NSMutableString*)enml withDumpedDict:(NSMutableDictionary*)dict
{
    if ([element.tagName isEqualToString:@"a"]) {
        NSLog(@"    href:%@",[element objectForKey:@"href"]);
        NSLog(@"    text:%@",[[element firstChild] content]);
        NSString* lnk = [[element objectForKey:@"href"] stringByEncodingHTMLEntities];

        if (!lnk||[dict objectForKey:lnk]||[lnk rangeOfString:@"http"].location==NSNotFound) {
            //[dict removeObjectForKey:lnk];//pop
            return;
        }

        if ( [[element firstChild] content] ) {

            [enml appendFormat:@"<a href=\"%@\" target=\"_blank\">%@</a>",lnk,[[element firstChild] content]];
        }
        else
        {
            [enml appendFormat:@"<a href=\"%@\" target=\"_blank\"></a>",lnk];
        }
        [dict setObject:lnk forKey:lnk];
    }
    else if ([element.tagName isEqualToString:@"img"]) {
        NSLog(@"    src:%@",[element objectForKey:@"src"]);
        NSLog(@"    alt:%@",[element objectForKey:@"alt"]);
        NSString* src = [[element objectForKey:@"src"] stringByEncodingHTMLEntities];

        if (!src||[dict objectForKey:src]||[src rangeOfString:@"http"].location==NSNotFound) {
            //[dict removeObjectForKey:src];//pop
            return;
        }

        if ( [element objectForKey:@"alt"] ) {
            [enml appendFormat:@"<img src=\"%@\" alt=\"%@\"></img>",src,[element objectForKey:@"alt"]];
        }
        else
        {
            [enml appendFormat:@"<img src=\"%@\"></img>",src];
        }
        [dict setObject:src forKey:src];
    }
    else if ([element.tagName isEqualToString:@"span"]) {
        NSLog(@"    span:%@",[[element firstChild] content]);
        NSLog(@"    style:%@",[element objectForKey:@"style"]);
        NSString* colorText = [[element firstChild] content];

        if (!colorText||[dict objectForKey:colorText]) {
            //[dict removeObjectForKey:colorText];
            return;
        }
        if ([[element firstChild] content]&&[[element objectForKey:@"style"] isEqualToString:@"background-color: yellow;"]) {

            [enml appendFormat:@"<span style=\"background-color: yellow;\">%@</span>",colorText];
            [dict setObject:colorText forKey:colorText];
        }
        /*
         NSArray* arr = [element children];
         for ( TFHppleElement *elem in arr ) {
         NSLog(@"element tag name:%@",elem.tagName);
         }
         */
    }
    else if ([element.tagName isEqualToString:@"text"]) {
        NSLog(@"    text:%@",[element content]);
        NSString* text = [element content];
        if (!text||[dict objectForKey:text]) {
            //[dict removeObjectForKey:[element content]];
            return;
        }
        [enml appendFormat:@"%@",text];
        [dict setObject:text forKey:text];
    }
}

#if 0
- (void)uploadFeeditems
{
    NSInteger target=DN_FEEDITEM_BEEN_NOTE;
    NSPredicate *FeedItemPredicate = [NSPredicate predicateWithFormat:@"((flags & %i)!=0) AND ((flags & %i)== 0)", target,DN_FEEDITEM_BEEN_EVERNOTE];

    NSFetchedResultsController *frc = [DNFeedItem MR_fetchAllSortedBy:@"date" ascending:YES withPredicate:FeedItemPredicate groupBy:nil delegate:nil];

    //NSNumber* count = [DNFeedItem MR_numberOfEntitiesWithPredicate:FeedItemPredicate];
    //NSNumber* count = [[NSNumber alloc] initWithInt:[[[frc sections] objectAtIndex:0] numberOfObjects]];
    NSInteger count = [[[frc sections] objectAtIndex:0] numberOfObjects];

    if ( count==0 ) {
        return;
    }

    const int MAX_SZ = DN_UPLOAD_FITEM_MAX;
    int max = count<MAX_SZ?count:MAX_SZ;
    for (int i=0; i< max; i++)
    {
        NSIndexPath* idx=[NSIndexPath indexPathForRow:i inSection:0];
        DNFeedItem* fitem = [frc objectAtIndexPath:idx];
        [self saveToEvernote2:fitem withBLK:^(BOOL success) {
            ;
        }];
    }
}
#endif

#pragma - source info append
- (NSMutableString*) appendSourceInfo:(DNFeedItem*)fitem
{
    // because evernote didn't being the css file, need to embeded the format here directly.

    NSString *beginDiv = @"<div style=\"background-color: white; border-style:solid; border-color: #04B4AE; border-width:1px; font-size: 12pt; height: 40px; line-height: 40px; margin-left: auto ; margin-right: auto ; text-align: center; vertical-align: middle;\" id=\"source-link-div\"><a href=\"";
    NSString *endDiv = @"\" style=\"display: block; height: 100%; width: 100%;text-decoration: none; color: black;\">View on the website</a></div>";

    NSString *viewSiteHtml = ([fitem link]==nil)?@"":[fitem link];
    NSMutableString *viewSourceTags = [NSMutableString stringWithFormat:@"%@%@%@", beginDiv,viewSiteHtml,endDiv];

    DNSubscription *sub = [[DrawReaderStore sharedClient] getSubscriptionById:(fitem.subscriptionId)];
    BOOL bNeedSTConvert = DN_SUBSCRIPTION_IS_NEED_ST_CONVERT(sub.flags);

    NSString* content = (fitem.content==nil)?@"":(bNeedSTConvert?DN_ST_CONVERT(fitem.content):fitem.content);
    NSString *contentHtml = content;
    NSMutableString *result = [NSMutableString stringWithString:contentHtml];
    [result appendString:viewSourceTags];

    return result;
}

@end
