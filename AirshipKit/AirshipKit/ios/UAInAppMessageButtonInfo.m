/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageButtonInfo.h"
#import "UAGlobal.h"
#import "UAColorUtils+Internal.h"

NS_ASSUME_NONNULL_BEGIN
NSString *const UAInAppMessageButtonInfoDomain = @"com.urbanairship.in_app_message_button_info";

// JSON Keys and Values
NSString *const UAInAppMessageButtonInfoLabelKey = @"label";
NSString *const UAInAppMessageButtonInfoIdentifierKey = @"id";
NSString *const UAInAppMessageButtonInfoBehaviorKey = @"behavior";
NSString *const UAInAppMessageButtonInfoBorderRadiusKey = @"border_radius";
NSString *const UAInAppMessageButtonInfoBackgroundColorKey = @"background_color";
NSString *const UAInAppMessageButtonInfoBorderColorKey = @"border_color";
NSString *const UAInAppMessageButtonInfoActionsKey = @"actions";

NSString *const UAInAppMessageButtonInfoBehaviorCancelValue = @"cancel";
NSString *const UAInAppMessageButtonInfoBehaviorDismissValue = @"dismiss";

@interface UAInAppMessageButtonInfo ()
@property(nonatomic, strong) UAInAppMessageTextInfo *label;
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, assign) UAInAppMessageButtonInfoBehaviorType behavior;
@property(nonatomic, strong) UIColor *backgroundColor;
@property(nonatomic, strong) UIColor *borderColor;
@property(nonatomic, assign) NSUInteger borderRadius;
@property(nonatomic, copy, nullable) NSDictionary *actions;
@end

@implementation UAInAppMessageButtonInfoBuilder

// set default values for properties
- (instancetype)init {
    if (self = [super init]) {
        self.behavior = UAInAppMessageButtonInfoBehaviorDismiss;
        self.backgroundColor = [UIColor blackColor];
        self.borderColor = [UIColor blackColor];
    }
    return self;
}

@end

@implementation UAInAppMessageButtonInfo

- (instancetype)initWithBuilder:(UAInAppMessageButtonInfoBuilder *)builder {
    self = [super self];

    if (![UAInAppMessageButtonInfo validateBuilder:builder]) {
        UA_LDEBUG(@"UAInAppMessageButtonInfo instance could not be initialized, builder has missing or invalid parameters.");
        return nil;
    }

    if (self) {
        self.label = builder.label;
        self.identifier = builder.identifier;
        self.behavior = builder.behavior;
        self.backgroundColor = builder.backgroundColor;
        self.borderRadius = builder.borderRadius;
        self.borderColor = builder.borderColor;
        self.actions = builder.actions;
    }

    return self;
}

+ (nullable instancetype)buttonInfoWithBuilderBlock:(void(^)(UAInAppMessageButtonInfoBuilder *builder))builderBlock {
    UAInAppMessageButtonInfoBuilder *builder = [[UAInAppMessageButtonInfoBuilder alloc] init];

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UAInAppMessageButtonInfo alloc] initWithBuilder:builder];
}

