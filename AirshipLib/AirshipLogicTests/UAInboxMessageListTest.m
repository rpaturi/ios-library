/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAInbox.h"
#import "UAInboxMessageList+Internal.h"
#import "UAInboxAPIClient.h"
#import "UAActionArguments+Internal.h"
#import "UATestSynchronizer.h"
#import "UAirship.h"
#import "UAConfig.h"

static UAUser *mockUser = nil;

@protocol UAInboxMessageListMockNotificationObserver
- (void)messageListWillUpdate;
- (void)messageListUpdated;
@end

@interface UAInboxMessageListTest : XCTestCase
@property (nonatomic, strong) id mockUser;
@property (nonatomic, assign) BOOL userCreated;

//the mock inbox API client we'll inject into the message list
@property (nonatomic, strong) id mockInboxAPIClient;
//a mock object that will sign up for NSNotificationCenter events
@property (nonatomic, strong) id mockMessageListNotificationObserver;

@property (nonatomic, strong) UAInboxMessageList *messageList;

@end

@implementation UAInboxMessageListTest

- (void)setUp {
    [super setUp];

    self.userCreated = YES;
    self.mockUser = [OCMockObject niceMockForClass:[UAUser class]];
    [[[self.mockUser stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:&_userCreated];
    }] isCreated];

    self.mockInboxAPIClient = [OCMockObject niceMockForClass:[UAInboxAPIClient class]];

    self.mockMessageListNotificationObserver = [OCMockObject mockForProtocol:@protocol(UAInboxMessageListMockNotificationObserver)];

    //order is important with these events, so we should be explicit about it
    [self.mockMessageListNotificationObserver setExpectationOrderMatters:YES];

    self.messageList = [UAInboxMessageList messageListWithUser:self.mockUser client:self.mockInboxAPIClient config:[UAConfig config]];

    //inject the API client
    self.messageList.client = self.mockInboxAPIClient;

    //sign up for NSNotificationCenter events with our mock observer
    [[NSNotificationCenter defaultCenter] addObserver:self.mockMessageListNotificationObserver selector:@selector(messageListWillUpdate) name:UAInboxMessageListWillUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self.mockMessageListNotificationObserver selector:@selector(messageListUpdated) name:UAInboxMessageListUpdatedNotification object:nil];
}

- (void)tearDown {
    [self.mockUser stopMocking];

    [self waitUntilAllOperationsAreFinished];

    [[NSNotificationCenter defaultCenter] removeObserver:self.mockMessageListNotificationObserver name:UAInboxMessageListWillUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self.mockMessageListNotificationObserver name:UAInboxMessageListUpdatedNotification object:nil];

    [self.mockInboxAPIClient stopMocking];
    [self.mockMessageListNotificationObserver stopMocking];

    [super tearDown];
}

//if there's no user, retrieveMessageList should do nothing
- (void)testRetrieveMessageListDefaultUserNotCreated {
    self.userCreated = NO;

    [self.messageList retrieveMessageListWithSuccessBlock:^{
        XCTFail(@"No user should no-op");
    } withFailureBlock:^{
        XCTFail(@"No user should no-op");
    }];
    [self waitUntilAllOperationsAreFinished];
}

#pragma mark block-based methods

//if the user is not created, this method should do nothing.
//the UADisposable return value should be nil.
- (void)testRetrieveMessageListWithBlocksDefaultUserNotCreated {
    //if there's no user, the block version of this method should do nothing and return a nil disposable
    self.userCreated = NO;

    __block BOOL fail = NO;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = YES;
    } withFailureBlock:^{
        fail = YES;
    }];

    XCTAssertNil(disposable, @"disposable should be nil");
    XCTAssertFalse(fail, @"callback blocks should not have been executed");
}

