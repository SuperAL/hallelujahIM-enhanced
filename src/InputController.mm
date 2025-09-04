#import <AppKit/NSSpellChecker.h>
#import <CoreServices/CoreServices.h>
#import <objc/runtime.h>

#import "InputApplicationDelegate.h"
#import "InputController.h"
#import "NSScreen+PointConversion.h"

extern IMKCandidates *sharedCandidates;
extern IMKCandidates *expandedCandidates;
extern NSUserDefaults *preference;
extern ConversionEngine *engine;

typedef NSInteger KeyCode;
static const KeyCode KEY_RETURN = 36, KEY_SPACE = 49, KEY_DELETE = 51, KEY_ESC = 53, KEY_ARROW_LEFT = 123, KEY_ARROW_RIGHT = 124, KEY_ARROW_UP = 126, KEY_ARROW_DOWN = 125, KEY_RIGHT_SHIFT = 60;

// Debug logging function
void writeDebugLog(NSString *message) {
    NSString *logPath = @"/tmp/hallelujah_debug.log";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *logEntry = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];

    if (![[NSFileManager defaultManager] fileExistsAtPath:logPath]) {
        [@"=== Hallelujah IM Debug Log ===\n" writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }

    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (fileHandle) {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[logEntry dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    }
}

@interface InputController()

- (void)showIMEPreferences:(id)sender;
- (void)clickAbout:(NSMenuItem *)sender;
- (IMKCandidates *)currentCandidatePanel;
- (void)switchToExpandedMode;
- (void)switchToCompactMode;

@end

@implementation InputController

- (NSUInteger)recognizedEvents:(id)sender {
    return NSEventMaskKeyDown | NSEventMaskFlagsChanged;
}

- (BOOL)handleEvent:(NSEvent *)event client:(id)sender {
    NSUInteger modifiers = event.modifierFlags;
    bool handled = NO;
    switch (event.type) {
    case NSEventTypeFlagsChanged:
        // NSLog(@"hallelujah event modifierFlags %lu, event keyCode: %@", (unsigned long)[event modifierFlags], [event keyCode]);

        if (_lastEventTypes[1] == NSEventTypeFlagsChanged && _lastModifiers[1] == modifiers) {
            return YES;
        }

        if (modifiers == 0 && _lastEventTypes[1] == NSEventTypeFlagsChanged && _lastModifiers[1] == NSEventModifierFlagShift &&
            event.keyCode == KEY_RIGHT_SHIFT && !(_lastModifiers[0] & NSEventModifierFlagShift)) {

            _defaultEnglishMode = !_defaultEnglishMode;
            if (_defaultEnglishMode) {
                NSString *bufferedText = [self originalBuffer];
                if (bufferedText && bufferedText.length > 0) {
                    [self cancelComposition];
                    [self commitComposition:sender];
                }
            }
        }
        break;
    case NSEventTypeKeyDown:
        if (_defaultEnglishMode) {
            break;
        }

        // ignore Command+X hotkeys.
        if (modifiers & NSEventModifierFlagCommand)
            break;

        if (modifiers & NSEventModifierFlagOption) {
            return false;
        }

        if (modifiers & NSEventModifierFlagControl) {
            return false;
        }

        handled = [self onKeyEvent:event client:sender];
        break;
    default:
        break;
    }

    _lastModifiers[0] = _lastModifiers[1];
    _lastEventTypes[0] = _lastEventTypes[1];
    _lastModifiers[1] = modifiers;
    _lastEventTypes[1] = event.type;
    return handled;
}

- (BOOL)onKeyEvent:(NSEvent *)event client:(id)sender {
    _currentClient = sender;
    NSInteger keyCode = event.keyCode;
    NSString *characters = event.characters;

    NSString *bufferedText = [self originalBuffer];
    bool hasBufferedText = bufferedText && bufferedText.length > 0;

    if (keyCode == KEY_DELETE) {
        if (hasBufferedText) {
            return [self deleteBackward:sender];
        }

        return NO;
    }

    if (keyCode == KEY_SPACE) {
        if (hasBufferedText) {
            if (_candidates.count > 0) {
                // Space key should apply the current selected candidate (default behavior)
                NSString *selectedCandidate = _candidates[_currentCandidateIndex];
                [self setComposedBuffer:selectedCandidate];
                [self setOriginalBuffer:selectedCandidate];
                [self commitComposition:sender];
            } else {
                // No candidates available, commit the original input with space
                [self setComposedBuffer:[self originalBuffer]];
                [self commitComposition:sender];
            }
            return YES;
        }
        return NO;
    }

    if (keyCode == KEY_RETURN) {
        if (hasBufferedText) {
            if (_hasNavigatedCandidates && _candidates.count > 0) {
                // User has navigated through candidates, commit the selected candidate
                NSString *selectedCandidate = _candidates[_currentCandidateIndex];
                [self setComposedBuffer:selectedCandidate];
                [self setOriginalBuffer:selectedCandidate];
                [self commitCompositionWithoutSpace:sender];
            } else {
                // User hasn't navigated, commit the original input
                [self commitOriginalInputWithoutSpace:sender];
            }
            return YES;
        }
        return NO;
    }

    if (keyCode == KEY_ESC) {
        [self cancelComposition];
        [sender insertText:@""];
        [self reset];
        return YES;
    }

    char ch = [characters characterAtIndex:0];
    if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
        // Reset navigation state whenever user modifies the original input
        _hasNavigatedCandidates = NO;

        [self originalBufferAppend:characters client:sender];

        [sharedCandidates updateCandidates];
        [sharedCandidates show:kIMKLocateCandidatesBelowHint];
        return YES;
    }

    if ([self isMojaveAndLaterSystem]) {
        BOOL isCandidatesVisible = [sharedCandidates isVisible] || [expandedCandidates isVisible];
        writeDebugLog([NSString stringWithFormat:@"Key pressed: %d, candidates visible: %@", keyCode, isCandidatesVisible ? @"YES" : @"NO"]);
        if (isCandidatesVisible) {
            IMKCandidates *currentPanel = [self currentCandidatePanel];

            // Up/Down keys: expand/collapse or navigate in expanded mode
            if (keyCode == KEY_ARROW_UP || keyCode == KEY_ARROW_DOWN) {
                if (!_candidatesExpanded) {
                    // Expand to grid mode when up/down is pressed
                    writeDebugLog(@"🔄 Expanding candidates panel on first up/down key press");
                    [self switchToExpandedMode];
                    _hasNavigatedCandidates = YES;

                    // After expanding, also perform the navigation in the same key press
                    IMKCandidates *currentPanel = [self currentCandidatePanel];
                    if (keyCode == KEY_ARROW_UP) {
                        writeDebugLog(@"⬆️ Moving up after expansion");
                        [currentPanel moveUp:self];
                    } else {
                        writeDebugLog(@"⬇️ Moving down after expansion");
                        [currentPanel moveDown:self];
                    }
                    return YES; // We handled the event completely
                } else {
                    // Navigate up/down in expanded mode - let IMK handle it
                    if (keyCode == KEY_ARROW_UP) {
                        writeDebugLog([NSString stringWithFormat:@"Arrow UP pressed in expanded mode, current index: %ld", (long)_currentCandidateIndex]);
                        [currentPanel moveUp:self];
                    } else {
                        writeDebugLog([NSString stringWithFormat:@"Arrow DOWN pressed in expanded mode, current index: %ld", (long)_currentCandidateIndex]);
                        [currentPanel moveDown:self];
                    }
                    _hasNavigatedCandidates = YES;
                    return YES; // We handled the event completely
                }
            }

            // Left/Right keys: navigate horizontally
            if (keyCode == KEY_ARROW_RIGHT) {
                if (_candidatesExpanded) {
                    writeDebugLog([NSString stringWithFormat:@"Arrow RIGHT pressed in expanded mode, current index: %ld", (long)_currentCandidateIndex]);
                    [currentPanel moveRight:self];
                } else {
                    [currentPanel moveDown:self];
                    _currentCandidateIndex++;
                }
                _hasNavigatedCandidates = YES;
                return NO;
            }

            if (keyCode == KEY_ARROW_LEFT) {
                if (_candidatesExpanded) {
                    writeDebugLog([NSString stringWithFormat:@"Arrow LEFT pressed in expanded mode, current index: %ld", (long)_currentCandidateIndex]);
                    [currentPanel moveLeft:self];
                } else {
                    [currentPanel moveUp:self];
                    _currentCandidateIndex--;
                }
                _hasNavigatedCandidates = YES;
                return NO;
            }

            // Handle number keys for candidate selection
            if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:ch]) {
                int pressedNumber = characters.intValue;

                // Clear log section
                writeDebugLog(@"");
                writeDebugLog(@"========== NUMBER KEY DEBUG ==========");
                writeDebugLog([NSString stringWithFormat:@"🔢 Number key pressed: %d", pressedNumber]);
                writeDebugLog([NSString stringWithFormat:@"📋 Candidates visible: %@", isCandidatesVisible ? @"YES" : @"NO"]);
                writeDebugLog([NSString stringWithFormat:@"🔍 Candidates expanded: %@", _candidatesExpanded ? @"YES" : @"NO"]);
                writeDebugLog([NSString stringWithFormat:@"📍 Current candidate index: %ld", (long)_currentCandidateIndex]);
                writeDebugLog([NSString stringWithFormat:@"📊 Total candidates: %lu", (unsigned long)_candidates.count]);
                writeDebugLog([NSString stringWithFormat:@"🧭 Has navigated: %@", _hasNavigatedCandidates ? @"YES" : @"NO"]);

                // Show current candidates list
                if (_candidates.count > 0) {
                    writeDebugLog(@"📝 Current candidates:");
                    for (int i = 0; i < MIN(_candidates.count, 10); i++) {
                        NSString *marker = (i == _currentCandidateIndex) ? @"👉" : @"  ";
                        writeDebugLog([NSString stringWithFormat:@"  %@[%d] %@", marker, i, _candidates[i]]);
                    }
                }

                if (pressedNumber >= 1 && pressedNumber <= 9) {
                    writeDebugLog([NSString stringWithFormat:@"✅ Valid number key %d pressed", pressedNumber]);

                    if (_candidatesExpanded) {
                        writeDebugLog(@"🔍 EXPANDED MODE - Processing selection...");

                        // Try different approaches to select candidates in expanded mode
                        IMKCandidates *currentPanel = [self currentCandidatePanel];
                        writeDebugLog([NSString stringWithFormat:@"📱 Current panel: %@", currentPanel]);

                        // Method 1: Use visible candidates for accurate selection
                        if (_currentVisibleCandidates && pressedNumber <= _currentVisibleCandidates.count) {
                            int visibleIndex = pressedNumber - 1;
                            NSString *targetCandidate = _currentVisibleCandidates[visibleIndex];
                            writeDebugLog([NSString stringWithFormat:@"🎯 Method 1: Visible candidate selection - number: %d, target: '%@'", pressedNumber, targetCandidate]);

                            // Try to simulate candidate selection
                            NSAttributedString *candidateString = [[NSAttributedString alloc] initWithString:targetCandidate];
                            writeDebugLog(@"📤 Calling candidateSelected with visible candidate...");
                            [self candidateSelected:candidateString];
                            writeDebugLog(@"✅ candidateSelected completed with visible candidate");
                            return YES;
                        } else {
                            writeDebugLog([NSString stringWithFormat:@"❌ Number %d exceeds visible candidates count %lu or no visible candidates stored",
                                         pressedNumber, (unsigned long)(_currentVisibleCandidates ? _currentVisibleCandidates.count : 0)]);
                        }

                        // Method 2: Try IMK selectCandidateWithIdentifier as fallback
                        int imkTargetIndex = pressedNumber - 1;
                        writeDebugLog([NSString stringWithFormat:@"🔄 Method 2: IMK selectCandidateWithIdentifier(%d)", imkTargetIndex]);

                        if ([currentPanel respondsToSelector:@selector(selectCandidateWithIdentifier:)]) {
                            writeDebugLog(@"✅ IMK method available, calling...");
                            [currentPanel selectCandidateWithIdentifier:imkTargetIndex];
                            writeDebugLog(@"📤 IMK method called");
                        } else {
                            writeDebugLog(@"❌ IMK selectCandidateWithIdentifier not available");
                        }

                        // Method 3: Direct candidate selection fallback (old logic)
                        int targetIndex = pressedNumber - 1;
                        writeDebugLog([NSString stringWithFormat:@"🔄 Method 3: Direct selection fallback - target index: %d", targetIndex]);

                        if (targetIndex >= 0 && targetIndex < _candidates.count) {
                            NSString *targetCandidate = _candidates[targetIndex];
                            writeDebugLog([NSString stringWithFormat:@"🎯 Fallback target candidate: [%d] '%@'", targetIndex, targetCandidate]);

                            // Try to simulate candidate selection
                            NSAttributedString *candidateString = [[NSAttributedString alloc] initWithString:targetCandidate];
                            writeDebugLog(@"📤 Calling candidateSelected (fallback)...");
                            [self candidateSelected:candidateString];
                            writeDebugLog(@"✅ candidateSelected completed (fallback)");
                            return YES;
                        } else {
                            writeDebugLog([NSString stringWithFormat:@"❌ Fallback target index %d out of bounds (total: %lu)", targetIndex, (unsigned long)_candidates.count]);
                        }

                        if (targetIndex < _candidates.count) {
                            NSString *candidate = _candidates[targetIndex];
                            writeDebugLog([NSString stringWithFormat:@"Selected candidate in expanded mode: %@", candidate]);

                            [self cancelComposition];
                            [self setComposedBuffer:candidate];
                            [self setOriginalBuffer:candidate];
                            [self commitComposition:sender];
                            return YES;
                        } else {
                            writeDebugLog([NSString stringWithFormat:@"Target index %d out of bounds (total: %ld)", targetIndex, (long)_candidates.count]);
                        }
                        return YES; // Consume the key even if not handled
                    } else {
                        // In compact mode, handle number keys manually
                        writeDebugLog([NSString stringWithFormat:@"=== COMPACT MODE DEBUG ==="]);
                        writeDebugLog([NSString stringWithFormat:@"Current candidate index: %ld", (long)_currentCandidateIndex]);

                        NSString *candidate = nil;
                        int pageSize = 9;
                        if (_currentCandidateIndex <= pageSize) {
                            if (pressedNumber <= _candidates.count) {
                                candidate = _candidates[pressedNumber - 1];
                                writeDebugLog([NSString stringWithFormat:@"Simple selection: candidate[%d] = %@", pressedNumber - 1, candidate]);
                            }
                        } else {
                            int calculatedIndex = pageSize * (_currentCandidateIndex / pageSize - 1) + (_currentCandidateIndex % pageSize) + pressedNumber - 1;
                            writeDebugLog([NSString stringWithFormat:@"Calculated index: %d", calculatedIndex]);
                            if (calculatedIndex < _candidates.count) {
                                candidate = _candidates[calculatedIndex];
                                writeDebugLog([NSString stringWithFormat:@"Complex selection: candidate[%d] = %@", calculatedIndex, candidate]);
                            }
                        }

                        if (candidate) {
                            writeDebugLog([NSString stringWithFormat:@"Selected candidate: %@", candidate]);
                            [self cancelComposition];
                            [self setComposedBuffer:candidate];
                            [self setOriginalBuffer:candidate];
                            [self commitComposition:sender];
                            return YES;
                        } else {
                            writeDebugLog(@"No candidate found");
                        }
                    }
                }
                return YES; // Consume the number key even if not handled
            }
        }

        if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:ch]) {
            if (!hasBufferedText) {
                [self appendToComposedBuffer:characters];
                [self commitCompositionWithoutSpace:sender];
                return YES;
            }
        }
    }

    if ([[NSCharacterSet punctuationCharacterSet] characterIsMember:ch] || [[NSCharacterSet symbolCharacterSet] characterIsMember:ch]) {
        if (hasBufferedText) {
            [self appendToComposedBuffer:characters];
            [self commitCompositionWithoutSpace:sender];
            return YES;
        }
    }

    return NO;
}

