#import "EMRAppDelegate.h"
#import "EMRMoveResize.h"
#import "EMRPreferences.h"

@implementation EMRAppDelegate {
    EMRPreferences *preferences;
}

- (id) init  {
    self = [super init];
    if (self) {
        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"userPrefs"];
        preferences = [[EMRPreferences alloc] initWithUserDefaults:userDefaults];
        
        moveMouseButtonMenus = [NSArray arrayWithObjects:_moveLeftMouseButtonMenu, _moveRightMouseButtonMenu, _moveMiddleMouseButtonMenu, nil];
        resizeMouseButtonMenus = [NSArray arrayWithObjects:_resizeLeftMouseButtonMenu, _resizeRightMouseButtonMenu, _resizeMiddleMouseButtonMenu, nil];
    }
    return self;
}

CGEventRef myCGEventCallback(CGEventTapProxy __unused proxy, CGEventType type, CGEventRef event, void *refcon) {

    EMRAppDelegate *ourDelegate = (__bridge EMRAppDelegate*)refcon;
    int moveKeyModifierFlags = [ourDelegate moveModifierFlags];
    CGEventType resizeModifierDown = kCGEventRightMouseDown;
    CGEventType resizeModifierDragged = kCGEventRightMouseDragged;
    CGEventType resizeModifierUp = kCGEventRightMouseUp;
    bool handled = NO;

    if (![ourDelegate sessionActive]) {
        return event;
    }

    if (moveKeyModifierFlags == 0) {
        // No modifier keys set. Disable behaviour.
        return event;
    }
    
    EMRMoveResize* moveResize = [EMRMoveResize instance];

    if ((type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput)) {
        // need to re-enable our eventTap (We got disabled.  Usually happens on a slow resizing app)
        CGEventTapEnable([moveResize eventTap], true);
        return event;
    }
    
    CGEventFlags flags = CGEventGetFlags(event);
    if ((flags & (moveKeyModifierFlags)) != (moveKeyModifierFlags)) {
        // didn't find our expected modifiers; this event isn't for us
        return event;
    }

    int ignoredKeysMask = (kCGEventFlagMaskShift | kCGEventFlagMaskCommand | kCGEventFlagMaskAlphaShift | kCGEventFlagMaskAlternate | kCGEventFlagMaskControl) ^ moveKeyModifierFlags;
    
    if (flags & ignoredKeysMask) {
        // also ignore this event if we've got extra modifiers (i.e. holding down Cmd+Ctrl+Alt should not invoke our action)
        return event;
    }

    if (type == kCGEventLeftMouseDown
            || type == resizeModifierDown) {
        CGPoint mouseLocation = CGEventGetLocation(event);
        [moveResize setTracking:CACurrentMediaTime()];

        AXUIElementRef _systemWideElement;
        AXUIElementRef _clickedWindow = NULL;
        _systemWideElement = AXUIElementCreateSystemWide();

        AXUIElementRef _element;
        if ((AXUIElementCopyElementAtPosition(_systemWideElement, (float) mouseLocation.x, (float) mouseLocation.y, &_element) == kAXErrorSuccess) && _element) {
            CFTypeRef _role;
            if (AXUIElementCopyAttributeValue(_element, (__bridge CFStringRef)NSAccessibilityRoleAttribute, &_role) == kAXErrorSuccess) {
                if ([(__bridge NSString *)_role isEqualToString:NSAccessibilityWindowRole]) {
                    _clickedWindow = _element;
                }
                if (_role != NULL) CFRelease(_role);
            }
            CFTypeRef _window;
            if (AXUIElementCopyAttributeValue(_element, (__bridge CFStringRef)NSAccessibilityWindowAttribute, &_window) == kAXErrorSuccess) {
                if (_element != NULL) CFRelease(_element);
                _clickedWindow = (AXUIElementRef)_window;
            }
        }
        CFRelease(_systemWideElement);
        
        pid_t PID;
        NSRunningApplication* app;
        if(!AXUIElementGetPid(_clickedWindow, &PID)) {
            app = [NSRunningApplication runningApplicationWithProcessIdentifier:PID];
            if ([[ourDelegate getDisabledApps] objectForKey:[app bundleIdentifier]] != nil) {
                [moveResize setTracking:0];
                return event;
            }
            [ourDelegate setMostRecentApp:app];
        }

        if([ourDelegate shouldBringWindowToFront]){
            if (app != nil) {
                [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
            }
            AXUIElementPerformAction(_clickedWindow, kAXRaiseAction);
        }
        
        CFTypeRef _cPosition = nil;
        NSPoint cTopLeft;
        if (AXUIElementCopyAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, &_cPosition) == kAXErrorSuccess) {
            if (!AXValueGetValue(_cPosition, kAXValueCGPointType, (void *)&cTopLeft)) {
                NSLog(@"ERROR: Could not decode position");
                cTopLeft = NSMakePoint(0, 0);
            }
            CFRelease(_cPosition);
        }
        
        cTopLeft.x = (int) cTopLeft.x;
        cTopLeft.y = (int) cTopLeft.y;

        [moveResize setWndPosition:cTopLeft];
        [moveResize setWindow:_clickedWindow];
        if (_clickedWindow != nil) CFRelease(_clickedWindow);
        handled = YES;
    }

    if (type == kCGEventLeftMouseDragged
            && [moveResize tracking] > 0) {
        AXUIElementRef _clickedWindow = [moveResize window];
        double deltaX = CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
        double deltaY = CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);

        NSPoint cTopLeft = [moveResize wndPosition];
        NSPoint thePoint;
        thePoint.x = cTopLeft.x + deltaX;
        thePoint.y = cTopLeft.y + deltaY;
        [moveResize setWndPosition:thePoint];
        CFTypeRef _position;

        // actually applying the change is expensive, so only do it every kMoveFilterInterval seconds
        if (CACurrentMediaTime() - [moveResize tracking] > kMoveFilterInterval) {
            _position = (CFTypeRef) (AXValueCreate(kAXValueCGPointType, (const void *) &thePoint));
            AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef) NSAccessibilityPositionAttribute, (CFTypeRef *) _position);
            if (_position != NULL) CFRelease(_position);
            [moveResize setTracking:CACurrentMediaTime()];
        }
        handled = YES;
    }

    if (type == resizeModifierDown) {
        AXUIElementRef _clickedWindow = [moveResize window];

        // on resizeModifierDown click, record which direction we should resize in on the drag
        struct ResizeSection resizeSection;

        CGPoint clickPoint = CGEventGetLocation(event);

        NSPoint cTopLeft = [moveResize wndPosition];

        clickPoint.x -= cTopLeft.x;
        clickPoint.y -= cTopLeft.y;

        CFTypeRef _cSize;
        NSSize cSize;
        if (!(AXUIElementCopyAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, &_cSize) == kAXErrorSuccess)
                || !AXValueGetValue(_cSize, kAXValueCGSizeType, (void *)&cSize)) {
            NSLog(@"ERROR: Could not decode size");
            return NULL;
        }
        CFRelease(_cSize);

        NSSize wndSize = cSize;

        if (clickPoint.x < wndSize.width/3) {
            resizeSection.xResizeDirection = left;
        } else if (clickPoint.x > 2*wndSize.width/3) {
            resizeSection.xResizeDirection = right;
        } else {
            resizeSection.xResizeDirection = noX;
        }

        if (clickPoint.y < wndSize.height/3) {
            resizeSection.yResizeDirection = bottom;
        } else  if (clickPoint.y > 2*wndSize.height/3) {
            resizeSection.yResizeDirection = top;
        } else {
            resizeSection.yResizeDirection = noY;
        }

        [moveResize setWndSize:wndSize];
        [moveResize setResizeSection:resizeSection];
        handled = YES;
    }

    if (type == resizeModifierDragged
            && [moveResize tracking] > 0) {
        AXUIElementRef _clickedWindow = [moveResize window];
        struct ResizeSection resizeSection = [moveResize resizeSection];
        int deltaX = (int) CGEventGetDoubleValueField(event, kCGMouseEventDeltaX);
        int deltaY = (int) CGEventGetDoubleValueField(event, kCGMouseEventDeltaY);

        NSPoint cTopLeft = [moveResize wndPosition];
        NSSize wndSize = [moveResize wndSize];

        switch (resizeSection.xResizeDirection) {
            case right:
                wndSize.width += deltaX;
                break;
            case left:
                wndSize.width -= deltaX;
                cTopLeft.x += deltaX;
                break;
            case noX:
                // nothing to do
                break;
            default:
                [NSException raise:@"Unknown xResizeSection" format:@"No case for %d", resizeSection.xResizeDirection];
        }

        switch (resizeSection.yResizeDirection) {
            case top:
                wndSize.height += deltaY;
                break;
            case bottom:
                wndSize.height -= deltaY;
                cTopLeft.y += deltaY;
                break;
            case noY:
                // nothing to do
                break;
            default:
                [NSException raise:@"Unknown yResizeSection" format:@"No case for %d", resizeSection.yResizeDirection];
        }

        [moveResize setWndPosition:cTopLeft];
        [moveResize setWndSize:wndSize];

        // actually applying the change is expensive, so only do it every kResizeFilterInterval events
        if (CACurrentMediaTime() - [moveResize tracking] > kResizeFilterInterval) {
            // only make a call to update the position if we need to
            if (resizeSection.xResizeDirection == left || resizeSection.yResizeDirection == bottom) {
                CFTypeRef _position = (CFTypeRef)(AXValueCreate(kAXValueCGPointType, (const void *)&cTopLeft));
                AXUIElementSetAttributeValue(_clickedWindow, (__bridge CFStringRef)NSAccessibilityPositionAttribute, (CFTypeRef *)_position);
                CFRelease(_position);
            }

            CFTypeRef _size = (CFTypeRef)(AXValueCreate(kAXValueCGSizeType, (const void *)&wndSize));
            AXUIElementSetAttributeValue((AXUIElementRef)_clickedWindow, (__bridge CFStringRef)NSAccessibilitySizeAttribute, (CFTypeRef *)_size);
            CFRelease(_size);
            [moveResize setTracking:CACurrentMediaTime()];
        }
        handled = YES;
    }

    if ((type == kCGEventLeftMouseUp || type == resizeModifierUp)
        && [moveResize tracking] > 0) {
        [moveResize setTracking:0];
        handled = YES;
    }
    
    if (handled) {
        return NULL;
    }
    else {
        return event;
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    const void * keys[] = { kAXTrustedCheckOptionPrompt };
    const void * values[] = { kCFBooleanTrue };

    CFDictionaryRef options = CFDictionaryCreate(
            kCFAllocatorDefault,
            keys,
            values,
            sizeof(keys) / sizeof(*keys),
            &kCFCopyStringDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks);

    if (!AXIsProcessTrustedWithOptions(options)) {
        // don't have permission to do our thing right now... AXIsProcessTrustedWithOptions prompted the user to fix
        // this, so hopefully on next launch we'll be good to go
        exit(1);
    }
    
    [self initMenuItems];

    // Retrieve the Key press modifier flags to activate move/resize actions.
    moveKeyModifierFlags = [preferences moveModifierFlags];
    
    CFRunLoopSourceRef runLoopSource;

    CGEventMask eventMask = CGEventMaskBit( kCGEventLeftMouseDown )
                    | CGEventMaskBit( kCGEventRightMouseDown )
                    | CGEventMaskBit( kCGEventOtherMouseDown )
                    | CGEventMaskBit( kCGEventLeftMouseDragged )
                    | CGEventMaskBit( kCGEventRightMouseDragged )
                    | CGEventMaskBit( kCGEventOtherMouseDragged )
                    | CGEventMaskBit( kCGEventLeftMouseUp )
                    | CGEventMaskBit( kCGEventRightMouseUp )
                    | CGEventMaskBit( kCGEventOtherMouseUp )
    ;

    CFMachPortRef eventTap = CGEventTapCreate(kCGHIDEventTap,
                                              kCGHeadInsertEventTap,
                                              kCGEventTapOptionDefault,
                                              eventMask,
                                              myCGEventCallback,
                                              (__bridge void * _Nullable)self);

    if (!eventTap) {
        NSLog(@"Couldn't create event tap!");
        exit(1);
    }

    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);


    EMRMoveResize *moveResize = [EMRMoveResize instance];
    [moveResize setEventTap:eventTap];
    [moveResize setRunLoopSource:runLoopSource];
    [self enableRunLoopSource:moveResize];
    CFRelease(runLoopSource);

    _sessionActive = true;
    [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver:self
            selector:@selector(becameActive:)
            name:NSWorkspaceSessionDidBecomeActiveNotification
            object:nil];

    [[[NSWorkspace sharedWorkspace] notificationCenter]
            addObserver:self
            selector:@selector(becameInactive:)
            name:NSWorkspaceSessionDidResignActiveNotification
            object:nil];
    
    [self reconstructDisabledAppsSubmenu];
}

