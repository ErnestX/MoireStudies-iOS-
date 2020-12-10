//
//  SliderControlView.m
//  MoireStudies
//
//  Created by Jialiang Xiang on 2020-12-08.
//

#import "SliderControlView.h"

@implementation SliderControlView {
    
}

- (UIView*) instanceFromNib {
    return (UIView*)[[UINib nibWithNibName:@"SliderControlView" bundle:nil]instantiateWithOwner:nil options:nil].firstObject;
}

- (id) initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        UIView* view = [self instanceFromNib];
        view.frame = self.frame;
        [self addSubview:view];
    }
    return self;
}

@end
