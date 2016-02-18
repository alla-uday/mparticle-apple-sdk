//
//  MPApplication.m
//
//  Copyright 2015 mParticle, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "MPApplication.h"
#import <mach-o/ldsyms.h>
#import <dlfcn.h>
#import <mach-o/arch.h>
#import <mach-o/dyld.h>
#import "NSUserDefaults+mParticle.h"
#import <UIKit/UIKit.h>
#import "MPStateMachine.h"

NSString *const kMPApplicationInformationKey = @"ai";
NSString *const kMPApplicationNameKey = @"an";
NSString *const kMPApplicationVersionKey = @"av";
NSString *const kMPAppPackageNameKey = @"apn";
NSString *const kMPAppInitialLaunchTimeKey = @"ict";
NSString *const kMPAppBuildNumberKey = @"abn";
NSString *const kMPAppBuildUUIDKey = @"bid";
NSString *const kMPAppArchitectureKey = @"arc";
NSString *const kMPAppPiratedKey = @"pir";
NSString *const kMPAppDeploymentTargetKey = @"tsv";
NSString *const kMPAppBuildSDKKey = @"bsv";
NSString *const kMPAppUpgradeDateKey = @"ud";
NSString *const kMPAppLaunchCountKey = @"lc";
NSString *const kMPAppLaunchCountSinceUpgradeKey = @"lcu";
NSString *const kMPAppLastUseDateKey = @"lud";
NSString *const kMPAppStoredVersionKey = @"asv";
NSString *const kMPAppStoredBuildKey = @"asb";
NSString *const kMPAppEnvironmentKey = @"env";
NSString *const kMPAppBadgeNumberKey = @"bn";
NSString *const kMPAppStoreReceiptKey = @"asr";

static NSString *kMPAppStoreReceiptString = nil;

@interface MPApplication() {
    NSDictionary *appInfo;
    NSUserDefaults *userDefaults;
    BOOL syncUserDefaults;
}

@end


@implementation MPApplication

@synthesize architecture = _architecture;
@synthesize buildUUID = _buildUUID;
@synthesize environment = _environment;
@synthesize initialLaunchTime = _initialLaunchTime;
@synthesize pirated = _pirated;

+ (void)initialize {
    NSURL *url = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *appStoreReceiptData = [NSData dataWithContentsOfURL:url];
    
    if (appStoreReceiptData) {
        kMPAppStoreReceiptString = [appStoreReceiptData base64EncodedStringWithOptions:0];
    }
}

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    userDefaults = [NSUserDefaults standardUserDefaults];
    syncUserDefaults = NO;
    
    return self;
}

- (void)dealloc {
    if (syncUserDefaults) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSUserDefaults standardUserDefaults] synchronize];
        });
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@", [self dictionaryRepresentation]];
}

#pragma mark Accessors
- (NSString *)architecture {
    if (_architecture) {
        return _architecture;
    }
    
    const struct mach_header *header = _dyld_get_image_header(0);
    const NXArchInfo *info = NXGetArchInfoFromCpuType(header->cputype, header->cpusubtype);
    
    _architecture = [[NSString alloc] initWithUTF8String:info->name];
    
    return _architecture;
}

- (NSString *)build {
    NSDictionary *bundleInfoDictionary = [[NSBundle mainBundle] infoDictionary];
    return bundleInfoDictionary[@"CFBundleVersion"];
}

- (NSString *)buildUUID {
//#if !TARGET_IPHONE_SIMULATOR
//    if (_buildUUID) {
//        return _buildUUID;
//    }
//    
//    const uint8_t *command = (const uint8_t *)(&_mh_execute_header + 1);
//    for (uint32_t idx = 0; idx < _mh_execute_header.ncmds; ++idx) {
//        const struct load_command *load_command = (const struct load_command *)command;
//        if (load_command->cmd == LC_UUID) {
//            const struct uuid_command *uuid_command = (const struct uuid_command *)command;
//            const uint8_t *uuid = uuid_command->uuid;
//            
//            _buildUUID = [[NSString stringWithFormat:@"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
//                           uuid[0], uuid[1], uuid[2], uuid[3],
//                           uuid[4], uuid[5], uuid[6], uuid[7],
//                           uuid[8], uuid[9], uuid[10], uuid[11],
//                           uuid[12], uuid[13], uuid[14], uuid[15]]
//                          lowercaseString];
//            
//            return _buildUUID;
//        } else {
//            command += load_command->cmdsize;
//        }
//    }
//#endif
    return @"00000000-0000-0000-0000-000000000000";
}

- (NSString *)bundleIdentifier {
    NSDictionary *bundleInfoDictionary = [[NSBundle mainBundle] infoDictionary];
    return bundleInfoDictionary[@"CFBundleIdentifier"];
}

- (MPEnvironment)environment {
    return [MPStateMachine environment];
}

- (NSNumber *)firstSeenInstallation {
    return [MPStateMachine sharedInstance].firstSeenInstallation;
}