- (BOOL)isMojaveAndLaterSystem {
    NSOperatingSystemVersion version = [NSProcessInfo processInfo].operatingSystemVersion;
    return (version.majorVersion == 10 && version.minorVersion > 13) || version.majorVersion > 10;
}

- (BOOL)deleteBackward:(id)sender {
    NSMutableString *originalText = [self originalBuffer];

    if (_insertionIndex > 0) {
        --_insertionIndex;

        // Reset navigation state when user modifies the original input
        _hasNavigatedCandidates = NO;

        NSString *convertedString = [originalText substringToIndex:originalText.length - 1];

        [self setComposedBuffer:convertedString];
        [self setOriginalBuffer:convertedString];

        [self showPreeditString:convertedString];

        if (convertedString && convertedString.length > 0) {
            [sharedCandidates updateCandidates];
            [sharedCandidates show:kIMKLocateCandidatesBelowHint];
        } else {
            [self reset];
        }
        return YES;
    }
    return NO;
}

- (void)commitComposition:(id)sender {
    NSString *text = [self composedBuffer];

    if (text == nil || text.length == 0) {
        text = [self originalBuffer];
    }
    BOOL commitWordWithSpace = [preference boolForKey:@"commitWordWithSpace"];

    if (commitWordWithSpace && text.length > 0) {
        char firstChar = [text characterAtIndex:0];
        char lastChar = [text characterAtIndex:text.length - 1];
        if (![[NSCharacterSet decimalDigitCharacterSet] characterIsMember:firstChar] && lastChar != '\'') {
            text = [NSString stringWithFormat:@"%@ ", text];
        }
    }

    [sender insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

    [self reset];
}

- (void)commitCompositionWithoutSpace:(id)sender {
    NSString *text = [self composedBuffer];

    if (text == nil || text.length == 0) {
        text = [self originalBuffer];
    }

    [sender insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

    [self reset];
}

- (void)commitOriginalInputWithoutSpace:(id)sender {
    NSString *text = [self originalBuffer];

    if (text == nil || text.length == 0) {
        return;
    }

    [sender insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

    [self reset];
}

- (void)reset {
    [self setComposedBuffer:@""];
    [self setOriginalBuffer:@""];
    _insertionIndex = 0;
    _currentCandidateIndex = 0;
    _hasNavigatedCandidates = NO;
    _candidatesExpanded = NO;
    [sharedCandidates clearSelection];
    [sharedCandidates hide];
    [expandedCandidates clearSelection];
    [expandedCandidates hide];
    _candidates = [[NSMutableArray alloc] init];
    [sharedCandidates setCandidateData:@[]];
    [expandedCandidates setCandidateData:@[]];
    [_annotationWin setAnnotation:@""];
    [_annotationWin hideWindow];
}

- (NSMutableString *)composedBuffer {
    if (_composedBuffer == nil) {
        _composedBuffer = [[NSMutableString alloc] init];
    }
    return _composedBuffer;
}

- (void)setComposedBuffer:(NSString *)string {
    NSMutableString *buffer = [self composedBuffer];
    [buffer setString:string];
}

- (NSMutableString *)originalBuffer {
    if (_originalBuffer == nil) {
        _originalBuffer = [[NSMutableString alloc] init];
    }
    return _originalBuffer;
}

- (void)setOriginalBuffer:(NSString *)input {
    NSMutableString *buffer = [self originalBuffer];
    [buffer setString:input];
}

- (void)showPreeditString:(NSString *)input {
    NSDictionary *attrs = [self markForStyle:kTSMHiliteSelectedRawText atRange:NSMakeRange(0, input.length)];
    NSAttributedString *attrString;

    NSString *originalBuff = [NSString stringWithString:[self originalBuffer]];
    if ([input.lowercaseString hasPrefix:originalBuff.lowercaseString]) {
        attrString = [[NSAttributedString alloc]
            initWithString:[NSString stringWithFormat:@"%@%@", originalBuff, [input substringFromIndex:originalBuff.length]]
                attributes:attrs];
    } else {
        attrString = [[NSAttributedString alloc] initWithString:input attributes:attrs];
    }

    [_currentClient setMarkedText:attrString
                   selectionRange:NSMakeRange(input.length, 0)
                 replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
}

- (void)originalBufferAppend:(NSString *)input client:(id)sender {
    NSMutableString *buffer = [self originalBuffer];
    [buffer appendString:input];
    _insertionIndex++;
    [self showPreeditString:buffer];
}

- (void)appendToComposedBuffer:(NSString *)input {
    NSMutableString *buffer = [self composedBuffer];
    [buffer appendString:input];
}

- (NSArray *)candidates:(id)sender {
    NSString *originalInput = [self originalBuffer];
    NSArray *candidateList = [engine getCandidates:originalInput];
    _candidates = [NSMutableArray arrayWithArray:candidateList];
    return candidateList;
}

- (void)candidateSelectionChanged:(NSAttributedString *)candidateString {
    writeDebugLog(@"");
    writeDebugLog(@"========== CANDIDATE SELECTION CHANGED ==========");

    // Update the current candidate index based on the selected candidate
    if (_candidates && candidateString) {
        NSString *selectedCandidate = candidateString.string;
        writeDebugLog([NSString stringWithFormat:@"🔄 candidateSelectionChanged called with: '%@'", selectedCandidate]);
        writeDebugLog([NSString stringWithFormat:@"📍 Previous index: %ld", (long)_currentCandidateIndex]);
        writeDebugLog([NSString stringWithFormat:@"🔍 Candidates expanded: %@", _candidatesExpanded ? @"YES" : @"NO"]);

        NSInteger oldIndex = _currentCandidateIndex;
        for (NSInteger i = 0; i < _candidates.count; i++) {
            if ([_candidates[i] isEqualToString:selectedCandidate]) {
                _currentCandidateIndex = i;
                writeDebugLog([NSString stringWithFormat:@"📍 New index: %ld (changed from %ld)", (long)_currentCandidateIndex, (long)oldIndex]);
                writeDebugLog([NSString stringWithFormat:@"🎯 Selected candidate: [%ld] '%@'", (long)i, selectedCandidate]);

                // Try to get more information from IMK framework
                if (_candidatesExpanded) {
                    // Delay the introspection to let IMK update its internal state
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self logIMKPanelInfo];
                    });
                }
                break;
            }
        }

        // Show current candidates context
        writeDebugLog(@"📝 Current candidates context:");
        int start = MAX(0, (int)_currentCandidateIndex - 2);
        int end = MIN((int)_candidates.count, (int)_currentCandidateIndex + 3);
        for (int i = start; i < end; i++) {
            NSString *marker = (i == _currentCandidateIndex) ? @"👉" : @"  ";
            writeDebugLog([NSString stringWithFormat:@"  %@[%d] %@", marker, i, _candidates[i]]);
        }
    }
    writeDebugLog(@"===============================================");

    // Don't update the composed buffer or display text when just navigating candidates
    // Keep showing the user's original input
    [self showPreeditString:[self originalBuffer]];

    _insertionIndex = [self originalBuffer].length;

    BOOL showTranslation = [preference boolForKey:@"showTranslation"];
    if (showTranslation) {
        [self showAnnotation:candidateString];
    }
}

- (void)candidateSelected:(NSAttributedString *)candidateString {
    writeDebugLog(@"");
    writeDebugLog(@"========== CANDIDATE SELECTED ==========");
    writeDebugLog([NSString stringWithFormat:@"🎯 candidateSelected called with: '%@'", candidateString.string]);
    writeDebugLog([NSString stringWithFormat:@"📍 Current candidate index: %ld", (long)_currentCandidateIndex]);
    writeDebugLog([NSString stringWithFormat:@"🔍 Candidates expanded: %@", _candidatesExpanded ? @"YES" : @"NO"]);
    writeDebugLog([NSString stringWithFormat:@"📊 Total candidates: %lu", (unsigned long)_candidates.count]);

    // Update both buffers when user explicitly selects a candidate
    [self setComposedBuffer:candidateString.string];
    [self setOriginalBuffer:candidateString.string];

    writeDebugLog([NSString stringWithFormat:@"📝 Set composed buffer to: '%@'", candidateString.string]);
    writeDebugLog(@"📤 Committing composition...");
    [self commitComposition:_currentClient];
    writeDebugLog(@"✅ Composition committed");
    writeDebugLog(@"=====================================");
}

- (void)logIMKPanelInfo {
    IMKCandidates *currentPanel = [self currentCandidatePanel];
    if (!currentPanel) {
        writeDebugLog(@"❌ No current panel available");
        return;
    }

    writeDebugLog(@"");
    writeDebugLog(@"========== DELAYED IMK PANEL INFO ==========");

    // Try to get candidate frame and other info
    NSRect candidateFrame = [currentPanel candidateFrame];
    writeDebugLog([NSString stringWithFormat:@"📐 Candidate frame: x=%.1f, y=%.1f, w=%.1f, h=%.1f",
                 candidateFrame.origin.x, candidateFrame.origin.y, candidateFrame.size.width, candidateFrame.size.height]);

    // Try to introspect the panel object for more methods
    writeDebugLog([NSString stringWithFormat:@"🔍 Panel class: %@", [currentPanel class]]);

    // Try some common methods that might exist
    if ([currentPanel respondsToSelector:@selector(selectedCandidateIndex)]) {
        id result = [currentPanel performSelector:@selector(selectedCandidateIndex)];
        NSInteger selectedIndex = [result integerValue];
        writeDebugLog([NSString stringWithFormat:@"📊 IMK selectedCandidateIndex: %ld", (long)selectedIndex]);
    }

    if ([currentPanel respondsToSelector:@selector(visibleCandidates)]) {
        id visibleCandidates = [currentPanel performSelector:@selector(visibleCandidates)];
        writeDebugLog([NSString stringWithFormat:@"👁️ IMK visibleCandidates (DELAYED): %@", visibleCandidates]);

        // Try to parse the visible candidates to understand the layout
        if ([visibleCandidates isKindOfClass:[NSArray class]]) {
            NSArray *visibleArray = (NSArray *)visibleCandidates;
            writeDebugLog([NSString stringWithFormat:@"📊 Visible candidates count: %lu", (unsigned long)visibleArray.count]);

            // Store the current visible candidates for number key selection
            _currentVisibleCandidates = visibleArray;

            // Extract candidate strings from the visible candidates
            NSMutableArray *visibleCandidateStrings = [NSMutableArray array];
            for (int i = 0; i < visibleArray.count; i++) {
                id candidate = visibleArray[i];
                writeDebugLog([NSString stringWithFormat:@"  👁️[%d] %@", i, candidate]);

                // Try to extract the candidate string from the IMK candidate object
                NSString *candidateString = nil;
                if ([candidate respondsToSelector:@selector(string)]) {
                    candidateString = [candidate performSelector:@selector(string)];
                } else if ([candidate isKindOfClass:[NSString class]]) {
                    candidateString = (NSString *)candidate;
                } else {
                    // Try to parse from description like "'(null)' -> 'helps' (IMKCandidateTypeReplacement)"
                    NSString *description = [candidate description];
                    NSRange arrowRange = [description rangeOfString:@"' -> '"];
                    if (arrowRange.location != NSNotFound) {
                        NSRange startRange = NSMakeRange(arrowRange.location + arrowRange.length, description.length - arrowRange.location - arrowRange.length);
                        NSRange endRange = [description rangeOfString:@"'" options:0 range:startRange];
                        if (endRange.location != NSNotFound) {
                            candidateString = [description substringWithRange:NSMakeRange(startRange.location, endRange.location - startRange.location)];
                        }
                    }
                }

                if (candidateString) {
                    [visibleCandidateStrings addObject:candidateString];
                    writeDebugLog([NSString stringWithFormat:@"    📝 Extracted: '%@'", candidateString]);
                } else {
                    writeDebugLog([NSString stringWithFormat:@"    ❌ Could not extract string from: %@", candidate]);
                }
            }

            // Store the extracted strings
            _currentVisibleCandidates = [visibleCandidateStrings copy];
            writeDebugLog([NSString stringWithFormat:@"💾 Stored %lu visible candidate strings for number key selection", (unsigned long)visibleCandidateStrings.count]);
        }
    }

    if ([currentPanel respondsToSelector:@selector(candidatesPerRow)]) {
        id result = [currentPanel performSelector:@selector(candidatesPerRow)];
        NSInteger candidatesPerRow = [result integerValue];
        writeDebugLog([NSString stringWithFormat:@"📏 IMK candidatesPerRow: %ld", (long)candidatesPerRow]);
    }

    // List all methods available on the panel (only once to avoid spam)
    static BOOL methodsLogged = NO;
    if (!methodsLogged) {
        unsigned int methodCount;
        Method *methods = class_copyMethodList([currentPanel class], &methodCount);
        writeDebugLog(@"🔧 Available methods:");
        for (unsigned int i = 0; i < MIN(methodCount, 30); i++) {
            SEL selector = method_getName(methods[i]);
            NSString *methodName = NSStringFromSelector(selector);
            if ([methodName containsString:@"candidate"] || [methodName containsString:@"select"] ||
                [methodName containsString:@"visible"] || [methodName containsString:@"row"] ||
                [methodName containsString:@"page"] || [methodName containsString:@"index"]) {
                writeDebugLog([NSString stringWithFormat:@"  - %@", methodName]);
            }
        }
        free(methods);
        methodsLogged = YES;
    }

    writeDebugLog(@"==========================================");
}

- (void)_updateComposedBuffer:(NSAttributedString *)candidateString {
    [self setComposedBuffer:candidateString.string];
}

- (void)activateServer:(id)sender {
    [sender overrideKeyboardWithKeyboardNamed:@"com.apple.keylayout.US"];

    if (_annotationWin == nil) {
        _annotationWin = [AnnotationWinController sharedController];
    }

    _currentCandidateIndex = 0;
    _hasNavigatedCandidates = NO;
    _candidatesExpanded = NO;
    _candidates = [[NSMutableArray alloc] init];
}

- (void)deactivateServer:(id)sender {
    [self reset];
}

- (NSMenu *)menu{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [NSApp.delegate performSelector:NSSelectorFromString(@"menu")];
#pragma clang diagnostic pop
}

- (void)showIMEPreferences:(id)sender {
    [self openUrl:@"http://localhost:62718/index.html"];
}

- (void)clickAbout:(NSMenuItem *)sender {
    [self openUrl:@"https://github.com/dongyuwei/hallelujahIM"];
}

- (void)openUrl:(NSString *)url {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    
    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration new];
    configuration.promptsUserIfNeeded = YES;
    configuration.createsNewApplicationInstance = NO;
    
    [ws openURL:[NSURL URLWithString:url] configuration:configuration completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
        if (error) {
          NSLog(@"Failed to run the app: %@", error.localizedDescription);
        }
    }];
}

