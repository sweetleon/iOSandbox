using namespace Cedar::Matchers;
using namespace Cedar::Doubles;

#import "OCMock.h"

typedef void (^RunBlock)();
@protocol TakesBlocks
-(void)runBlock:RunBlock;
@end

SPEC_BEGIN(CedarSpec)

describe(@"async blocks", ^{
    __block id spyForProtocol;
    __block bool called = false;
    RunBlock blockToRun = ^{
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        dispatch_queue_t priorityQueue = dispatch_queue_create("priorityQueue", 0);
        dispatch_set_target_queue(priorityQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH,0));
        
        dispatch_group_async(group, queue, ^{
            dispatch_group_enter(group);
            [spyForProtocol runBlock:^{
                dispatch_group_leave(group);
            }];
        });
        
//        dispatch_group_notify(group, queue, ^{
            dispatch_queue_t mainQueue = dispatch_get_main_queue();
            [spyForProtocol runBlock:^{
                dispatch_async(priorityQueue, ^{
                    dispatch_async(mainQueue, ^{
                        // called = true;
                        NSLog(@"WOW, this is very deeply nested");
                    });
                });
            }];
//        });
    };
    
    beforeEach(^{
        called = false;
    });
    
    it(@"in OCMock should complete happily", ^{
        spyForProtocol = [OCMockObject niceMockForProtocol:@protocol(TakesBlocks)];
        [[[spyForProtocol expect] andDo:^(NSInvocation *invocation) {
            RunBlock runBlock;
            [invocation getArgument:&runBlock atIndex:2];
            runBlock();
            called = true;
        }] runBlock:OCMOCK_ANY];

        blockToRun();
        
        while (!called) {
            NSLog(@"OCMock sleeping...");
            [[NSRunLoop currentRunLoop] addTimer:[NSTimer timerWithTimeInterval:0.1 invocation:nil repeats:NO] forMode:NSDefaultRunLoopMode];
            NSDate *futureDate = [NSDate dateWithTimeIntervalSinceNow:0.1];
            [[NSRunLoop currentRunLoop] runUntilDate:futureDate];
        }

        [spyForProtocol verify];
        NSLog(@"OCMOCK PASSED");
    });
    
    it(@"in Cedar should complete happily", ^{
        spyForProtocol = fake_for(@protocol(TakesBlocks));
        spyForProtocol stub_method("runBlock:").and_do(^(NSInvocation *invocation) {
            RunBlock runBlock;
            [invocation getArgument:&runBlock atIndex:2];
            runBlock();
            called = true;
        });
        
        blockToRun();
        
        while (!called) {
            NSLog(@"Cedar sleeping...");
            [[NSRunLoop currentRunLoop] addTimer:[NSTimer timerWithTimeInterval:0.1 invocation:nil repeats:NO] forMode:NSDefaultRunLoopMode];
            NSDate *futureDate = [NSDate dateWithTimeIntervalSinceNow:0.1];
            [[NSRunLoop currentRunLoop] runUntilDate:futureDate];
        }

        spyForProtocol should have_received("runBlock:");
        NSLog(@"CEDAR PASSED");
    });
});

describe(@"spying on a systemwide singleton [NSUserDefaults standardUserDefaults]", ^{
    beforeEach(^{
        spy_on([NSUserDefaults standardUserDefaults]);
    });
    
    it(@"should work once", ^{
        [NSUserDefaults standardUserDefaults] stub_method("objectForKey:").with(@"A").and_return(@"once");
        [[NSUserDefaults standardUserDefaults] objectForKey:@"A"] should equal(@"once");
    });
    
    it(@"should work twice", ^{
        [NSUserDefaults standardUserDefaults] stub_method("objectForKey:").with(@"A").and_return(@"twice");
        [[NSUserDefaults standardUserDefaults] objectForKey:@"A"] should equal(@"twice");
    });
});

xdescribe(@"be_nil", ^{
    it(@"should not a consider a non-nil object to be nil", ^{
        id foo = [NSObject new];
        expect(foo).to_not(be_nil());
    });
    
    it(@"should consider a nil object to be_nil", ^{
        id foo = nil;
        expect(foo).to(be_nil());
    });
});
SPEC_END
