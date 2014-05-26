//
//  MMBezelGestureRecognizer.m
//  Loose Leaf
//
//  Created by Adam Wulf on 6/19/12.
//  Copyright (c) 2012 Milestone Made, LLC. All rights reserved.
//

#import "MMBezelInRightGestureRecognizer.h"
#import "MMBezelInLeftGestureRecognizer.h"
#import "MMTouchVelocityGestureRecognizer.h"
#import "Constants.h"
#import "NSMutableSet+Extras.h"
#import <JotUI/JotUI.h>

@implementation MMBezelInRightGestureRecognizer{
    NSMutableSet* ignoredTouches;
}

@synthesize panDirection;
@synthesize numberOfRepeatingBezels;
@synthesize panDelegate;
@synthesize subState;
@synthesize hasSeenSubstateBegin;

-(id) initWithTarget:(id)target action:(SEL)action{
    self = [super initWithTarget:target action:action];
    validTouches = [[NSMutableSet alloc] init];
    ignoredTouches = [[NSMutableSet alloc] init];
    numberOfRepeatingBezels = 0;
    liftedLeftFingerOffset = 0;
    dateOfLastBezelEnding = nil;
    self.cancelsTouchesInView = NO;
    return self;
}

//
// this will make sure that the substate transitions
// into a valid state and doesn't repeat a Began/End/Cancelled/etc
-(void) processSubStateForNextIteration{
    if(subState == UIGestureRecognizerStateEnded ||
       subState == UIGestureRecognizerStateCancelled ||
       subState == UIGestureRecognizerStateFailed){
        subState = UIGestureRecognizerStatePossible;
    }else if(subState == UIGestureRecognizerStateBegan){
        subState = UIGestureRecognizerStateChanged;
    }
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer{
    return subState != UIGestureRecognizerStatePossible;
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer{
    return [preventingGestureRecognizer isKindOfClass:[MMBezelInLeftGestureRecognizer class]];
}

-(NSArray*)touches{
    return [validTouches allObjects];
}

-(void) cancel{
    if(self.enabled){
        self.enabled = NO;
        self.enabled = YES;
    }
}

/**
 * finds the touch that is furthest left
 *
 * right now, this gesture is effectively hard coded to
 * allow for bezeling in from the right.
 *
 * it would need a refactor to support gesturing from
 * other sides, despite what its API looks like
 */
-(CGPoint) furthestLeftTouchLocation{
    CGPoint ret = CGPointMake(CGFLOAT_MAX, CGFLOAT_MAX);
    for(UITouch* touch in validTouches){
        CGPoint ret2 = [touch locationInView:self.view];
        if(ret2.x < ret.x){
            ret = ret2;
        }
    }
    return ret;
}
/**
 * returns the furthest right touch point of the gesture
 */
-(CGPoint) furthestRightTouchLocation{
    CGPoint ret = CGPointZero;
    for(UITouch* touch in validTouches){
        CGPoint ret2 = [touch locationInView:self.view];
        if(ret2.x > ret.x){
            ret = ret2;
        }
    }
    return ret;
}

/**
 * returns the furthest point of the gesture if possible,
 * otherwise returns default behavior.
 *
 * this is so that the translation isn't an average of
 * touch locations but will follow the lead finger in
 * the gesture.
 */
-(CGPoint) translationInView:(UIView *)view{
    if(self.view){
        CGPoint p = [self furthestLeftTouchLocation];
        if(p.x == MAXFLOAT){
            // we don't have a furthest location,
            // so the translation is zero
            return CGPointZero;
        }
        return CGPointMake(p.x - firstKnownLocation.x - liftedLeftFingerOffset, p.y - firstKnownLocation.y);
    }
    return CGPointZero;
}

/**
 * the first touch of a gesture.
 * this touch may interrupt an animation on this frame, so set the frame
 * to match that of the animation.
 */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    [self processSubStateForNextIteration];
    BOOL foundValidTouch = NO;
    for(UITouch* touch in touches){
        CGPoint point = [touch locationInView:self.view];
        if(point.x < self.view.frame.size.width - kBezelInGestureWidth){
            // only accept touches on the right bezel
            [ignoredTouches addObject:touch];
        }else{
            [validTouches addObject:touch];
            foundValidTouch = YES;
        }
    }
    
    panDirection = MMBezelDirectionNone;
    lastKnownLocation = [self furthestLeftTouchLocation];
    
    // ok, a touch began, and we need to start the gesture
    // and increment our repeat count
    //
    // we have to manually track valid touches for this gesture
    //
    // the default for a gesture recognizer:
    //   after the recognizer is set to UIGestureRecognizerStateEnded,
    //   then all touches from that gesture are ignored for the rest
    //   of the life of that touch
    //
    // we want to support the user gesturing with two fingers into the bezel,
    // then gesturing both OR just one finger back off the bezel and repeating.
    //
    // since we want to effectively re-use a touch for the 2nd bezel gesture,
    // we'll keep the gesture alive and just increment the repeat count counter
    // instead of ending the gesture entirely.
    //
    if([validTouches count] >= 2 && foundValidTouch){
        if(!dateOfLastBezelEnding || [dateOfLastBezelEnding timeIntervalSinceNow] > -.5){
            numberOfRepeatingBezels++;
        }else{
            numberOfRepeatingBezels = 1;
        }
        if(subState == UIGestureRecognizerStatePossible){
            [self.panDelegate ownershipOfTouches:validTouches isGesture:self];
            hasSeenSubstateBegin = NO;
            NSLog(@"right bezel begins");
            subState = UIGestureRecognizerStateBegan;
            firstKnownLocation = [self furthestRightTouchLocation];
            firstKnownLocation.x = self.view.bounds.size.width;
        }
        [dateOfLastBezelEnding release];
        dateOfLastBezelEnding = nil;
    }
    if(self.state == UIGestureRecognizerStatePossible){
        self.state = UIGestureRecognizerStateBegan;
    }else{
        self.state = UIGestureRecognizerStateChanged;
    }
}

/**
 * when the touch moves, track which direction the gesture
 * is moving and record it
 */
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
    [self processSubStateForNextIteration];
    CGFloat xDirection = [self directionOfTouchesInXAxis];
    CGPoint p = [self furthestLeftTouchLocation];
    if(p.x != lastKnownLocation.x){
        panDirection = MMBezelDirectionNone;
        if(xDirection < 0){
            panDirection = panDirection | MMBezelDirectionLeft;
        }
        if(xDirection > 0){
            panDirection = panDirection | MMBezelDirectionRight;
        }
        if(p.y > lastKnownLocation.y){
            panDirection = panDirection | MMBezelDirectionDown;
        }
        if(p.y < lastKnownLocation.y){
            panDirection = panDirection | MMBezelDirectionUp;
        }
        lastKnownLocation = p;
    }
    self.state = UIGestureRecognizerStateChanged;
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    [self processSubStateForNextIteration];
    [ignoredTouches removeObjectsInSet:touches];
    BOOL didChangeTouchLoc = NO;
    CGPoint locationOfLeft = [self furthestLeftTouchLocation];
    for(UITouch* touch in touches){
        CGPoint touchLocation = [touch locationInView:self.view];
        [validTouches removeObject:touch];
        if(CGPointEqualToPoint(touchLocation, locationOfLeft)){
            // this'll use the new left location
            if([self furthestLeftTouchLocation].x != MAXFLOAT){
                liftedLeftFingerOffset += [self furthestLeftTouchLocation].x - touchLocation.x;
            }
            didChangeTouchLoc = YES;
        }
    }
    if([validTouches count] == 0 && subState == UIGestureRecognizerStateChanged){
        subState = UIGestureRecognizerStateEnded;
        [dateOfLastBezelEnding release];
        dateOfLastBezelEnding = [[NSDate date] retain];
    }else if(didChangeTouchLoc && subState == UIGestureRecognizerStateChanged){
        subState = UIGestureRecognizerStateChanged;
    }
    
    if([validTouches count] == 0 && [ignoredTouches count] == 0){
        self.state = UIGestureRecognizerStateEnded;
    }else{
        self.state = UIGestureRecognizerStateChanged;
    }
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event{
    [self processSubStateForNextIteration];
    [ignoredTouches removeObjectsInSet:touches];
    [validTouches removeObjectsInSet:touches];
    if([validTouches count] < 2 && (subState == UIGestureRecognizerStateChanged || subState == UIGestureRecognizerStateBegan)){
        // we cancelled one of our two touches, so
        // tell our substate we're dead now
        subState = UIGestureRecognizerStateCancelled;
    }
    if([validTouches count] == 0 && subState == UIGestureRecognizerStateChanged){
        subState = UIGestureRecognizerStateCancelled;
        [dateOfLastBezelEnding release];
        dateOfLastBezelEnding = [[NSDate date] retain];
    }
    if([validTouches count] == 0 && [ignoredTouches count] == 0){
        self.state = UIGestureRecognizerStateEnded;
    }else{
        self.state = UIGestureRecognizerStateChanged;
    }
}
- (void)reset{
    [super reset];
    subState = UIGestureRecognizerStatePossible;
    liftedLeftFingerOffset = 0;
    panDirection = MMBezelDirectionNone;
    firstKnownLocation = CGPointZero;
    lastKnownLocation = CGPointZero;
    [validTouches removeAllObjects];
    [ignoredTouches removeAllObjects];
}
-(void) setState:(UIGestureRecognizerState)state{
    [super setState:state];
}
- (void) resetPageCount{
    numberOfRepeatingBezels = 0;
    [dateOfLastBezelEnding release];
    dateOfLastBezelEnding = nil;
}



/**
 * calculates the pixel velocity
 * per fraction of a second (1/20)
 * to helper determine how wide to make
 * the bezel
 *
 * since directionOfTouch is only updated
 * if the touch moves significantly, this
 * helps filter out very small direction changes
 */
-(CGFloat) directionOfTouchesInXAxis{
    // calculate the average X direction velocity
    // so we can determine how wide to make the bezel
    // exit of the gesture. this helps us work with
    // really fast bezelling without accidentally zooming
    // into list view or missing the bezel altogether
    int count = 0;
    CGPoint averageVelocity = CGPointZero;
    for(UITouch* touch in validTouches){
        struct DurationCacheObject cache = [[MMTouchVelocityGestureRecognizer sharedInstace] velocityInformationForTouch:touch withIndex:nil];
        averageVelocity.x = averageVelocity.x * count + cache.directionOfTouch.x;
        count += 1;
        averageVelocity.x /= count;
    }
    // calculate the pixels moved per 20th of a second
    // and add that to the bezel that we'll allow
    return averageVelocity.x; // velocity per fraction of a second
}


@end