- (void)becameActive:(NSNotification*) notification {
    _sessionActive = true;
}

- (void)becameInactive:(NSNotification*) notification {
    _sessionActive = false;
}

-(void)awakeFromNib{
    NSImage *icon = [NSImage imageNamed:@"MenuIcon"];
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setMenu:statusMenu];
    [statusItem setImage:icon];
    [statusMenu setAutoenablesItems:NO];
    [[statusMenu itemAtIndex:0] setEnabled:NO];
}

- (void)enableRunLoopSource:(EMRMoveResize*)moveResize {
    CFRunLoopAddSource(CFRunLoopGetCurrent(), [moveResize runLoopSource], kCFRunLoopCommonModes);
    CGEventTapEnable([moveResize eventTap], true);
}

- (void)disableRunLoopSource:(EMRMoveResize*)moveResize {
    CGEventTapEnable([moveResize eventTap], false);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), [moveResize runLoopSource], kCFRunLoopCommonModes);
}

- (void)initMenuItems {
    [_moveLeftMouseButtonMenu setState:0];
    [_moveRightMouseButtonMenu setState:0];
    [_moveMiddleMouseButtonMenu setState:0];
    [_moveAltMenu setState:0];
    [_moveCmdMenu setState:0];
    [_moveCtrlMenu setState:0];
    [_moveShiftMenu setState:0];
    
    [_resizeLeftMouseButtonMenu setState:0];
    [_resizeRightMouseButtonMenu setState:0];
    [_resizeMiddleMouseButtonMenu setState:0];
    [_resizeAltMenu setState:0];
    [_resizeCmdMenu setState:0];
    [_resizeCtrlMenu setState:0];
    [_resizeShiftMenu setState:0];
    
    [_disabledMenu setState:0];
    [_bringWindowFrontMenu setState:0];

    bool shouldBringWindowToFront = [preferences shouldBringWindowToFront];

    if(shouldBringWindowToFront){
        [_bringWindowFrontMenu setState:1];
    }
    
    NSString *moveMouseButton = [preferences getMoveMouseButton];
    if ([moveMouseButton isEqualToString:LEFT_MOUSE]) {
        [_moveLeftMouseButtonMenu setState:1];
    }
    if ([moveMouseButton isEqualToString:RIGHT_MOUSE]) {
        [_moveRightMouseButtonMenu setState:1];
    }
    if ([moveMouseButton isEqualToString:MIDDLE_MOUSE]) {
        [_moveMiddleMouseButtonMenu setState:1];
    }
    
    NSSet* moveFlags = [preferences getMoveFlagStringSet];
    if ([moveFlags containsObject:ALT_KEY]) {
        [_moveAltMenu setState:1];
    }
    if ([moveFlags containsObject:CMD_KEY]) {
        [_moveCmdMenu setState:1];
    }
    if ([moveFlags containsObject:CTRL_KEY]) {
        [_moveCtrlMenu setState:1];
    }
    if ([moveFlags containsObject:SHIFT_KEY]) {
        [_moveShiftMenu setState:1];
    }
    
    NSString *resizeMouseButton = [preferences getResizeMouseButton];
    if ([resizeMouseButton isEqualToString:LEFT_MOUSE]) {
        [_resizeLeftMouseButtonMenu setState:1];
    }
    if ([resizeMouseButton isEqualToString:RIGHT_MOUSE]) {
        [_resizeRightMouseButtonMenu setState:1];
    }
    if ([resizeMouseButton isEqualToString:MIDDLE_MOUSE]) {
        [_resizeMiddleMouseButtonMenu setState:1];
    }
    NSSet* resizeFlags = [preferences getResizeFlagStringSet];
    if ([resizeFlags containsObject:ALT_KEY]) {
        [_resizeAltMenu setState:1];
    }
    if ([resizeFlags containsObject:CMD_KEY]) {
        [_resizeCmdMenu setState:1];
    }
    if ([resizeFlags containsObject:CTRL_KEY]) {
        [_resizeCtrlMenu setState:1];
    }
    if ([resizeFlags containsObject:SHIFT_KEY]) {
        [_resizeShiftMenu setState:1];
    }
}
- (IBAction)moveMouseToggle:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    
    [preferences setMoveMouseButton:[menu identifier]];
}

