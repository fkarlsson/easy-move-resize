#import <Cocoa/Cocoa.h>

// these intervals feel good in experimentation, but maybe in the future we can measure how long
// the move and resize increments are actually taking and adjust them dynamically for each move/resize?
static const double kMoveFilterInterval = 0.02;
static const double kResizeFilterInterval = 0.04;

@interface EMRAppDelegate : NSObject <NSApplicationDelegate> {
    IBOutlet NSMenu *statusMenu;
    NSStatusItem *statusItem;
    int moveKeyModifierFlags;
    int resizeKeyModifierFlags;
    NSArray *moveMouseButtonMenus;
    NSArray *resizeMouseButtonMenus;
    NSRunningApplication *lastApp;
}

- (int)moveModifierFlags;

- (void)initMenuItems;
- (IBAction)moveModifierToggle:(id)sender;
- (IBAction)resetToDefaults:(id)sender;
- (IBAction)toggleDisabled:(id)sender;
- (IBAction)toggleBringWindowToFront:(id)sender;
- (IBAction)disableLastApp:(id)sender;
- (IBAction)enableDisabledApp:(id)sender;

@property (weak) IBOutlet NSMenuItem *moveLeftMouseButtonMenu;
@property (weak) IBOutlet NSMenuItem *moveRightMouseButtonMenu;
@property (weak) IBOutlet NSMenuItem *moveMiddleMouseButtonMenu;
@property (weak) IBOutlet NSMenuItem *moveAltMenu;
@property (weak) IBOutlet NSMenuItem *moveCmdMenu;
@property (weak) IBOutlet NSMenuItem *moveCtrlMenu;
@property (weak) IBOutlet NSMenuItem *moveShiftMenu;

@property (weak) IBOutlet NSMenuItem *resizeLeftMouseButtonMenu;
@property (weak) IBOutlet NSMenuItem *resizeRightMouseButtonMenu;
@property (weak) IBOutlet NSMenuItem *resizeMiddleMouseButtonMenu;
@property (weak) IBOutlet NSMenuItem *resizeAltMenu;
@property (weak) IBOutlet NSMenuItem *resizeCmdMenu;
@property (weak) IBOutlet NSMenuItem *resizeCtrlMenu;
@property (weak) IBOutlet NSMenuItem *resizeShiftMenu;


@property (weak) IBOutlet NSMenuItem *disabledMenu;
@property (weak) IBOutlet NSMenuItem *bringWindowFrontMenu;
@property (weak) IBOutlet NSMenuItem *middleClickResizeMenu;
@property (weak) IBOutlet NSMenuItem *disabledAppsMenu;
@property (weak) IBOutlet NSMenuItem *lastAppMenu;
@property (nonatomic) BOOL sessionActive;

@end
