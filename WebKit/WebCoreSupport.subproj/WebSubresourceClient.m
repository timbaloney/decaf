//
//  WebSubresourceClient.m
//  WebKit
//
//  Created by Darin Adler on Sat Jun 15 2002.
//  Copyright (c) 2002 Apple Computer, Inc. All rights reserved.
//

#import <WebKit/WebSubresourceClient.h>

#import <WebFoundation/WebError.h>
#import <WebFoundation/WebResourceHandle.h>
#import <WebFoundation/WebResourceHandlePrivate.h>
#import <WebFoundation/WebResourceRequest.h>
#import <WebFoundation/WebResourceResponse.h>

#import <WebCore/WebCoreResourceLoader.h>

#import <WebKit/WebLoadProgress.h>
#import <WebKit/WebControllerPrivate.h>
#import <WebKit/WebBridge.h>
#import <WebKit/WebDataSourcePrivate.h>
#import <WebKit/WebFrame.h>
#import <WebFoundation/WebAssertions.h>

@implementation WebSubresourceClient

- initWithLoader:(id <WebCoreResourceLoader>)l dataSource:(WebDataSource *)s
{
    [super init];
    
    loader = [l retain];
    dataSource = [s retain];
    
    return self;
}

- (void)dealloc
{
    ASSERT(currentURL == nil);
    
    [loader release];
    [dataSource release];
    [handle release];
    [response release];
    
    [super dealloc];
}

- (void)didStartLoadingWithURL:(NSURL *)URL
{
    ASSERT(currentURL == nil);
    currentURL = [URL retain];
    [[dataSource controller] _didStartLoading:currentURL];
}

- (void)didStopLoading
{
    ASSERT(currentURL != nil);
    [[dataSource controller] _didStopLoading:currentURL];
    [currentURL release];
    currentURL = nil;
}

- (void)receivedProgressWithComplete:(BOOL)isComplete
{
    [[dataSource controller] _receivedProgress:[WebLoadProgress progressWithResourceHandle:handle]
        forResourceHandle:handle fromDataSource:dataSource complete:isComplete];
}

+ (WebSubresourceClient *)startLoadingResource:(id <WebCoreResourceLoader>)rLoader
    withURL:(NSURL *)URL referrer:(NSString *)referrer forDataSource:(WebDataSource *)source
{
    WebSubresourceClient *client = [[self alloc] initWithLoader:rLoader dataSource:source];
    WebResourceRequest *request = [[WebResourceRequest alloc] initWithURL:URL];
    [request setRequestCachePolicy:[[source request] requestCachePolicy]];
    [request setResponseCachePolicy:[[source request] responseCachePolicy]];
    [request setReferrer:referrer];
    [request setCookiePolicyBaseURL:[[[[source controller] mainFrame] dataSource] URL]];
    [request setUserAgent:[[source controller] userAgentForURL:URL]];
    
    if (![WebResourceHandle canInitWithRequest:request]) {
        [request release];
        [rLoader cancel];

        WebError *badURLError = [[WebError alloc] initWithErrorCode:WebErrorCodeBadURLError
                                                           inDomain:WebErrorDomainWebFoundation
                                                         failingURL:[URL absoluteString]];
        [[source controller] _receivedError:badURLError forResourceHandle:nil
            partialProgress:nil fromDataSource:source];
        [badURLError release];
        return nil;
    }
    
    WebResourceHandle *h = [[WebResourceHandle alloc] initWithRequest:request];
    client->handle = h;
    [h loadWithDelegate:client];
    [source _addSubresourceClient:client];
    [client didStartLoadingWithURL:[request canonicalURL]];
    [client receivedProgressWithComplete:NO];
    [request release];
        
    return [client autorelease];
}

- (void)receivedError:(WebError *)error
{
    [[dataSource controller] _receivedError:error forResourceHandle:handle
        partialProgress:[WebLoadProgress progressWithResourceHandle:handle] fromDataSource:dataSource];
}

-(void)handle:(WebResourceHandle *)h willSendRequest:(WebResourceRequest *)request
{
    ASSERT(handle == h);

    // FIXME: We do want to tell the client about redirects.
    // But the current API doesn't give any way to tell redirects on
    // the main page from redirects on subresources, so for now we are
    // just disabling this. Before, we had code that tried to send the
    // redirect, but sent it to the wrong object.
    //[[dataSource _locationChangeHandler] serverRedirectTo:toURL forDataSource:dataSource];

    // FIXME: Need to make sure client sets cookie policy base URL
    // properly on redirect when we have the new redirect
    // request-adjusting API

    WebController *controller = [dataSource controller];
    NSURL *URL = [request URL];

    [request setUserAgent:[controller userAgentForURL:URL]];

    [self didStopLoading];
    [self didStartLoadingWithURL:URL];
}

-(void)handle:(WebResourceHandle *)handle didReceiveResponse:(WebResourceResponse *)theResponse
{
    [theResponse retain];
    [response release];
    response = theResponse;
}

- (void)handle:(WebResourceHandle *)h didReceiveData:(NSData *)data
{
    ASSERT(handle == h);
    ASSERT([currentURL isEqual:[[handle _request] canonicalURL]]);

    [self receivedProgressWithComplete:NO];
    [loader addData:data];
}

- (void)handleDidFinishLoading:(WebResourceHandle *)h
{
    ASSERT(handle == h);
    ASSERT([currentURL isEqual:[[handle _request] canonicalURL]]);
    ASSERT([response statusCode] == WebResourceHandleStatusLoadComplete);

    // Calling _removeSubresourceClient will likely result in a call to release, so we must retain.
    [self retain];
    
    [loader finish];
    
    [dataSource _removeSubresourceClient:self];
    
    WebError *nonTerminalError = [response error];
    if (nonTerminalError) {
        [self receivedError:nonTerminalError];
    }
    
    [self receivedProgressWithComplete:YES];
    
    [self didStopLoading];

    [handle release];
    handle = nil;
    
    [self release];
}

- (void)handle:(WebResourceHandle *)h didFailLoadingWithError:(WebError *)error
{
    ASSERT(handle == h);
    
    // Calling _removeSubresourceClient will likely result in a call to release, so we must retain.
    [self retain];
    
    [loader cancel];
    
    [dataSource _removeSubresourceClient:self];
    
    [self receivedError:error];

    [self didStopLoading];

    [handle release];
    handle = nil;
    
    [self release];
}

- (void)cancel
{
    // Calling _removeSubresourceClient will likely result in a call to release, so we must retain.
    [self retain];
    
    [handle cancel];
    
    [loader cancel];
    
    [dataSource _removeSubresourceClient:self];
        
    WebError *error = [[WebError alloc] initWithErrorCode:WebErrorCodeCancelled 
        inDomain:WebErrorDomainWebFoundation failingURL:[[[dataSource request] URL] absoluteString]];
    [self receivedError:error];
    [error release];

    [self didStopLoading];

    [handle release];
    handle = nil;
    
    [self release];
}

- (WebResourceHandle *)handle
{
    return handle;
}

@end