- (IBAction)moveModifierToggle:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setMoveModifierKey:[menu title] enabled:newState];
    moveKeyModifierFlags = [preferences moveModifierFlags];
}

- (IBAction)resizeMouseToggle:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    
    [preferences setResizeMouseButton:[menu identifier]];
}

- (IBAction)resizeModifierToggle:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setResizeModifierKey:[menu title] enabled:newState];
    resizeKeyModifierFlags = [preferences resizeModifierFlags];
}

- (IBAction)resetToDefaults:(id)sender {
    EMRMoveResize* moveResize = [EMRMoveResize instance];
    [preferences setToDefaults];
    [self initMenuItems];
    [self setMenusEnabled:YES];
    [self enableRunLoopSource:moveResize];
    moveKeyModifierFlags = [preferences moveModifierFlags];
    resizeKeyModifierFlags = [preferences resizeModifierFlags];
}

- (IBAction)toggleBringWindowToFront:(id)sender {
    NSMenuItem *menu = (NSMenuItem*)sender;
    BOOL newState = ![menu state];
    [menu setState:newState];
    [preferences setShouldBringWindowToFront:newState];
}

- (IBAction)toggleDisabled:(id)sender {
    EMRMoveResize* moveResize = [EMRMoveResize instance];
    if ([_disabledMenu state] == 0) {
        // We are enabled, disable
        [_disabledMenu setState:YES];
        [self setMenusEnabled:NO];
        [self disableRunLoopSource:moveResize];
    }
    else {
        // We are disabled, enable
        [_disabledMenu setState:NO];
        [self setMenusEnabled:YES];
        [self enableRunLoopSource:moveResize];
    }
}