//if successful, the observer should get messageListWillLoad and messageListLoaded callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//the succcessBlock should be executed.
//the UADisposable returned should be non-nil.
- (void)testRetrieveMessageListWithBlocksSuccess {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientMessageRetrievalSuccessBlock successBlock = (__bridge UAInboxClientMessageRetrievalSuccessBlock) arg;
        successBlock(304, nil, 0);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];


    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = YES;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = NO;
    } withFailureBlock:^{
        fail = YES;
    }];
    [self waitUntilAllOperationsAreFinished];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertFalse(fail, @"success block should have been called");

    [self.mockMessageListNotificationObserver verify];
}

//if unsuccessful, the observer should get messageListWillLoad and inboxLoadFailed callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//the failureBlock should be executed.
//the UADisposable returned should be non-nil.
- (void)testRetrieveMessageListWithBlocksFailure {
    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        failureBlock(nil);
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = NO;
    } withFailureBlock:^{
        fail = YES;
    }];

    [self waitUntilAllOperationsAreFinished];

    XCTAssertNotNil(disposable, @"disposable should be non-nil");
    XCTAssertTrue(fail, @"failure block should have been called");

    [self.mockMessageListNotificationObserver verify];
}

//if successful, the observer should get messageListWillLoad and messageListLoaded callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//if dispose is called on the disposable, the succcessBlock should not be executed.
- (void)testRetrieveMessageListWithBlocksSuccessDisposal {
    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:2];
        UAInboxClientMessageRetrievalSuccessBlock successBlock = (__bridge UAInboxClientMessageRetrievalSuccessBlock) arg;
        trigger = ^{
            successBlock(304, nil, 0);
        };
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];


    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = YES;
    } withFailureBlock:^{
        fail = YES;
    }];

    [disposable dispose];

    //disposal should prevent the successBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();

    [self waitUntilAllOperationsAreFinished];

    XCTAssertFalse(fail, @"callback blocks should not have been executed");

    [self.mockMessageListNotificationObserver verify];
}

//if unsuccessful, the observer should get messageListWillLoad and inboxLoadFailed callbacks.
//UAInboxMessageListWillUpdateNotification and UAInboxMessageListUpdatedNotification should be emitted.
//if dispose is called on the disposable, the failureBlock should not be executed.
- (void)testRetrieveMessageListWithBlocksFailureDisposal {

    __block void (^trigger)(void) = ^{
        XCTFail(@"trigger function should have been reset");
    };

    [[[self.mockInboxAPIClient expect] andDo:^(NSInvocation *invocation) {
        void *arg;
        [invocation getArgument:&arg atIndex:3];
        UAInboxClientFailureBlock failureBlock = (__bridge UAInboxClientFailureBlock) arg;
        trigger = ^{
            failureBlock(nil);
        };
    }] retrieveMessageListOnSuccess:[OCMArg any] onFailure:[OCMArg any]];

    [[self.mockMessageListNotificationObserver expect] messageListWillUpdate];
    [[self.mockMessageListNotificationObserver expect] messageListUpdated];

    __block BOOL fail = NO;

    UADisposable *disposable = [self.messageList retrieveMessageListWithSuccessBlock:^{
        fail = YES;
    } withFailureBlock:^{
        fail = YES;
    }];
    [self waitUntilAllOperationsAreFinished];

    [disposable dispose];

    //disposal should prevent the failureBlock from being executed in the trigger function
    //otherwise we should see unexpected callbacks
    trigger();

    XCTAssertFalse(fail, @"callback blocks should not have been executed");

    [self.mockMessageListNotificationObserver verify];
}

// Helper method to finish any pending operations on the message list.
- (void)waitUntilAllOperationsAreFinished {

    UATestSynchronizer *testSynchronizer = [[UATestSynchronizer alloc] init];

    // Dispatch a block on the main queue. This allow us to wait for everything thats
    // on the main queue at this exact moment to finish
    dispatch_async(dispatch_get_main_queue(), ^{
        [testSynchronizer continue];
    });

    // Wait for main queue block to execute
    [testSynchronizer wait];
}

@end
