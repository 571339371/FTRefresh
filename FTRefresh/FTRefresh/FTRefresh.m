//
//  FTRefresh.m
//  wsMaijia
//
//  Created by Stubble on 2018/12/10.
//  Copyright © 2018 Stubble. All rights reserved.
//

#import "FTRefresh.h"
#import "FTRefreshHeaderView.h"

#define FTRefreshViewH 80.0
#define screenH [UIScreen mainScreen].bounds.size.height
#define screenW [UIScreen mainScreen].bounds.size.width

// 控件的刷新状态
typedef enum {
    FTRefreshStateNormal = 1, // 普通状态
    FTRefreshStateRefreshing = 2, // 正在刷新中的状态
}FTRefreshState;


@interface FTRefresh()

@property(weak,nonatomic)FTRefreshHeaderView* header;

// 父控件一开始的contentInset
@property (assign, nonatomic)UIEdgeInsets scrollViewInitInset;
@property (assign, nonatomic)FTRefreshState state;
@property (assign, nonatomic)float iconScale;
@property (assign, nonatomic)CGFloat lastOffset;
@property (assign, nonatomic)BOOL refreshing;

@end

@implementation FTRefresh

-(void)free{
    // 移除之前的监听器
    [_scrollview removeObserver:self forKeyPath:@"contentOffset" context:nil];
    _scrollview  = nil;
    [self removeFromSuperview];
}

-(instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        _header = [FTRefreshHeaderView view];
        _state = FTRefreshStateNormal;
        _iconScale = 0.0;
        _refreshing = false;
        [self addSubview:_header];
    }
    return self;
}

-(void)setScrollview:(UIScrollView *)scrollview{
    _scrollview = scrollview;
    _scrollViewInitInset = scrollview.contentInset;
    _header.frame = CGRectMake(0.0,0.0,screenW,FTRefreshBGViewHeight);
    self.frame = CGRectMake(0.0,-FTRefreshBGViewHeight,screenW,FTRefreshBGViewHeight);
    // 监听contentOffset
    [_scrollview addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
    [_scrollview addSubview:self];
}


/**
 开始奔跑动画
 */
-(void)startAnimate{
    
    if ([_header.icon isAnimating])return;
    
    [_header.prompt setText:@"松手更新..."];
//    NSMutableArray  *arrayM=[NSMutableArray array];
//    for (int i=1; i<3; i++) {
//        [arrayM addObject:[UIImage imageNamed:[NSString stringWithFormat:@"pulldown%d",i]]];
//    }
//    //设置动画数组
//    [_header.icon setAnimationImages:arrayM];
//    //设置动画播放次数
//    [_header.icon setAnimationRepeatCount:0];
//    //设置动画播放时间
//    [_header.icon setAnimationDuration:3*0.075];
//    //开始动画
//    [_header.icon startAnimating];
//    NSLog(@"播放动画...");
}


-(void)setState:(FTRefreshState)state{
    
    if (_state == state)return;
    
    switch (state) {
        case FTRefreshStateNormal:
            if ([_header.icon isAnimating]) {
                [_header.icon stopAnimating];
                [_header.prompt setText:@"下拉更新..."];
            }
            break;
        case FTRefreshStateRefreshing:
            _refreshing = true;
            [self startAnimate];//开始进入动画
            break;
        default:
            break;
    }
    
    _state = state;
}


/**
 开始刷新
 */
-(void)beginRefresh{
    // 1.增加滚动区域
    UIEdgeInsets inset = _scrollview.contentInset;
    inset.top = _scrollViewInitInset.top + FTRefreshViewH;
    _scrollview.contentInset = inset;
    // 2.设置滚动位置
    _scrollview.contentOffset = CGPointMake(0,-_scrollViewInitInset.top - FTRefreshViewH);
    [_header.prompt setText:@"更新中..."];
    if (_isAutoEnd) {
        [self performSelector:@selector(hide) withObject:self afterDelay:(_refreshTime>=0)?_refreshTime:(-_refreshTime)];
    }
    if (self.startBlock) {
        self.startBlock();
    }
}
/**
 刷新完毕隐藏
 */
-(void)hide{
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:.3];
    [_scrollview setContentInset:UIEdgeInsetsMake(0, 0.0f, 0.0f, 0.0f)];
    [UIView commitAnimations];
    [self setState:FTRefreshStateNormal];
    
    self.iconScale = 0.0;
    if (self.endBlock) {
        self.endBlock();
    }
}
/**
 设置图片大小
 */
-(void)setIconScale:(float)iconScale{
    _iconScale = iconScale;
    if (![_header.icon isAnimating]) {
        [UIView animateWithDuration:0.1 animations:^{
            [_header.icon setTransform:CGAffineTransformMakeScale(iconScale,iconScale)];
        }];
    }
    //NSLog(@"scale = %f",iconScale);
}
#pragma mark 监听UIScrollView的contentOffset属性
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ((![@"contentOffset" isEqualToString:keyPath]) || (_scrollview.contentOffset.y>0))return;
    if (!_scrollview.isDragging && (_state==FTRefreshStateRefreshing)){//松开进入刷新
        if (_refreshing) {
            _refreshing = false;
            [self beginRefresh];//松手则开始刷新
        }
        return;
    }
    
    CGFloat offsetY = _scrollview.contentOffset.y;
    CGFloat validY = _scrollViewInitInset.top;
    if (_scrollview.isDragging) {
        CGFloat validOffsetY = validY - FTRefreshViewH;
        if (offsetY > validOffsetY) {
            
            if ((_lastOffset-_scrollview.contentOffset.y)>0.0) {//向下
                if (self.iconScale < 1) {
                    self.iconScale = sin((((-_scrollview.contentOffset.y))/FTRefreshViewH)*0.5*M_PI);
                    if (self.iconScale >= 0.98) {
                        [self setState:FTRefreshStateRefreshing];
                    }
                }
            }else{//向上
                self.iconScale = sin((((-_scrollview.contentOffset.y))/FTRefreshViewH)*0.5*M_PI);
                if (self.iconScale>0.0 && self.iconScale <= 0.98) {
                    [self setState:FTRefreshStateNormal];
                }
            }
            self.header.iconBottom.constant = self.iconScale + 5;
        }
    }else{
        [self setState:FTRefreshStateNormal];
        self.iconScale = 0.0;
        self.header.iconBottom.constant = 30;
    }
    _lastOffset = _scrollview.contentOffset.y;
    // NSLog(@"contentoffset = %f, scale = %f",_scrollview.contentOffset.y,sin((((-_scrollview.contentOffset.y))/FTRefreshViewH)*0.5*M_PI));
}



@end
