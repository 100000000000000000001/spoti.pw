// Home redesign: a shelf's heading at the Music app's size, the title 2 style in bold (22pt at the default
// text size) over Spotify's 17pt. The title is a label of the Kit's own on the same baseline, drawn over
// Spotify's, which goes transparent: Spotify's label measures the heading, so the shelf keeps its layout,
// and the heading button keeps its touch and its accessibility label. The larger title reaches a few
// points up into the gap above the shelf. A small line over the title ("For fans of") and the artist's
// picture beside it stay Spotify's.
//
// Tree (trees/continuous/1.txt:2289-2312, 2026-09-17): Element_List.SupplementaryItemView 370x48 >
// ... > UIView id=Components.UI.SectionHeadingHome > AutoLayoutStackView > UIView > NoIntrinsicContentSizeButton
// (a11y "For fans of  Yzomandias"), under which an ImageViewHolder 48x48 and a stack of SPTEncoreLabels:
// "For fans of " 11pt #B3B3B3, "Yzomandias" 17pt #FFFFFF at {0, 19.3} 91x20.7, and a hidden one. A heading
// of a title alone is 20.7 tall (10.txt:2363). "Show all" is Components.UI.NavigationButtonHome, a sibling
// of the button's stack, 0 wide while it is not offered.
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Home.h"

static char kTitleKey, kShowAllKey;

static UIView *headingAround(UIView *button) {
    NSUInteger depth = 0;
    for (UIView *v = button.superview; v && depth < 4; v = v.superview, depth++) {
        if ([v.accessibilityIdentifier isEqualToString:@"Components.UI.SectionHeadingHome"]) return v;
    }
    return nil;
}

static BOOL shown(UIView *view, UIView *root) {
    for (UIView *v = view; v && v != root; v = v.superview) {
        if (v.hidden) return NO;
    }
    return YES;
}

// The label that is the title: the largest text showing under the button, its own label aside.
static UILabel *titleLabelIn(UIView *button, UILabel *mine) {
    __block UILabel *title = nil;
    SGForEachView(button, ^(UIView *v) {
        if (v == mine || ![v isKindOfClass:UILabel.class]) return;
        UILabel *label = (UILabel *)v;
        if (!label.text.length || label.bounds.size.height < 1 || !shown(label, button)) return;
        if (!title || label.font.pointSize > title.font.pointSize) title = label;
    });
    return title;
}

static void restyle(UIView *button) {
    UIView *heading = headingAround(button);
    if (!heading) return;
    UILabel *mine = objc_getAssociatedObject(button, &kTitleKey);
    UILabel *theirs = titleLabelIn(button, mine);
    if (!theirs) {
        mine.hidden = YES;
        return;
    }
    if (!mine) {
        mine = [UILabel new];
        mine.userInteractionEnabled = NO;
        mine.accessibilityElementsHidden = YES;
        mine.lineBreakMode = NSLineBreakByTruncatingTail;
        objc_setAssociatedObject(button, &kTitleKey, mine, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (mine.superview != button) [button addSubview:mine];
    mine.hidden = NO;

    UIFont *font = SGRFont(UIFontTextStyleTitle2, UIFontWeightBold, UIContentSizeCategoryLarge);
    if (![mine.font isEqual:font]) mine.font = font;
    if (![mine.text isEqualToString:theirs.text]) mine.text = theirs.text;
    if (![mine.textColor isEqual:theirs.textColor]) mine.textColor = theirs.textColor;
    if (theirs.alpha != 0) theirs.alpha = 0;

    // Spotify's label centres its one line in its bounds.
    CGRect frame = [theirs convertRect:theirs.bounds toView:button];
    UIFont *spotify = theirs.font;
    CGFloat baseline = CGRectGetMinY(frame) + (frame.size.height - spotify.lineHeight) / 2 + spotify.ascender;
    CGFloat x = CGRectGetMinX(frame);
    CGFloat available = heading.bounds.size.width - [button convertPoint:CGPointMake(x, 0) toView:heading].x;
    UIView *showAll = SGRFindByIdentifier(heading, @"Components.UI.NavigationButtonHome", &kShowAllKey);
    if (showAll.bounds.size.width > 1 && shown(showAll, heading)) available -= showAll.bounds.size.width + SGRGrid;
    CGFloat width = MIN(ceil([mine sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)].width), MAX(0, available));
    CGRect target = CGRectMake(x, round(baseline - font.ascender), width, ceil(font.lineHeight));
    if (!CGRectEqualToRect(mine.frame, target)) mine.frame = target;

    static dispatch_once_t once;
    dispatch_once(&once, ^{ SGLog(@"redesign home: heading \"%@\" %.0fpt drawn at %.0fpt, %@", theirs.text, spotify.pointSize, font.pointSize, NSStringFromCGRect(target)); });
}

%hook _TtCOOOE11Home_ECMKitO19LegacyUI_ECMCoreKit10Components18SectionHeadingHome2UI7Private28NoIntrinsicContentSizeButton
- (void)layoutSubviews {
    %orig;
    CFTimeInterval began = SGRHomeProbeBegin();
    restyle((UIView *)self);
    SGRHomeProbeEnd(SGRHomeProbeHeadings, began);
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    SGRequireClasses(@[@"_TtCOOOE11Home_ECMKitO19LegacyUI_ECMCoreKit10Components18SectionHeadingHome2UI7Private28NoIntrinsicContentSizeButton"]);
}