- (IBAction)disableLastApp:(id)sender {
    [preferences setDisabledForApp:[lastApp bundleIdentifier] withLocalizedName:[lastApp localizedName] disabled:YES];
    [_lastAppMenu setEnabled:FALSE];
    [self reconstructDisabledAppsSubmenu];
}

- (IBAction)enableDisabledApp:(id)sender {
    NSString *bundleId = [sender representedObject];
    [preferences setDisabledForApp:bundleId withLocalizedName:nil disabled:NO];
    if (lastApp != nil && [[lastApp bundleIdentifier] isEqualToString:bundleId]) {
        [_lastAppMenu setEnabled:YES];
    }
    [self reconstructDisabledAppsSubmenu];
}

- (int)moveModifierFlags {
    return moveKeyModifierFlags;
}

- (int)resizeModifierFlags {
    return resizeKeyModifierFlags;
}

- (void) setMostRecentApp:(NSRunningApplication*)app {
    lastApp = app;
    [_lastAppMenu setTitle:[NSString stringWithFormat:@"Disable for %@", [app localizedName]]];
    [_lastAppMenu setEnabled:YES];
}
- (NSDictionary*) getDisabledApps {
    return [preferences getDisabledApps];
}
-(BOOL)shouldBringWindowToFront {
    return [preferences shouldBringWindowToFront];
}

