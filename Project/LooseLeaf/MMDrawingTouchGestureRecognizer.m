//
//  MMDrawingTouchGestureRecognizer.m
//  LooseLeaf
//
//  Created by Adam Wulf on 2/8/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//

#import "MMDrawingTouchGestureRecognizer.h"
#import "MMTouchVelocityGestureRecognizer.h"
#import "NSMutableSet+Extras.h"

@implementation MMDrawingTouchGestureRecognizer

@synthesize touchDelegate;

#pragma mark - Singleton

static MMDrawingTouchGestureRecognizer* _instance = nil;

-(id) init{
    if(_instance) return _instance;
    if((self = [super init])){
        _instance = self;
        self.delaysTouchesBegan = NO;
        self.delaysTouchesEnded = NO;
        self.cancelsTouchesInView = NO;
        validTouches = [[NSMutableOrderedSet alloc] init];
        possibleTouches = [[NSMutableOrderedSet alloc] init];
        ignoredTouches = [[NSMutableSet alloc] init];
    }
    return _instance;
}

+(MMDrawingTouchGestureRecognizer*) sharedInstace{
    if(!_instance){
        _instance = [[MMDrawingTouchGestureRecognizer alloc]init];
        _instance.delegate = _instance;
    }
    return _instance;
}

#pragma mark - UIGestureRecognizer

-(BOOL) canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer{
    return NO;
}

-(BOOL) shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    return NO;
}

#pragma mark - Touch Methods

-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    for(UITouch* touch in touches){
        // initialize values for touch
        if(![ignoredTouches containsObject:touch]){
            [possibleTouches addObject:touch];
        }
    }
}

-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    for(UITouch* touch in touches){
        if([possibleTouches containsObject:touch]){
            struct DurationCacheObject velInfo = [[MMTouchVelocityGestureRecognizer sharedInstace] velocityInformationForTouch:touch withIndex:nil];
            if(velInfo.totalDistance > 100){
                [validTouches addObject:touch];
                [possibleTouches removeObject:touch];
                [self.touchDelegate ownershipOfTouches:[NSSet setWithObject:touch] isGesture:self];
                NSLog(@"found a drawing touch");
            }
        }
    }
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    [possibleTouches removeObjectsInSet:touches];
    [ignoredTouches removeObjectsInSet:touches];
    [validTouches removeObjectsInSet:touches];
}

-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{
    [possibleTouches removeObjectsInSet:touches];
    [ignoredTouches removeObjectsInSet:touches];
    [validTouches removeObjectsInSet:touches];
}


-(void) ownershipOfTouches:(NSSet*)touches isGesture:(UIGestureRecognizer*)gesture{
    if(gesture != self){
        [possibleTouches removeObjectsInSet:touches];
        [ignoredTouches addObjectsInSet:touches];
    }
}


#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    return NO;
}

@end