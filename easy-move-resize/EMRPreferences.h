// Preferences can alternativevly be managed from the Terminal:
//   Read:
//     `defaults read org.dmarcotte.Easy-Move-Resize ModifierFlags CMD,CTRL`
//   Write:
//     `defaults write org.dmarcotte.Easy-Move-Resize ModifierFlags CMD,CTRL`
//   Note that deleting this preference or writing invalid keys may cause trouble and require that
//     you choose "Reset to Defaults from the app menu.
#ifndef EMRPreferences_h
#define EMRPreferences_h

#define MOVE_MOUSE_BUTTON_DEFAULTS_KEY @"MoveMouseButton"
#define MOVE_MODIFIER_FLAGS_DEFAULTS_KEY @"MoveModifierFlags"

#define RESIZE_MOUSE_BUTTON_DEFAULTS_KEY @"ResizeMouseButton"
#define RESIZE_MODIFIER_FLAGS_DEFAULTS_KEY @"ResizeModifierFlags"

#define SHOULD_BRING_WINDOW_TO_FRONT @"BringToFront"
#define DISABLED_APPS_DEFAULTS_KEY @"DisabledApps"
#define LEFT_MOUSE @"LEFT"
#define RIGHT_MOUSE @"RIGHT"
#define MIDDLE_MOUSE @"MIDDLE"
#define CTRL_KEY @"CTRL"
#define SHIFT_KEY @"SHIFT"
#define CAPS_KEY @"CAPS" // CAPS lock
#define ALT_KEY @"ALT" // Alternate or Option key
#define CMD_KEY @"CMD"

@interface EMRPreferences : NSObject {
    
}

@property (nonatomic) BOOL shouldBringWindowToFront;

// Initialize an EMRPreferences, persisting settings to the given userDefaults
- (id)initWithUserDefaults:(NSUserDefaults *)defaults;

// Get the move modifier flags from the standard preferences
- (int)moveModifierFlags;

// Get the resize modifier flags from the standard preferences
- (int)resizeModifierFlags;

// Set or unset the given modifier key for the Move action in the preferences
- (void)setMoveModifierKey:(NSString*)singleFlagString enabled:(BOOL)enabled;

// Set or unset the given modifier key for the Resize action in the preferences
- (void)setResizeModifierKey:(NSString*)singleFlagString enabled:(BOOL)enabled;

// Set the given mouse button for the Move action in the preferences
- (void)setMoveMouseButton:(NSString *)mouseButtonString;

// Set the given mouse button for the Resize action in the preferences
- (void)setResizeMouseButton:(NSString *)mouseButtonString;

// returns a string of the currently persisted Move mouse button constant
- (NSString*)getMoveMouseButton;

// returns a string of the currently persisted Resize mouse button constant
- (NSString*)getResizeMouseButton;

// returns a set of the currently persisted Move key constants
- (NSSet*)getMoveFlagStringSet;

// returns a set of the currently persisted Resize key constants
- (NSSet*)getResizeFlagStringSet;

// returns a dict of disabled apps
- (NSDictionary*)getDisabledApps;

// add or remove an app from the disabled apps list
- (void)setDisabledForApp:(NSString*)bundleIdentifier withLocalizedName:(NSString*)localizedName disabled:(BOOL)disabled;

// reset preferences to the defaults
- (void)setToDefaults;

@end

#endif /* EMRPreferences_h */
