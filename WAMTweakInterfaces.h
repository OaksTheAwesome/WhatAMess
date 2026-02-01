
@interface CKConversationListCollectionViewController : UICollectionViewController
-(void)updateBackground;
-(void)makeSubviewsTransparent:(UIView *)view;
- (void)applyCustomColorsToCKLabelsInView:(UIView *)view;
@end

@interface CKTranscriptCollectionViewController : UIViewController
@end

@interface CKGradientReferenceView : UIView
@end

@interface CKMessagesController : UIViewController
@end

@interface _UIBarBackground : UIView
- (void)createOurBlur;
- (void)removeSystemViews;
- (void)ensureBlurExists;
- (BOOL)findContactViewInWindow:(UIView *)view;
@end

@interface _UICollectionViewListSeparatorView : UIView
@end

@interface _UISearchBarSearchFieldBackgroundView : UIView
@end

@interface CKPinnedConversationView : UIView
@end

@class CKConversationListCollectionViewController;

@interface _UINavigationBarTitleControl : UIControl
@end

@interface _UIVisualEffectBackdropView : UIView
@end

@interface UIView (Private)
- (UIViewController *)_viewControllerForAncestor;
@end

@interface CKLabel : UILabel
@end

@interface UIDateLabel : UILabel
@end

@interface CKDateLabel : UIDateLabel
@end

@interface CKConversationListCollectionViewConversationCell : UICollectionViewCell
@end

@interface CKGradientView : UIView
- (void)setColors:(NSArray *)colors;
- (NSArray *)colors;
- (BOOL)isInsideReactionBubble;
- (void)applyColorRecursively:(UIColor *)color;
@end

@interface CKBalloonImageView : UIImageView
@property (nonatomic, strong) UIImage *image;
@end

@interface CKColoredBalloonView : UIView
@property (nonatomic, assign) int color;
@end

@interface CKBalloonTextView : UITextView
- (void)updateTextColorForBalloon;
- (UIColor *)getCustomTextColor;
@end

@interface CKTranscriptStatusCell : UICollectionViewCell
@end

@interface CKTranscriptLabelCell : UICollectionViewCell
@end

@interface _UIVisualEffectContentView : UIView
@end

@interface _UIVisualEffectSubview : UIView
@end

@interface CKMessageEntryView : UIView
- (void)applyInputFieldCustomization;
- (UITextView *)findTextView:(UIView *)view;
- (UIView *)findRoundedView:(UIView *)view;
- (UIView *)findViewByClassName:(UIView *)view;
@end

@interface UIKBVisualEffectView : UIVisualEffectView
@end

@interface CKMessageEntryRichTextView : UITextView
@end

@interface CKEntryViewButton : UIView
@end

@interface CKDetailsTableView : UITableView
@end

@interface _UITableViewHeaderFooterContentView : UIView
@end

@interface CNGroupIdentityHeaderContainerView : UIView
- (void)applyContactNameColor;
@end

@interface CKGroupPhotoCell : UIView
@end

@interface CNActionView : UIView
- (void)matchIconToLabelAlpha;
- (void)updateIconOpacity;
@end

@interface CKTranscriptDetailsResizableCell : UICollectionViewCell
@end

@interface CKDetailsSharedWithYouCell : UITableViewCell
@end

@interface CKDetailsChatOptionsCell : UITableViewCell
@end

@interface CKBackgroundDecorationView : UICollectionReusableView
@end

@interface CKRecipientSelectionView : UIView
- (void)updateRecipientBackground;
@end

@interface CKComposeRecipientView : UIView
@end

@interface UITableViewLabel : UILabel
@end

@interface CKQuickActionSaveButton : UIView
@end

@interface UIButtonLabel : UILabel
@end

@interface _UIPlatterClippingView : UIView
@end

@interface _UISystemBackgroundView : UIView
@end

@interface CKTranscriptReportSpamCell : UIView
- (void)colorReportJunkButton:(UIView *)view withColor:(UIColor *)color;
@end

@interface CKThumbsUpAcknowledgmentGlyphView : UIView
@end

@interface CKAggregateAcknowledgementBalloonView : UIView
- (void)applyGlyphTintRecursively:(UIView *)view;
@end

@interface CKAcknowledgmentGlyphImageView : UIView
@property (nonatomic, strong) UIColor *tintColor;
- (void)setImage:(UIImage *)image;
@end

@interface CKTranscriptUnavailabilityIndicatorCell : UICollectionViewCell
- (void)applyColorToUnavailabilityIndicator:(UIView *)view withColor:(UIColor *)color;
- (void)applyColorToUnavailabilityIndicator:(UIView *)view withColor:(UIColor *)color;
@end

@interface CKSendMenuPresentationPopoverBackdropView : UIView
@end

@interface CKSearchCollectionView : UICollectionView
@end

@interface UINavigationButton : UIView
@end

@interface _UINavigationBarLargeTitleView : UIView
@end

@interface UIViewControllerWrapperView : UIView
@end

@interface CKTranscriptNotifyAnywayButtonCell : UICollectionViewCell
@end

@interface CKEntryViewBlurrableButtonContainer : UIView
@end

@interface LPFlippedView : UIView
@end

@interface LPTextView : UIView
@end

@interface LPImageView : UIView
@end

@interface CKDetailsSearchResultsTitleHeaderCell : UIView
@end

@interface CKSearchResultsTitleHeaderCell : UIView
@end

@interface CKAvatarTitleCollectionReusableView : UIView
@end

@interface CKMessageAcknowledgmentPickerBarView: UIView
@end

@interface CKPinnedConversationSummaryBubble : UIView
@end

@interface CNContactView : UIView
@end

@interface UITableViewWrapperView : UIView
@end

@interface CNContactHeaderDisplayView : UIView
@end

@interface CNContactActionsContainerView : UIView
@end

@interface CKMessageAcknowledgmentPickerBarItemViewPhone : UIView
@end

@interface CKCanvasBackButtonView : UIView
@end

@interface CKPinnedConversationTypingBubble : UIView
@end

@interface CKConversationListTypingIndicatorView : UIView
@end

@interface CKTypingView : UIView
- (void)applyTypingIndicatorColors;
@end