- (NSNumber *)initialLaunchTime {
    if (_initialLaunchTime) {
        return _initialLaunchTime;
    }
    
    _initialLaunchTime = userDefaults[kMPAppInitialLaunchTimeKey];
    
    if (!_initialLaunchTime) {
        _initialLaunchTime = MPCurrentEpochInMilliseconds;
        userDefaults[kMPAppInitialLaunchTimeKey] = _initialLaunchTime;
        syncUserDefaults = YES;
    }

    return _initialLaunchTime;
}

- (NSString *)name {
    NSDictionary *bundleInfoDictionary = [[NSBundle mainBundle] infoDictionary];
    return bundleInfoDictionary[@"CFBundleDisplayName"];
}

- (NSNumber *)lastUseDate {
    NSNumber *lastUseDate = userDefaults[kMPAppLastUseDateKey];
    if (!lastUseDate) {
        lastUseDate = MPMilliseconds([[MPStateMachine sharedInstance].launchDate timeIntervalSince1970]);
    }
    
    return lastUseDate;
}

- (void)setLastUseDate:(NSNumber *)lastUseDate {
    userDefaults[kMPAppLastUseDateKey] = lastUseDate;
    syncUserDefaults = YES;
}

- (NSNumber *)launchCount {
    NSNumber *launchCount = userDefaults[kMPAppLaunchCountKey];
    return launchCount;
}

- (void)setLaunchCount:(NSNumber *)launchCount {
    userDefaults[kMPAppLaunchCountKey] = launchCount;
    syncUserDefaults = YES;
}

- (NSNumber *)launchCountSinceUpgrade {
    NSNumber *launchCount = userDefaults[kMPAppLaunchCountSinceUpgradeKey];
    return launchCount;
}

- (void)setLaunchCountSinceUpgrade:(NSNumber *)launchCountSinceUpgrade {
    userDefaults[kMPAppLaunchCountSinceUpgradeKey] = launchCountSinceUpgrade;
    syncUserDefaults = YES;
}

- (NSNumber *)pirated {
    _pirated = @(NO);
    return _pirated;
}

- (NSNumber *)remoteNotificationTypes {
    NSNumber *notificationTypes;
    UIApplication *app = [UIApplication sharedApplication];
    
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 8.0) {
        UIUserNotificationSettings *userNotificationSettings = [app currentUserNotificationSettings];
        notificationTypes = @(userNotificationSettings.types);
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        notificationTypes = @([app enabledRemoteNotificationTypes]);
#pragma clang diagnostic pop
    }

    return notificationTypes;
}

- (NSString *)storedBuild {
    NSString *storedBuild = userDefaults[kMPAppStoredBuildKey];
    return storedBuild;
}

- (void)setStoredBuild:(NSString *)storedBuild {
    if (storedBuild) {
        userDefaults[kMPAppStoredBuildKey] = storedBuild;
    } else {
        [userDefaults removeMPObjectForKey:kMPAppStoredBuildKey];
    }
    
    syncUserDefaults = YES;
}

- (NSString *)storedVersion {
    NSString *storedBuild = userDefaults[kMPAppStoredVersionKey];
    return storedBuild;
}

- (void)setStoredVersion:(NSString *)storedVersion {
    if (storedVersion) {
        userDefaults[kMPAppStoredVersionKey] = storedVersion;
    } else {
        [userDefaults removeMPObjectForKey:kMPAppStoredVersionKey];
    }
    
    syncUserDefaults = YES;
}

- (NSNumber *)upgradeDate {
    NSNumber *upgradeDate = userDefaults[kMPAppUpgradeDateKey];
    return upgradeDate;
}

- (void)setUpgradeDate:(NSNumber *)upgradeDate {
    userDefaults[kMPAppUpgradeDateKey] = upgradeDate;
    syncUserDefaults = YES;
}

- (NSString *)version {
#ifndef MP_UNIT_TESTING
    NSDictionary *bundleInfoDictionary = [[NSBundle mainBundle] infoDictionary];
    return bundleInfoDictionary[@"CFBundleShortVersionString"];
#else
    return kMParticleSDKVersion;
#endif
}

#pragma mark NSCopying
- (instancetype)copyWithZone:(NSZone *)zone {
    MPApplication *copyObject = [[[self class] alloc] init];
    
    if (copyObject) {
        copyObject->_architecture = [_architecture copy];
        copyObject->_buildUUID = [_buildUUID copy];
        copyObject->_initialLaunchTime = [_initialLaunchTime copy];
        copyObject->_pirated = [_pirated copy];
    }
    
    return copyObject;
}

#pragma mark Class methods
+ (NSString *)appStoreReceipt {
    return kMPAppStoreReceiptString;
}

+ (void)markInitialLaunchTime {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSNumber *initialLaunchTime = userDefaults[kMPAppInitialLaunchTimeKey];
    
    if (!initialLaunchTime) {
        initialLaunchTime = MPCurrentEpochInMilliseconds;
        userDefaults[kMPAppInitialLaunchTimeKey] = initialLaunchTime;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [userDefaults synchronize];
        });
    }
}

+ (void)updateLastUseDate:(NSDate *)date {
    MPApplication *application = [[MPApplication alloc] init];
    application.lastUseDate = MPMilliseconds([date timeIntervalSince1970]);
}

