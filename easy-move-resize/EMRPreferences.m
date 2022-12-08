#import "EMRPreferences.h"

#define DEFAULT_MODIFIER_FLAGS kCGEventFlagMaskCommand | kCGEventFlagMaskControl

@implementation EMRPreferences {
@private
    NSUserDefaults *userDefaults;
}

- (id)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:@"Must initialize with a NSUserDefaults pointer in -initWithUserDefaults"
                                 userInfo:nil];
    return nil;
}

- (id)initWithUserDefaults:(NSUserDefaults *)defaults {
    self = [super init];
    if (self) {
        userDefaults = defaults;
        NSString *moveModifierFlagString = [userDefaults stringForKey:MOVE_MODIFIER_FLAGS_DEFAULTS_KEY];
        if (moveModifierFlagString == nil) {
            // ensure our defaults are initialized
            [self setToDefaults];
        }
        else {
            // disabledApps was added in an update, need to set if the app has been updated
            NSDictionary *disabledApps = [userDefaults dictionaryForKey:DISABLED_APPS_DEFAULTS_KEY];
            if (disabledApps == nil) {
                [userDefaults setObject:[NSDictionary dictionary] forKey:DISABLED_APPS_DEFAULTS_KEY];
            }
            // Move mouse button added in update
            NSString *moveMouseButtonString = [userDefaults stringForKey:MOVE_MOUSE_BUTTON_DEFAULTS_KEY];
            if (moveMouseButtonString == nil) {
                [self setMoveMouseButtonToDefault];
            }
            // Resize modifiers added in update
            NSString *resizeModifierFlagString = [userDefaults stringForKey:RESIZE_MODIFIER_FLAGS_DEFAULTS_KEY];
            if (resizeModifierFlagString == nil) {
                [self setResizeModifiersToDefault];
            }
            // Resize mouse button added in update
            NSString *resizeMouseButtonString = [userDefaults stringForKey:RESIZE_MOUSE_BUTTON_DEFAULTS_KEY];
            if (resizeMouseButtonString == nil) {
                [self setResizeMouseButtonToDefault];
            }
        }
    }
    return self;
}

- (int)modifierFlagsWithDefaultsKey:(NSString*)defaultsKey {
    int modifierFlags = 0;
    
    NSString *modifierFlagString = [userDefaults stringForKey:defaultsKey];
    if (modifierFlagString == nil) {
        return DEFAULT_MODIFIER_FLAGS;
    }
    
    modifierFlags = [self flagsFromFlagString:modifierFlagString];
    
    return modifierFlags;
}

- (int)moveModifierFlags {
    return [self modifierFlagsWithDefaultsKey:MOVE_MODIFIER_FLAGS_DEFAULTS_KEY];
}

- (int)resizeModifierFlags {
    return [self modifierFlagsWithDefaultsKey:RESIZE_MODIFIER_FLAGS_DEFAULTS_KEY];
}

