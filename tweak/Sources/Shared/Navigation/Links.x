// The dispatcher is a singleton the app builds at startup; -setMainUILoaded: is the last call of its
// setup (objc-methods.txt:38809).
#import "Core/SGCore.h"
#import "Headers/SPTLinkDispatcherImplementation.h"
#import "Links.h"

static __weak SPTLinkDispatcherImplementation *sg_linkDispatcher;

id SGLinkDispatcher(void) {
    return sg_linkDispatcher;
}

BOOL SGOpenSpotifyURI(NSURL *uri) {
    SPTLinkDispatcherImplementation *dispatcher = sg_linkDispatcher;
    if (!uri || ![dispatcher respondsToSelector:@selector(navigateToURI:options:interactionID:)]) return NO;
    [dispatcher navigateToURI:uri options:0 interactionID:nil];
    return YES;
}

%hook SPTLinkDispatcherImplementation
- (void)setMainUILoaded:(BOOL)loaded {
    %orig;
    sg_linkDispatcher = (SPTLinkDispatcherImplementation *)self;
}
%end

%ctor {
    %init;
    SGRequireClasses(@[@"SPTLinkDispatcherImplementation"]);
}
