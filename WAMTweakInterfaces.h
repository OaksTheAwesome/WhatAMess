@interface CKConversationListCollectionViewController : UICollectionViewController
-(void)updateBackground;
-(void)makeSubviewsTransparent:(UIView *)view;
-(void)applyCustomColorsToCKLabelsInView:(UIView *)view;
-(void)handlePrefsChanged;
-(void)updateAllColors;
@end

@interface CKTranscriptCollectionViewController : UIViewController
@end

@interface CKGradientReferenceView : UIView
@end

@interface CKMessagesController : UIViewController
-(void)updateChatBackground;
-(void)handlePrefsChanged;
- (NSArray *)getAllSubviews:(UIView *)view;
-(void)forceRedrawCell:(UIView *)view;
@end

@interface _UIBarBackground : UIView
-(void)createOurBlur;
-(void)removeSystemViews;
-(void)ensureBlurExists;
-(BOOL)findContactViewInWindow:(UIView *)view;
@end

@interface _UICollectionViewListSeparatorView : UIView
@end

@interface _UISearchBarSearchFieldBackgroundView : UIView
@end

@interface CKPinnedConversationView : UIView
-(void)applyPinnedGlow;
@end

@class CKConversationListCollectionViewController;

@interface _UINavigationBarTitleControl : UIControl
@end

@interface _UIVisualEffectBackdropView : UIView
@end

@interface UIView (Private)
-(UIViewController *)_viewControllerForAncestor;
@end

@interface CKLabel : UILabel
@end

@interface UIDateLabel : UILabel
@end

@interface CKDateLabel : UIDateLabel
@end

@interface CKConversationListCollectionViewConversationCell : UICollectionViewCell
-(void)applyScreenshotMode;
@end

@interface CKGradientView : UIView
-(void)setColors:(NSArray *)colors;
-(NSArray *)colors;
-(BOOL)isInsideReactionBubble;
-(void)applyColorRecursively:(UIColor *)color;
@end

@interface CKBalloonImageView : UIImageView
@property (nonatomic, strong) UIImage *image;
@end

@interface CKColoredBalloonView : UIView
@property (nonatomic, assign) int color;
@end

@interface CKBalloonTextView : UITextView
-(void)updateTextColorForBalloon;
-(UIColor *)getCustomTextColor;
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
-(void)applyInputFieldCustomization;
-(UITextView *)findTextView:(UIView *)view;
-(UIView *)findRoundedView:(UIView *)view;
-(UIView *)findViewByClassName:(UIView *)view;
@end

@interface UIKBVisualEffectView : UIVisualEffectView
@end

@interface CKMessageEntryRichTextView : UITextView
- (void)handlePrefsChanged;
@end

@interface CKEntryViewButton : UIView
-(void)handleButtonPrefsChanged;
@end

@interface CKDetailsTableView : UITableView
-(void)updateDetailsBackground;
@end

@interface _UITableViewHeaderFooterContentView : UIView
@end

@interface CNGroupIdentityHeaderContainerView : UIView
-(void)applyContactNameColor;
@end

@interface CKGroupPhotoCell : UIView
@end

@interface CNActionView : UIView
-(void)matchIconToLabelAlpha;
-(void)updateIconOpacity;
-(void)applyActionViewBlur;
@end

@interface CKTranscriptDetailsResizableCell : UICollectionViewCell
-(void)applyBlurStyle;
@end

@interface CKDetailsSharedWithYouCell : UITableViewCell
-(void)applyBlurStyle;
@end

@interface CKDetailsChatOptionsCell : UITableViewCell
-(void)applyBlurStyle;
@end

@interface CKBackgroundDecorationView : UICollectionReusableView
-(void)applyBlurStyle;
@end

@interface CKRecipientSelectionView : UIView
-(void)updateRecipientBackground;
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
-(void)applyPlatterBackground;
@end

@interface _UISystemBackgroundView : UIView
@end

@interface CKTranscriptReportSpamCell : UIView
-(void)colorReportJunkButton:(UIView *)view withColor:(UIColor *)color;
@end

@interface CKThumbsUpAcknowledgmentGlyphView : UIView
@end

@interface CKAggregateAcknowledgementBalloonView : UIView
-(void)applyGlyphTintRecursively:(UIView *)view;
@end

@interface CKAcknowledgmentGlyphImageView : UIView
@property (nonatomic, strong) UIColor *tintColor;
-(void)setImage:(UIImage *)image;
@end

@interface CKTranscriptUnavailabilityIndicatorCell : UICollectionViewCell
-(void)applyColorToUnavailabilityIndicator:(UIView *)view withColor:(UIColor *)color;
@end

@interface CKSendMenuPresentationPopoverBackdropView : UIView
-(UIColor *)adjustedTintColor:(UIColor *)customTint;
-(void)applyMenuBackdropColor;
@end

@interface CKSearchCollectionView : UICollectionView
-(void)applySearchBackground;
@end

@interface UINavigationButton : UIView
@end

@interface _UINavigationBarLargeTitleView : UIView
-(void)applyLargeTitleStyle;
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
-(void)applyLinkTextColors;
@end

@interface LPImageView : UIView
@end

@interface CKDetailsSearchResultsTitleHeaderCell : UIView
-(void)applyHeaderStyle;
@end

@interface CKSearchResultsTitleHeaderCell : UIView
-(void)applyHeaderStyle;
@end

@interface CKAvatarTitleCollectionReusableView : UIView
@end

@interface CKMessageAcknowledgmentPickerBarView : UIView
@end

@interface CKPinnedConversationSummaryBubble : UIView
-(void)applyPinnedBubbleStyle;
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
-(void)applyTypingBubbleColors;
@end

@interface CKConversationListTypingIndicatorView : UIView
-(void)applyTypingIndicatorColors;
@end

@interface CKTypingView : UIView
-(void)applyTypingIndicatorColors;
@end

// Category declarations for system classes with added methods
@interface UISearchTextField (WAMTweakAdditions)
-(void)applySearchFieldTint;
@end

@interface UITableViewCell (WAMTweakAdditions)
-(void)applyContactCellBlur;
@end