- (void)setMenusEnabled:(BOOL)enabled {
    [_moveLeftMouseButtonMenu setEnabled:enabled];
    [_moveRightMouseButtonMenu setEnabled:enabled];
    [_moveMiddleMouseButtonMenu setEnabled:enabled];
    [_moveAltMenu setEnabled:enabled];
    [_moveCmdMenu setEnabled:enabled];
    [_moveCtrlMenu setEnabled:enabled];
    [_moveShiftMenu setEnabled:enabled];
    
    [_resizeLeftMouseButtonMenu setEnabled:enabled];
    [_resizeRightMouseButtonMenu setEnabled:enabled];
    [_resizeMiddleMouseButtonMenu setEnabled:enabled];
    [_resizeAltMenu setEnabled:enabled];
    [_resizeCmdMenu setEnabled:enabled];
    [_resizeCtrlMenu setEnabled:enabled];
    [_resizeShiftMenu setEnabled:enabled];
    
    [_bringWindowFrontMenu setEnabled:enabled];
    [_middleClickResizeMenu setEnabled:enabled];
}

- (void)reconstructDisabledAppsSubmenu {
    NSMenu *submenu = [[NSMenu alloc] init];
    NSDictionary *disabledApps = [self getDisabledApps];
    for (id bundleIdentifier in disabledApps) {
        NSMenuItem *item = [submenu addItemWithTitle:[disabledApps objectForKey:bundleIdentifier] action:@selector(enableDisabledApp:) keyEquivalent:@""];
        [item setRepresentedObject:bundleIdentifier];
    }
    [_disabledAppsMenu setSubmenu:submenu];
    [_disabledAppsMenu setEnabled:([disabledApps count] > 0)];
}

@end