- (void)showAnnotation:(NSAttributedString *)candidateString {
    NSString *annotation = [engine getAnnotation:candidateString.string];
    if (annotation && annotation.length > 0) {
        [_annotationWin setAnnotation:annotation];
        [_annotationWin showWindow:[self calculatePositionOfTranslationWindow]];
    } else {
        [_annotationWin hideWindow];
    }
}

- (NSPoint)calculatePositionOfTranslationWindow {
    // Mac Cocoa ui default coordinate system: left-bottom, origin: (x:0, y:0) ↑→
    // see https://developer.apple.com/library/archive/documentation/General/Conceptual/Devpedia-CocoaApp/CoordinateSystem.html
    // see https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CocoaDrawingGuide/Transforms/Transforms.html
    // Notice: there is a System bug: candidateFrame.origin always be (0,0), so we can't depending on the origin point.
    NSRect candidateFrame = [sharedCandidates candidateFrame];

    // line-box of current input text: (width:1, height:17)
    NSRect lineRect;
    [_currentClient attributesForCharacterIndex:0 lineHeightRectangle:&lineRect];
    NSPoint cursorPoint = NSMakePoint(NSMinX(lineRect), NSMinY(lineRect));
    NSPoint positionPoint = NSMakePoint(NSMinX(lineRect), NSMinY(lineRect));
    positionPoint.x = positionPoint.x + candidateFrame.size.width;
    NSScreen *currentScreen = [NSScreen currentScreenForMouseLocation];
    NSPoint currentPoint = [currentScreen convertPointToScreenCoordinates:cursorPoint];
    NSRect rect = currentScreen.frame;
    int screenWidth = (int)rect.size.width;
    int marginToCandidateFrame = 20;
    int annotationWindowWidth = _annotationWin.width + marginToCandidateFrame;
    int lineHeight = lineRect.size.height; // 17px

    if (screenWidth - currentPoint.x >= candidateFrame.size.width) {
        // safe distance to display candidateFrame at current cursor's left-side.
        if (screenWidth - currentPoint.x < candidateFrame.size.width + annotationWindowWidth) {
            positionPoint.x = positionPoint.x - candidateFrame.size.width - annotationWindowWidth;
        }
    } else {
        // assume candidateFrame will display at current cursor's right-side.
        positionPoint.x = screenWidth - candidateFrame.size.width - annotationWindowWidth;
    }
    if (currentPoint.y >= candidateFrame.size.height) {
        positionPoint.y = positionPoint.y - 8; // Both 8 and 3 are magic numbers to adjust the position
    } else {
        positionPoint.y = positionPoint.y + candidateFrame.size.height + lineHeight + 3;
    }

    return positionPoint;
}

- (IMKCandidates *)currentCandidatePanel {
    return _candidatesExpanded ? expandedCandidates : sharedCandidates;
}

- (void)switchToExpandedMode {
    if (!_candidatesExpanded) {
        _candidatesExpanded = YES;
        [sharedCandidates hide];
        [expandedCandidates setCandidateData:_candidates];
        [expandedCandidates show:kIMKLocateCandidatesBelowHint];
        [expandedCandidates selectCandidateWithIdentifier:_currentCandidateIndex];
    }
}

- (void)switchToCompactMode {
    if (_candidatesExpanded) {
        _candidatesExpanded = NO;
        [expandedCandidates hide];
        [sharedCandidates setCandidateData:_candidates];
        [sharedCandidates show:kIMKLocateCandidatesBelowHint];
        [sharedCandidates selectCandidateWithIdentifier:_currentCandidateIndex];
    }
}

@end
