#import "WAMBannerCell.h"

@implementation WAMBannerCell

- (instancetype)initWithSpecifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"WAMBannerCell" specifier:specifier];
    
    _height = ((NSNumber *)specifier.properties[@"height"]).floatValue ?: 200.0f;
    
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    if (!_bannerImageView) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        UIImage *bannerImage = [UIImage imageNamed:@"WAMHeader" inBundle:bundle compatibleWithTraitCollection:nil];
        
        _bannerImageView = [[UIImageView alloc] initWithImage:bannerImage];
        _bannerImageView.contentMode = UIViewContentModeScaleAspectFill;
        _bannerImageView.clipsToBounds = YES;
        _bannerImageView.backgroundColor = [UIColor redColor];
        
        [self.contentView addSubview:_bannerImageView];
    }
    
    _bannerImageView.frame = CGRectMake(0, 0, self.contentView.bounds.size.width, _height ?: 200.0f);
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width {
    return _height ?: 200.0f;
}

@end