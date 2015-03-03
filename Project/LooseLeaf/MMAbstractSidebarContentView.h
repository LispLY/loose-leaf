//
//  MMImageSidebarContentView.h
//  LooseLeaf
//
//  Created by Adam Wulf on 3/29/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MMSlidingSidebarContainerViewDelegate.h"
#import "MMPhotoManagerDelegate.h"
#import "MMAlbumRowViewDelegate.h"
#import "MMSinglePhotoCollectionViewCellDelegate.h"

#define kTopBottomMargin 20

@class MMImageSidebarContainerView;

@interface MMAbstractSidebarContentView : UIView<UICollectionViewDataSource,MMSinglePhotoCollectionViewCellDelegate,MMPhotoManagerDelegate,UICollectionViewDelegate>{
    MMPhotoAlbum* currentAlbum;
    UICollectionView* albumListScrollView;
    UICollectionView* photoListScrollView;
    __weak MMImageSidebarContainerView* delegate;
    BOOL isShowing;
}

@property (nonatomic, weak) MMImageSidebarContainerView* delegate;
@property (nonatomic, readonly) BOOL isShowing;
@property (readonly) CGFloat rowHeight;

-(void) reset:(BOOL)animated;

-(void) show:(BOOL)animated;

-(void) hide:(BOOL)animated;

-(void) killMemory;

-(void) updatePhotoRotation:(BOOL)animated;

// abstract

-(NSInteger) indexForAlbum:(MMPhotoAlbum*)album;

-(MMPhotoAlbum*) albumAtIndex:(NSInteger)index;

-(UICollectionViewLayout*) photosLayout;

@end
