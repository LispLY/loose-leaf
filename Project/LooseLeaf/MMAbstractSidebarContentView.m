//
//  MMImageSidebarContentView.m
//  LooseLeaf
//
//  Created by Adam Wulf on 3/29/14.
//  Copyright (c) 2014 Milestone Made, LLC. All rights reserved.
//

#import "MMAbstractSidebarContentView.h"
#import "MMPhotoManager.h"
#import "MMAlbumRowView.h"
#import "MMBufferedImageView.h"
#import "MMImageSidebarContainerView.h"
#import "MMSinglePhotoCollectionViewCell.h"
#import "MMPermissionPhotosCollectionViewCell.h"
#import "MMEmptyCollectionViewCell.h"
#import "MMAlbumCell.h"
#import "MMAlbumListLayout.h"
#import "MMPhotoAlbumListLayout.h"
#import "MMRotationManager.h"
#import "Constants.h"
#import "NSThread+BlockAdditions.h"
#import "NSArray+Map.h"

@implementation MMAbstractSidebarContentView{
    NSMutableDictionary* currentRowForAlbum;
    MMEmptyCollectionViewCell* emptyView;
    
    CGPoint lastAlbumScrollOffset;
    CGPoint lastPhotoScrollOffset;
}

@synthesize delegate;
@synthesize isShowing;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        currentRowForAlbum = [NSMutableDictionary dictionary];
        albumListScrollView = [[UICollectionView alloc] initWithFrame:self.bounds collectionViewLayout:[self albumsLayout]];
        albumListScrollView.dataSource = self;
        albumListScrollView.delegate = self;
        
        [albumListScrollView registerClass:[MMAlbumCell class] forCellWithReuseIdentifier:@"MMAlbumCell"];
        
        photoListScrollView = [[UICollectionView alloc] initWithFrame:self.bounds collectionViewLayout:[self photosLayout]];
        photoListScrollView.dataSource = self;
        photoListScrollView.alpha = 0;
        photoListScrollView.backgroundColor = [UIColor clearColor];
        
        [photoListScrollView registerClass:[MMSinglePhotoCollectionViewCell class] forCellWithReuseIdentifier:@"MMSinglePhotoCollectionViewCell"];
        [photoListScrollView registerClass:[MMPermissionPhotosCollectionViewCell class] forCellWithReuseIdentifier:@"MMPermissionPhotosCollectionViewCell"];

        currentAlbum = nil;
        
        [self addSubview:albumListScrollView];
        [self addSubview:photoListScrollView];
        
        
        NSObject * transparent = (NSObject *) [[UIColor colorWithWhite:0 alpha:0] CGColor];
        NSObject * opaque = (NSObject *) [[UIColor colorWithWhite:0 alpha:1] CGColor];
        
        CALayer * maskLayer = [CALayer layer];
        maskLayer.frame = self.bounds;
        
        CAGradientLayer * gradientLayer = [CAGradientLayer layer];
        gradientLayer.frame = CGRectMake(self.bounds.origin.x, 0,
                                         self.bounds.size.width, self.bounds.size.height);
        
        gradientLayer.colors = [NSArray arrayWithObjects: transparent, opaque, nil];
        
        CGFloat fadePercentage = kTopBottomMargin / self.bounds.size.height;
        // Set percentage of scrollview that fades at top & bottom
        gradientLayer.locations = [NSArray arrayWithObjects:
                                   [NSNumber numberWithFloat:0],
                                   [NSNumber numberWithFloat:fadePercentage], nil];
        
        [maskLayer addSublayer:gradientLayer];
        self.layer.mask = maskLayer;

    }
    return self;
}

-(UICollectionViewLayout*) albumsLayout{
    return [[MMAlbumListLayout alloc] init];
}

-(UICollectionViewLayout*) photosLayout{
    return [[MMPhotoAlbumListLayout alloc] initForRotation:[self idealRotationForOrientation]];
}

-(CGFloat) rowHeight{
    return ceilf(self.bounds.size.width / 2);
}

-(void) updateEmptyErrorMessage{
    if(isShowing && ![self collectionView:albumListScrollView numberOfItemsInSection:0] && [MMPhotoManager hasPhotosPermission]){
        if(!emptyView){
            emptyView = [[MMEmptyCollectionViewCell alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.width)];
        }
        [self addSubview:emptyView];
        [emptyView updatePhotoRotation:NO];
    }else if(emptyView){
        [emptyView removeFromSuperview];
        emptyView = nil;
    }
}

-(void) reset:(BOOL)animated{
    albumListScrollView.alpha = 1;
    photoListScrollView.alpha = 0;
    [self updateEmptyErrorMessage];
}

-(void) show:(BOOL)animated{
    [self updateEmptyErrorMessage];
    [[MMPhotoManager sharedInstance] initializeAlbumCache];
    [self updatePhotoRotation:NO];
    isShowing = YES;
    albumListScrollView.contentOffset = lastAlbumScrollOffset;
}

-(void) hide:(BOOL)animated{
    lastAlbumScrollOffset = albumListScrollView.contentOffset;
    lastPhotoScrollOffset = photoListScrollView.contentOffset;
    isShowing = NO;
}

-(void) killMemory{
//    [albumListScrollView killMemory];
    if(![self isShowing]){
        // only clear the cache if its been a while (?)
        [photoListScrollView reloadData];
        [self updateEmptyErrorMessage];
        lastPhotoScrollOffset = CGPointZero;
        lastAlbumScrollOffset = CGPointZero;
    }
}

#pragma mark - MMPhotoManagerDelegate