+ (void)updateLaunchCountsAndDates {
    MPApplication *application = [[MPApplication alloc] init];
    
    application.launchCount = @([application.launchCount integerValue] + 1);
    
    if (![application.version isEqualToString:application.storedVersion] || ![application.build isEqualToString:application.storedBuild]) {
        application.launchCountSinceUpgrade = @1;
        application.upgradeDate = MPCurrentEpochInMilliseconds;
    } else {
        application.launchCountSinceUpgrade = @([application.launchCountSinceUpgrade integerValue] + 1);
    }
}

+ (void)updateStoredVersionAndBuildNumbers {
    MPApplication *application = [[MPApplication alloc] init];
    application.storedVersion = application.version;
    application.storedBuild = application.build;
}

#pragma mark Public methods
- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    if (appInfo) {
        return appInfo;
    }
    
    NSMutableDictionary<NSString *, id> *applicationInfo;
    NSString *auxString;
    
#ifndef MP_UNIT_TESTING
    applicationInfo = [@{kMPAppPiratedKey:self.pirated,
                         kMPAppInitialLaunchTimeKey:self.initialLaunchTime,
                         kMPDeviceSupportedPushNotificationTypesKey:self.remoteNotificationTypes,
                         kMPAppDeploymentTargetKey:[NSString stringWithFormat:@"%i", __IPHONE_OS_VERSION_MIN_REQUIRED],
                         kMPAppBuildSDKKey:[NSString stringWithFormat:@"%i", __IPHONE_OS_VERSION_MAX_ALLOWED],
                         kMPAppEnvironmentKey:@(self.environment),
                         kMPAppFirstSeenInstallationKey:self.firstSeenInstallation}
                       mutableCopy];
    
    auxString = self.bundleIdentifier;
    if (auxString) {
        applicationInfo[kMPAppPackageNameKey] = auxString;
    }
    
    auxString = self.buildUUID;
    if (auxString) {
        applicationInfo[kMPAppBuildUUIDKey] = auxString;
    }
    
    auxString = self.architecture;
    if (auxString) {
        applicationInfo[kMPAppArchitectureKey] = auxString;
    }
    
    auxString = self.name;
    if (auxString) {
        applicationInfo[kMPApplicationNameKey] = auxString;
    }
    
    NSNumber *auxNumber = self.upgradeDate;
    if (auxNumber) {
        applicationInfo[kMPAppUpgradeDateKey] = auxNumber;
    }
    
    auxNumber = self.launchCount;
    if (auxNumber) {
        applicationInfo[kMPAppLaunchCountKey] = auxNumber;
    }
    
    auxNumber = self.launchCountSinceUpgrade;
    if (auxNumber) {
        applicationInfo[kMPAppLaunchCountSinceUpgradeKey] = auxNumber;
    }
    
    auxNumber = self.lastUseDate;
    if (auxNumber) {
        applicationInfo[kMPAppLastUseDateKey] = auxNumber;
    }
    
    NSInteger badgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber;
    if (badgeNumber != 0) {
        applicationInfo[kMPAppBadgeNumberKey] = @(badgeNumber);
    }
#else
    applicationInfo = [@{kMPAppPackageNameKey:@"no.bundle.identifier",
                         kMPAppBuildUUIDKey:@"00000000-0000-0000-0000-000000000000",
                         kMPAppArchitectureKey:@"no_architecture",
                         kMPAppPiratedKey:@0,
                         kMPApplicationNameKey:@"no-name",
                         kMPAppInitialLaunchTimeKey:MPMilliseconds([[NSDate date] timeIntervalSince1970]),
                         kMPDeviceSupportedPushNotificationTypesKey:@0,
                         kMPAppDeploymentTargetKey:[NSString stringWithFormat:@"%i", __IPHONE_OS_VERSION_MIN_REQUIRED],
                         kMPAppBuildSDKKey:[NSString stringWithFormat:@"%i", __IPHONE_OS_VERSION_MAX_ALLOWED],
                         kMPAppUpgradeDateKey:MPMilliseconds([[NSDate date] timeIntervalSince1970]),
                         kMPAppLaunchCountKey:@1,
                         kMPAppLaunchCountSinceUpgradeKey:@1,
                         kMPAppLastUseDateKey:MPMilliseconds([[NSDate date] timeIntervalSince1970]),
                         kMPAppEnvironmentKey:@(MPEnvironmentDevelopment),
                         kMPAppFirstSeenInstallationKey:self.firstSeenInstallation}
                       mutableCopy];
#endif
    
    auxString = self.version;
    if (auxString) {
        applicationInfo[kMPApplicationVersionKey] = auxString;
    }
    
    auxString = self.build;
    if (auxString) {
        applicationInfo[kMPAppBuildNumberKey] = auxString;
    }
    
    if (kMPAppStoreReceiptString) {
        applicationInfo[kMPAppStoreReceiptKey] = kMPAppStoreReceiptString;
    }
    
    appInfo = (NSDictionary *)applicationInfo;
    
    return appInfo;
}

@end