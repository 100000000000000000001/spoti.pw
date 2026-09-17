// The Redesign page: a switch per redesigned screen and whatever rows a screen registers under it,
// the row on the root page of Mod Settings that opens it, and the note the legacy pages lead with
// while their screen is redesigned. Main thread only.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "SGRedesign.h"

typedef struct {
    __unsafe_unretained NSString *screen;
    __unsafe_unretained NSString *title;
    __unsafe_unretained NSString *subtitle;
    __unsafe_unretained NSString *symbol;
} SGRScreenRow;

// Spelled out in full rather than built from the screen's name: the page reads like the rest of Mod
// Settings, and a screen without a line here has no switch to show yet.
static const SGRScreenRow kRows[] = {
    {@"player", @"Player", @"The cover's own colour behind the whole player, glass behind the header buttons, and only the lyrics card below it", @"play.circle"},
    {@"artist", @"Artist", @"The photo across the full width fading into its colour, glass Play, Shuffle and Follow, and only the music below", @"music.mic"},
};

static const SGRScreenRow *rowFor(NSString *screen) {
    for (size_t i = 0; i < sizeof(kRows) / sizeof(kRows[0]); i++) {
        if ([kRows[i].screen isEqualToString:screen]) return &kRows[i];
    }
    return NULL;
}

static NSMutableDictionary<NSString *, NSArray<SGModRow *> *(^)(void)> *sg_extraRows;

void SGRedesignRegisterRows(NSString *screen, NSArray<SGModRow *> *(^rows)(void)) {
    if (!screen || !rows) return;
    if (!sg_extraRows) sg_extraRows = [NSMutableDictionary dictionary];
    sg_extraRows[screen] = [rows copy];
}

static NSUInteger countOn(void) {
    NSUInteger on = 0;
    for (NSString *screen in SGRedesignScreens()) {
        if (SGFlag([SGKeyRedesignPrefix stringByAppendingString:screen], NO)) on++;
    }
    return on;
}

UIViewController *SGRedesignSettingsPage(void) {
    NSMutableArray<SGModRow *> *switches = [NSMutableArray array];
    NSMutableArray<SGModSection *> *extras = [NSMutableArray array];
    for (NSString *screen in SGRedesignScreens()) {
        const SGRScreenRow *row = rowFor(screen);
        if (!row) continue;
        [switches addObject:SGWithSymbol(SGOptionRow(row->title, row->subtitle, [SGKeyRedesignPrefix stringByAppendingString:screen]), row->symbol)];
        NSArray<SGModRow *> *(^rows)(void) = sg_extraRows[screen];
        NSArray<SGModRow *> *more = rows ? rows() : nil;
        if (more.count) [extras addObject:SGSection(row->title, more)];
    }
    NSArray<SGModSection *> *sections = [@[
        SGNotedSection(@"Screens", switches, @"A redesigned screen replaces Spotify's own layout, so the switches for it on its part's page stop applying until it is off again."),
    ] arrayByAddingObjectsFromArray:extras];
    return [[SGModPage alloc] initWithTitle:@"Redesign" intro:SGRestartNote sections:sections footer:nil];
}

SGModSection *SGRedesignSection(void) {
    SGModRow *row = SGWithSymbol(SGPageRow(@"Redesign", ^UIViewController *{ return SGRedesignSettingsPage(); }), @"sparkles");
    row.value = ^NSString *{
        NSUInteger on = countOn();
        return on ? [NSString stringWithFormat:@"%lu of %lu", (unsigned long)on, (unsigned long)SGRedesignScreens().count] : @"Off";
    };
    return SGSection(nil, @[row]);
}

SGModSection *SGRedesignNoteSection(NSString *screen) {
    const SGRScreenRow *screenRow = rowFor(screen);
    if (!screenRow || !SGFlag([SGKeyRedesignPrefix stringByAppendingString:screen], NO)) return nil;
    SGModRow *row = SGPageRow([NSString stringWithFormat:@"%@ redesign is on", screenRow->title], ^UIViewController *{ return SGRedesignSettingsPage(); });
    row.subtitle = @"Its own layout replaces Spotify's, so the switches below that change this screen don't apply";
    return SGSection(nil, @[SGWithSymbol(row, @"sparkles")]);
}