-(void) doneLoadingPhotoAlbums{
    [self updateEmptyErrorMessage];
//    [albumListScrollView refreshVisibleRows];
//    [albumListScrollView enumerateVisibleRowsWithBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//        [self updateRow:obj atIndex:idx forFrame:[obj frame] forScrollView:albumListScrollView];
//    }];
    if(photoListScrollView.alpha){
        [photoListScrollView reloadData];
        photoListScrollView.contentOffset = lastPhotoScrollOffset;
    }
}

-(void) albumUpdated:(MMPhotoAlbum *)album{
    NSInteger index = [self indexForAlbum:album];
//    if([albumListScrollView rowIndexIsVisible:index]){
//        MMAlbumRowView* row = (MMAlbumRowView*) [albumListScrollView rowAtIndex:index];
//        [row loadedPreviewPhotos];
//    }
}

#pragma mark - Row Management

-(NSInteger) indexForAlbum:(MMPhotoAlbum*)album{
    @throw kAbstractMethodException;
}

-(MMPhotoAlbum*) albumAtIndex:(NSInteger)index{
    @throw kAbstractMethodException;
}


#pragma mark - Rotation

-(CGFloat) idealRotationForOrientation{
    CGFloat visiblePhotoRotation = 0;
    UIInterfaceOrientation orient = [[MMRotationManager sharedInstance] lastBestOrientation];
    if(orient == UIInterfaceOrientationLandscapeRight){
        visiblePhotoRotation = M_PI / 2;
    }else if(orient == UIInterfaceOrientationPortraitUpsideDown){
        visiblePhotoRotation = M_PI;
    }else if(orient == UIInterfaceOrientationLandscapeLeft){
        visiblePhotoRotation = -M_PI / 2;
    }else{
        visiblePhotoRotation = 0;
    }
    return visiblePhotoRotation;
}

-(void) updatePhotoRotation:(BOOL)animated{
    void(^updateVisibleRowsWithRotation)() = ^{
        if(albumListScrollView.alpha){
//            [albumListScrollView enumerateVisibleRowsWithBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//                if([obj respondsToSelector:@selector(updatePhotoRotation)]){
//                    [obj updatePhotoRotation];
//                }
//            }];
        }
    };
    
    if(animated){
        [[NSThread mainThread] performBlock:^{
            [photoListScrollView reloadData];
            [photoListScrollView setCollectionViewLayout:[[MMPhotoAlbumListLayout alloc] initForRotation:[self idealRotationForOrientation]] animated:YES];
            [UIView animateWithDuration:.3 animations:updateVisibleRowsWithRotation];
        }];
    }else{
        [[NSThread mainThread] performBlock:^{
            [photoListScrollView reloadData];
            [photoListScrollView setCollectionViewLayout:[[MMPhotoAlbumListLayout alloc] initForRotation:[self idealRotationForOrientation]] animated:NO];
            updateVisibleRowsWithRotation();
        }];
    }
    [emptyView updatePhotoRotation:animated];
}

-(NSString*) description{
    @throw kAbstractMethodException;
}



#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    if(collectionView == albumListScrollView){
        return 0;
    }else{
        // we're only working with the photoListScrollView. there's no albums here
        if([MMPhotoManager hasPhotosPermission]){
            return currentAlbum.numberOfPhotos;
        }else{
            return 1;
        }
    }
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    return isShowing ? 1 : 0;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    if(collectionView == albumListScrollView){
        MMAlbumCell* albumCell = [collectionView dequeueReusableCellWithReuseIdentifier:@"MMAlbumCell" forIndexPath:indexPath];
//        [photoCell loadPhotoFromAlbum:currentAlbum atIndex:indexPath.row forVisibleIndex:indexPath.row];
//        photoCell.delegate = self;
        return albumCell;
    }else{
        if([MMPhotoManager hasPhotosPermission]){
            MMSinglePhotoCollectionViewCell* photoCell = [collectionView dequeueReusableCellWithReuseIdentifier:@"MMSinglePhotoCollectionViewCell" forIndexPath:indexPath];
            [photoCell loadPhotoFromAlbum:currentAlbum atIndex:indexPath.row forVisibleIndex:indexPath.row];
            photoCell.delegate = self;
            return photoCell;
        }else{
            MMPermissionPhotosCollectionViewCell* permission = [collectionView dequeueReusableCellWithReuseIdentifier:@"MMPermissionPhotosCollectionViewCell" forIndexPath:indexPath];
            permission.shouldShowLine = NO;
            [permission showPhotosSteps];
            return permission;
        }
    }
}

#pragma mark - MMSinglePhotoCollectionViewCellDelegate

-(void) pictureTakeWithCamera:(UIImage*)img fromView:(MMBorderedCamView*)cameraView{
    [delegate pictureTakeWithCamera:img fromView:cameraView];
}

-(void) photoWasTapped:(MMPhoto *)asset
              fromView:(MMBufferedImageView *)bufferedImage
          withRotation:(CGFloat)rotation{
    MMPhotoAlbumListLayout* layout = (MMPhotoAlbumListLayout*) photoListScrollView.collectionViewLayout;
    [delegate photoWasTapped:asset fromView:bufferedImage withRotation:(rotation + layout.rotation) fromContainer:self];
}


#pragma mark - UICollectionViewDelegate

-(void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    if(collectionView == albumListScrollView){
        [self setUserInteractionEnabled:NO];
//        currentAlbum = row.album;
        photoListScrollView.contentOffset = CGPointZero;
        
        [photoListScrollView reloadData];
        
        [UIView animateWithDuration:.3 animations:^{
            albumListScrollView.alpha = 0;
            photoListScrollView.alpha = 1;
        }  completion:^(BOOL finished){
            [self setUserInteractionEnabled:YES];
        }];
    }
}


@end