- (void)setModifierFlagString:(NSString *)flagString defaultsKey:(NSString *)defaultsKey {
    flagString = [[flagString stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
    [userDefaults setObject:flagString forKey:defaultsKey];
}

- (void)setModifierKey:(NSString*)singleFlagString enabled:(BOOL)enabled defaultsKey:(NSString*)defaultsKey
{
    singleFlagString = [singleFlagString uppercaseString];
    NSString *modifierFlagString = [userDefaults stringForKey:defaultsKey];
    if (modifierFlagString == nil) {
        NSLog(@"Unexpected null... this should always have a value");
        [self setToDefaults];
    }
    NSMutableSet *flagSet = [self createSetFromFlagString:modifierFlagString];
    if (enabled) {
        [flagSet addObject:singleFlagString];
    }
    else {
        [flagSet removeObject:singleFlagString];
    }
    [self setModifierFlagString:[[flagSet allObjects] componentsJoinedByString:@","] defaultsKey:defaultsKey];
}

- (void)setMoveModifierKey:(NSString *)singleFlagString enabled:(BOOL)enabled {
    [self setModifierKey:singleFlagString enabled:enabled defaultsKey:MOVE_MODIFIER_FLAGS_DEFAULTS_KEY];
}

- (void)setResizeModifierKey:(NSString*)singleFlagString enabled:(BOOL)enabled {
    [self setModifierKey:singleFlagString enabled:enabled defaultsKey:RESIZE_MODIFIER_FLAGS_DEFAULTS_KEY];
}

- (void)setMouseButton:(NSString *)mouseButtonString defaultsKey:(NSString*)defaultsKey
{
    mouseButtonString = [mouseButtonString uppercaseString];
    mouseButtonString = [mouseButtonString componentsSeparatedByString:@" "][1];
    NSString *defaultsKeyString = [userDefaults stringForKey:defaultsKey];
    if (defaultsKeyString == nil) {
        NSLog(@"Unexpected null... this should always have a value");
        [self setToDefaults];
    }
    
    [userDefaults setObject:mouseButtonString forKey:defaultsKey];
}

- (void)setMoveMouseButton:(NSString *)mouseButtonString {
    [self setMouseButton:mouseButtonString defaultsKey:MOVE_MOUSE_BUTTON_DEFAULTS_KEY];
}

- (void)setResizeMouseButton:(NSString *)mouseButtonString {
    [self setMouseButton:mouseButtonString defaultsKey:RESIZE_MOUSE_BUTTON_DEFAULTS_KEY];
}

- (NSString*)getMouseButtonWithDefaultsKey:(NSString*)defaultsKey {
    NSString *mouseButtonString = [userDefaults stringForKey:defaultsKey];
    if (mouseButtonString == nil) {
        NSLog(@"Unexpected null... this should always have a value");
        [self setToDefaults];
    }
    
    return [userDefaults stringForKey:defaultsKey];
}

- (NSString*)getMoveMouseButton {
    return [self getMouseButtonWithDefaultsKey:MOVE_MOUSE_BUTTON_DEFAULTS_KEY];
}

- (NSString*)getResizeMouseButton {
    return [self getMouseButtonWithDefaultsKey:RESIZE_MOUSE_BUTTON_DEFAULTS_KEY];
}

- (NSSet*)getFlagStringSetWithDefaultsKey:(NSString*)defaultsKey {
    NSString *modifierFlagString = [userDefaults stringForKey:defaultsKey];
    if (modifierFlagString == nil) {
        NSLog(@"Unexpected null... this should always have a value");
        [self setToDefaults];
    }
    NSMutableSet *flagSet = [self createSetFromFlagString:modifierFlagString];
    return flagSet;
}

- (NSSet*)getMoveFlagStringSet {
    return [self getFlagStringSetWithDefaultsKey:MOVE_MODIFIER_FLAGS_DEFAULTS_KEY];
}

- (NSSet*)getResizeFlagStringSet {
    return [self getFlagStringSetWithDefaultsKey:RESIZE_MODIFIER_FLAGS_DEFAULTS_KEY];
}

- (NSDictionary*) getDisabledApps {
    return [userDefaults dictionaryForKey:DISABLED_APPS_DEFAULTS_KEY];
}

- (void)setDisabledForApp:(NSString*)bundleIdentifier withLocalizedName:(NSString*)localizedName disabled:(BOOL)disabled {    NSMutableDictionary *disabledApps = [[self getDisabledApps] mutableCopy];
    if (disabled) {
        [disabledApps setObject:localizedName forKey:bundleIdentifier];
    }
    else {
        [disabledApps removeObjectForKey:bundleIdentifier];
    }
    [userDefaults setObject:disabledApps forKey:DISABLED_APPS_DEFAULTS_KEY];
}

- (void)setMoveModifiersToDefault {
    [self setModifierFlagString:[@[CTRL_KEY, CMD_KEY] componentsJoinedByString:@","] defaultsKey:MOVE_MODIFIER_FLAGS_DEFAULTS_KEY];
}

- (void)setMoveMouseButtonToDefault {
    [self setMoveMouseButton:LEFT_MOUSE];
}

- (void)setResizeModifiersToDefault {
    [self setModifierFlagString:[@[CTRL_KEY, CMD_KEY] componentsJoinedByString:@","] defaultsKey:RESIZE_MODIFIER_FLAGS_DEFAULTS_KEY];
}

- (void)setResizeMouseButtonToDefault {
    [self setResizeMouseButton:RIGHT_MOUSE];
}

- (void)setToDefaults {
    [self setMoveModifiersToDefault];
    [self setResizeModifiersToDefault];
    [self setResizeMouseButtonToDefault];
    
    [userDefaults setBool:NO forKey:SHOULD_BRING_WINDOW_TO_FRONT];
    [userDefaults setObject:[NSDictionary dictionary] forKey:DISABLED_APPS_DEFAULTS_KEY];
}

- (NSMutableSet*)createSetFromFlagString:(NSString*)modifierFlagString {
    modifierFlagString = [[modifierFlagString stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString];
    if ([modifierFlagString length] == 0) {
        return [[NSMutableSet alloc] initWithCapacity:0];
    }
    NSArray *flagList = [modifierFlagString componentsSeparatedByString:@","];
    NSMutableSet *flagSet = [[NSMutableSet alloc] initWithArray:flagList];
    return flagSet;
}

- (int)flagsFromFlagString:(NSString*)modifierFlagString {
    int modifierFlags = 0;
    if (modifierFlagString == nil || [modifierFlagString length] == 0) {
        return 0;
    }
    NSSet *flagList = [self createSetFromFlagString:modifierFlagString];
    
    if ([flagList containsObject:CTRL_KEY]) {
        modifierFlags |= kCGEventFlagMaskControl;
    }
    if ([flagList containsObject:SHIFT_KEY]) {
        modifierFlags |= kCGEventFlagMaskShift;
    }
    if ([flagList containsObject:CAPS_KEY]) {
        modifierFlags |= kCGEventFlagMaskAlphaShift;
    }
    if ([flagList containsObject:ALT_KEY]) {
        modifierFlags |= kCGEventFlagMaskAlternate;
    }
    if ([flagList containsObject:CMD_KEY]) {
        modifierFlags |= kCGEventFlagMaskCommand;
    }
    
    return modifierFlags;
}

-(BOOL)shouldBringWindowToFront {
    return [userDefaults boolForKey:SHOULD_BRING_WINDOW_TO_FRONT];
}
-(void)setShouldBringWindowToFront:(BOOL)bringToFront {
    [userDefaults setBool:bringToFront forKey:SHOULD_BRING_WINDOW_TO_FRONT];
}

@end