+ (nullable instancetype)buttonInfoWithJSON:(id)json error:(NSError * _Nullable *)error {
    UAInAppMessageButtonInfoBuilder *builder = [[UAInAppMessageButtonInfoBuilder alloc] init];

    id labelDict = json[UAInAppMessageButtonInfoLabelKey];
    if (labelDict) {
        if (![labelDict isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"In-app message button label must be an dictionary. Invalid value: %@", labelDict];
                *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                              code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            
            return nil;
        }
        
        builder.label = [UAInAppMessageTextInfo textInfoWithJSON:labelDict error:error];
        if (!builder.label) {
            return nil;
        }
    }

    id identifierText = json[UAInAppMessageButtonInfoIdentifierKey];
    if (identifierText) {
        if (![identifierText isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"In-app message button identifier must be a string. Invalid value: %@", identifierText];
                *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                              code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            
            return nil;
        }
        builder.identifier = identifierText;
    }

    id behaviorContents = json[UAInAppMessageButtonInfoBehaviorKey];
    if (behaviorContents) {
        if (![behaviorContents isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Behavior must be a string."];
                *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                              code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }

       behaviorContents = [behaviorContents lowercaseString];

        if ([UAInAppMessageButtonInfoBehaviorCancelValue isEqualToString:behaviorContents]) {
            builder.behavior = UAInAppMessageButtonInfoBehaviorCancel;
        } else if ([UAInAppMessageButtonInfoBehaviorDismissValue isEqualToString:behaviorContents]) {
            builder.behavior = UAInAppMessageButtonInfoBehaviorDismiss;
        } else {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Invalid in-app message button behavior: %@", behaviorContents];
                *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                              code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }

            return nil;
        }
    }

    id backgroundColorHex = json[UAInAppMessageButtonInfoBackgroundColorKey];
    if (backgroundColorHex) {
        
        if (![backgroundColorHex isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"In-app message button background color must be a hex string. Invalid value: %@", backgroundColorHex];
                *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                              code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            
            return nil;
        }
        builder.backgroundColor = [UAColorUtils colorWithHexString:backgroundColorHex];
    }

    id borderColorHex = json[UAInAppMessageButtonInfoBorderColorKey];
    if (borderColorHex) {
        if (![borderColorHex isKindOfClass:[NSString class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"In-app message button border color must be a hex string. Invalid value: %@", borderColorHex];
                *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                              code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            
            return nil;
        }
        builder.borderColor = [UAColorUtils colorWithHexString:borderColorHex];
    }

    id borderRadius = json[UAInAppMessageButtonInfoBorderRadiusKey];
    if (borderRadius) {
        if (![borderRadius isKindOfClass:[NSNumber class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Button border radius must be a number. Invalid value: %@", borderRadius];
                *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                              code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            return nil;
        }
        builder.borderRadius = [borderRadius unsignedIntegerValue];
    }

    // Actions
    id actions = json[UAInAppMessageButtonInfoActionsKey];
    if (actions) {
        if (![actions isKindOfClass:[NSDictionary class]]) {
            if (error) {
                NSString *msg = [NSString stringWithFormat:@"Button actions payload must be a dictionary. Invalid value: %@", actions];
                *error =  [NSError errorWithDomain:UAInAppMessageButtonInfoDomain
                                              code:UAInAppMessageButtonInfoErrorCodeInvalidJSON
                                          userInfo:@{NSLocalizedDescriptionKey:msg}];
            }
            
            return nil;
        }
        builder.actions = actions;
    }

    return [[UAInAppMessageButtonInfo alloc] initWithBuilder:builder];
}

+ (NSDictionary *)JSONWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo {
    if (!buttonInfo) {
        return nil;
    }

    NSMutableDictionary *json = [NSMutableDictionary dictionary];

    json[UAInAppMessageButtonInfoLabelKey] = [UAInAppMessageTextInfo JSONWithTextInfo:buttonInfo.label];
    json[UAInAppMessageButtonInfoIdentifierKey] = buttonInfo.identifier;
    json[UAInAppMessageButtonInfoBorderRadiusKey] = [NSNumber numberWithInteger:buttonInfo.borderRadius];
    
    switch (buttonInfo.behavior) {
        case UAInAppMessageButtonInfoBehaviorCancel:
            json[UAInAppMessageButtonInfoBehaviorKey] = UAInAppMessageButtonInfoBehaviorCancelValue;
            break;
        case UAInAppMessageButtonInfoBehaviorDismiss:
        default:
            json[UAInAppMessageButtonInfoBehaviorKey] = UAInAppMessageButtonInfoBehaviorDismissValue;
            break;
    }

    json[UAInAppMessageButtonInfoBorderColorKey] = [UAColorUtils hexStringWithColor:buttonInfo.borderColor];
    json[UAInAppMessageButtonInfoBackgroundColorKey] = [UAColorUtils hexStringWithColor:buttonInfo.backgroundColor];
    json[UAInAppMessageButtonInfoActionsKey] = buttonInfo.actions;

    return [NSDictionary dictionaryWithDictionary:json];
}

#pragma mark - Validation

+ (BOOL)validateBuilder:(UAInAppMessageButtonInfoBuilder *)builder {
    if (!builder.label) {
        UA_LDEBUG(@"In-app button infos require a label");
        return NO;
    }

    return YES;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[UAInAppMessageButtonInfo class]]) {
        return NO;
    }

    return [self isEqualToInAppMessageButtonInfo:(UAInAppMessageButtonInfo *)object];
}

- (BOOL)isEqualToInAppMessageButtonInfo:(UAInAppMessageButtonInfo *)info {

    if (self.label != info.label && ![self.label isEqual:info.label]) {
        return NO;
    }

    if (self.identifier != info.identifier && ![self.identifier isEqualToString:info.identifier]) {
        return NO;
    }

    if (self.behavior != info.behavior) {
        return NO;
    }

    if (self.backgroundColor != info.backgroundColor && ![[UAColorUtils hexStringWithColor:self.backgroundColor] isEqualToString:[UAColorUtils hexStringWithColor:info.backgroundColor]]) {
        return NO;
    }

    if (self.borderColor != info.borderColor && ![[UAColorUtils hexStringWithColor:self.borderColor] isEqualToString:[UAColorUtils hexStringWithColor:info.borderColor]]) {
        return NO;
    }

    if (self.actions != info.actions && ![self.actions isEqualToDictionary:info.actions]) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash {
    NSUInteger result = 1;
    result = 31 * result + [self.label hash];
    result = 31 * result + [self.identifier hash];
    result = 31 * result + self.behavior;
    result = 31 * result + [self.backgroundColor hash];
    result = 31 * result + [self.borderColor hash];
    result = 31 * result + [self.actions hash];

    return result;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"UAInAppMessageButtonInfo: %@", self.identifier ?: self.label];
}

@end

NS_ASSUME_NONNULL_END
